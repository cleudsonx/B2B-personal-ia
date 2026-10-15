import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;

/// Modelo de dados de uma foto confidencial de evolução física
class EvolutionPhoto {
  final String id;
  final String studentId;
  final String photoUrl;
  final String photoType; // 'before', 'after', 'progress'
  final String? caption;
  final double? weightKg;
  final DateTime takenAt;

  const EvolutionPhoto({
    required this.id,
    required this.studentId,
    required this.photoUrl,
    required this.photoType,
    this.caption,
    this.weightKg,
    required this.takenAt,
  });

  factory EvolutionPhoto.fromJson(Map<String, dynamic> json) {
    return EvolutionPhoto(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
      photoType: json['photo_type']?.toString() ?? 'progress',
      caption: json['caption'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      takenAt: json['taken_at'] != null
          ? DateTime.tryParse(json['taken_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'photo_url': photoUrl,
        'photo_type': photoType,
        'caption': caption,
        'weight_kg': weightKg,
        'taken_at': takenAt.toIso8601String(),
      };
}

class EvolutionPhotoService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static final ImagePicker _picker = ImagePicker();

  /// Captura ou escolhe foto do dispositivo
  static Future<Uint8List?> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (file == null) return null;
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Erro ao selecionar foto de evolução: $e');
      return null;
    }
  }

  /// Faz upload da foto para o Supabase Storage e registra no banco
  static Future<EvolutionPhoto?> uploadPhoto({
    required Uint8List bytes,
    required String photoType, // 'before', 'after' ou 'progress'
    String? caption,
    double? weightKg,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return null;

    final client = _clientOrNull;
    String photoUrl = '';

    // 1. Tentar upload seguro via storage do Supabase
    if (client != null) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'evolution/${user.id}_${photoType}_$timestamp.jpg';

        await client.storage.from('avatars').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        photoUrl = client.storage.from('avatars').getPublicUrl(path);
      } catch (storageErr) {
        debugPrint('Aviso upload Storage: $storageErr');
      }
    }

    // Se storage falhou ou não configurado, converte em Base64 Data URI de alta compatibilidade
    if (photoUrl.isEmpty) {
      final base64 = base64Encode(bytes);
      photoUrl = 'data:image/jpeg;base64,$base64';
    }

    final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final photo = EvolutionPhoto(
      id: photoId,
      studentId: user.id,
      photoUrl: photoUrl,
      photoType: photoType,
      caption: caption,
      weightKg: weightKg,
      takenAt: now,
    );

    // 2. Persistir no banco Supabase
    if (client != null) {
      try {
        final res = await client.from('student_evolution_photos').insert({
          'student_id': user.id,
          'photo_url': photoUrl,
          'photo_type': photoType,
          'caption': caption,
          'weight_kg': weightKg,
          'taken_at': now.toIso8601String(),
        }).select().maybeSingle();

        if (res != null) {
          final savedPhoto = EvolutionPhoto.fromJson(res);
          await _saveToLocalCache(user.id, savedPhoto);
          return savedPhoto;
        }
      } catch (dbErr) {
        debugPrint('Aviso persistência DB evolution photo: $dbErr');
      }
    }

    // Salva no cache local como garantia de exibição imediata
    await _saveToLocalCache(user.id, photo);
    return photo;
  }

  /// Busca as fotos de evolução de um aluno
  static Future<Map<String, EvolutionPhoto?>> getStudentBeforeAndAfter(String studentId) async {
    EvolutionPhoto? beforePhoto;
    EvolutionPhoto? afterPhoto;

    // 1. Tenta buscar no banco Supabase
    final client = _clientOrNull;
    if (client != null) {
      try {
        final List<dynamic> res = await client
            .from('student_evolution_photos')
            .select('*')
            .eq('student_id', studentId)
            .order('taken_at', ascending: true);

        if (res.isNotEmpty) {
          final allPhotos = res.map((e) => EvolutionPhoto.fromJson(Map<String, dynamic>.from(e))).toList();
          
          // Before: foto com photo_type 'before' ou a mais antiga
          beforePhoto = allPhotos.firstWhere(
            (p) => p.photoType == 'before',
            orElse: () => allPhotos.first,
          );

          // After: foto com photo_type 'after' ou a mais recente
          if (allPhotos.length > 1) {
            afterPhoto = allPhotos.lastWhere(
              (p) => p.photoType == 'after' || p.id != beforePhoto?.id,
              orElse: () => allPhotos.last,
            );
          } else if (beforePhoto.photoType == 'after') {
            afterPhoto = beforePhoto;
            beforePhoto = null;
          }
        }
      } catch (e) {
        debugPrint('Aviso busca evolution photos: $e');
      }
    }

    // 2. Fallback de cache local
    if (beforePhoto == null && afterPhoto == null) {
      final cached = await _loadFromLocalCache(studentId);
      if (cached.isNotEmpty) {
        beforePhoto = cached.firstWhere((p) => p.photoType == 'before', orElse: () => cached.first);
        if (cached.length > 1) {
          afterPhoto = cached.lastWhere((p) => p.photoType == 'after' || p.id != beforePhoto?.id, orElse: () => cached.last);
        }
      }
    }

    return {
      'before': beforePhoto,
      'after': afterPhoto,
    };
  }

  static const String _prefPrefix = 'evolution_photos_';

  static Future<void> _saveToLocalCache(String studentId, EvolutionPhoto photo) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 600));
      final key = '$_prefPrefix$studentId';
      final existingJson = prefs.getStringList(key) ?? [];
      existingJson.add(jsonEncode(photo.toJson()));
      await prefs.setStringList(key, existingJson);
    } catch (_) {}
  }

  static Future<List<EvolutionPhoto>> _loadFromLocalCache(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 600));
      final key = '$_prefPrefix$studentId';
      final list = prefs.getStringList(key) ?? [];
      return list
          .map((s) => EvolutionPhoto.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Renderiza com resiliência foto do aluno (seja URL remota ou Base64 local)
  static Widget buildPhotoImage(
    String photoUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (photoUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFF1C1C1E),
        child: const Icon(Icons.person, color: Color(0xFF8E8E93)),
      );
    }

    if (photoUrl.startsWith('data:image') || !photoUrl.startsWith('http')) {
      try {
        final commaIndex = photoUrl.indexOf(',');
        final base64Str = commaIndex != -1 ? photoUrl.substring(commaIndex + 1) : photoUrl;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Color(0xFF8E8E93)),
          ),
        );
      } catch (_) {
        return const Center(
          child: Icon(Icons.broken_image_rounded, color: Color(0xFF8E8E93)),
        );
      }
    }

    return Image.network(
      photoUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_rounded, color: Color(0xFF8E8E93)),
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
          ),
        );
      },
    );
  }
}


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class ExerciseMedia {
  final String name;
  final String slug;
  final String muscleGroup;
  final String? secondaryMuscles;
  final String equipment;
  final String? motorPattern;
  final String? executionCues;
  final String mediaSource;
  final String mediaUrl;
  final String? thumbnailUrl;

  const ExerciseMedia({
    required this.name,
    required this.slug,
    required this.muscleGroup,
    this.secondaryMuscles,
    required this.equipment,
    this.motorPattern,
    this.executionCues,
    required this.mediaSource,
    required this.mediaUrl,
    this.thumbnailUrl,
  });

  factory ExerciseMedia.fromJson(Map<String, dynamic> json) {
    return ExerciseMedia(
      name: json['name'] as String? ?? 'Exercício',
      slug: json['slug'] as String? ?? '',
      muscleGroup: json['muscle_group'] as String? ?? 'Geral',
      secondaryMuscles: json['secondary_muscles'] as String?,
      equipment: json['equipment'] as String? ?? 'Geral',
      motorPattern: json['motor_pattern'] as String?,
      executionCues: json['execution_cues'] as String?,
      mediaSource: json['media_source'] as String? ?? 'custom',
      mediaUrl: json['media_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class ExerciseMediaService {
  static final Map<String, ExerciseMedia?> _cache = {};

  /// Busca mídia (vídeo/animação) vinculada ao nome do exercício
  static Future<ExerciseMedia?> getMediaFor(String exerciseName) async {
    final clean = exerciseName.trim();
    if (clean.isEmpty) return null;

    final key = clean.toLowerCase();
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/exercises/media').replace(
        queryParameters: {'name': clean},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final media = ExerciseMedia.fromJson(data);
        _cache[key] = media;
        return media;
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Aviso: $e');
    }

    // Fallback local se o backend estiver acordando
    if (key.contains('sumo') || key.contains('step') || key.contains('agachamento')) {
      final fallback = ExerciseMedia(
        name: clean,
        slug: 'agachamento-sumo-step',
        muscleGroup: 'Glúteos e Adutores',
        secondaryMuscles: 'Quadríceps, Isquiotibiais',
        equipment: 'Halteres e Steps',
        motorPattern: 'Agachamento profundo com base aberta',
        executionCues:
            'Em pé sobre dois steps com afastamento maior que a largura dos ombros e pontas dos pés para fora, desça o quadril verticalmente mantendo a coluna alinhada.',
        mediaSource: 'gdrive_initial',
        mediaUrl:
            'https://drive.google.com/uc?export=download&id=17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
      );
      _cache[key] = fallback;
      return fallback;
    }

    _cache[key] = null;
    return null;
  }
}


import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
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
    String? thumb = json['thumbnail_url'] as String?;
    final mediaUrl = json['media_url'] as String? ?? '';

    // Extrai ID do Google Drive para animação/GIF in-app caso thumbnail esteja ausente
    if ((thumb == null || thumb.trim().isEmpty) && mediaUrl.isNotEmpty) {
      final regExp = RegExp(r'(?:id=|\/d\/|file\/d\/)([a-zA-Z0-9_\-]+)');
      final match = regExp.firstMatch(mediaUrl);
      if (match != null) {
        thumb = 'https://lh3.googleusercontent.com/d/${match.group(1)}';
      }
    }

    return ExerciseMedia(
      name: json['name'] as String? ?? 'Exercício',
      slug: (json['slug'] ?? json['normalized_slug']) as String? ?? '',
      muscleGroup: json['muscle_group'] as String? ?? 'Geral',
      secondaryMuscles: json['secondary_muscles'] as String?,
      equipment: json['equipment'] as String? ?? 'Geral',
      motorPattern: json['motor_pattern'] as String?,
      executionCues: json['execution_cues'] as String?,
      mediaSource: json['media_source'] as String? ?? 'custom',
      mediaUrl: mediaUrl,
      thumbnailUrl: thumb,
    );
  }

  /// Retorna a URL otimizada para demonstração visual in-app sem redirecionamento externo
  String? get inAppMediaUrl {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl!.trim();
    }
    if (mediaUrl.isNotEmpty) {
      final regExp = RegExp(r'(?:id=|\/d\/|file\/d\/)([a-zA-Z0-9_\-]+)');
      final match = regExp.firstMatch(mediaUrl);
      if (match != null) {
        return 'https://lh3.googleusercontent.com/d/${match.group(1)}';
      }
      final clean = mediaUrl.toLowerCase();
      if (clean.endsWith('.gif') || clean.endsWith('.webp') || clean.endsWith('.png') || clean.endsWith('.jpg')) {
        return mediaUrl;
      }
    }
    return null;
  }
}

class ExerciseMediaService {
  static final Map<String, ExerciseMedia> _cache = {};

  /// Busca mídia (vídeo/animação) vinculada ao nome do exercício
  static Future<ExerciseMedia?> getMediaFor(String exerciseName) async {
    final clean = exerciseName.trim();
    if (clean.isEmpty) return null;

    final key = clean.toLowerCase();
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // 1. Tenta buscar no Supabase diretamente do app (resposta instantânea em ~30ms, imune a sleep do Render)
    try {
      final supabase = Supabase.instance.client;
      final tokens = key
          .split(' ')
          .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
          .where((w) => w.length > 2 && !{'para', 'com', 'dos', 'das', 'nos', 'nas'}.contains(w))
          .toList();

      if (tokens.isNotEmpty) {
        final res = await supabase
            .from('exercise_library')
            .select('*')
            .ilike('name', '%${tokens.first}%')
            .limit(10);

        if (res.isNotEmpty) {
          // Seleciona o melhor candidato por sobreposição de palavras
          Map<String, dynamic>? best;
          int bestScore = -1;
          for (final dynamic item in res) {
            final row = item as Map<String, dynamic>;
            final rowName = (row['name'] as String? ?? '').toLowerCase();
            int score = 0;
            for (final t in tokens) {
              if (rowName.contains(t)) score += 2;
            }
            if (rowName.contains(tokens.first)) score += 3;
            if (score > bestScore) {
              bestScore = score;
              best = row;
            }
          }

          if (best != null && best['media_url'] != null && (best['media_url'] as String).isNotEmpty) {
            final media = ExerciseMedia.fromJson(best);
            _cache[key] = media;
            return media;
          }
        }
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Supabase direto info: $e');
    }

    // 2. Consulta a API backend oficial com timeout estendido de 12s
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/exercises/media').replace(
        queryParameters: {'name': clean},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));

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

    return null;
  }

  static void clearCache() {
    _cache.clear();
  }
}

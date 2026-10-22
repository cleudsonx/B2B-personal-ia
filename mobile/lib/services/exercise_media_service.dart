import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../models/workout_plan_model.dart';

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
  final bool isOfflineCached;

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
    this.isOfflineCached = false,
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
      isOfflineCached: json['is_offline_cached'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'muscle_group': muscleGroup,
      if (secondaryMuscles != null) 'secondary_muscles': secondaryMuscles,
      'equipment': equipment,
      if (motorPattern != null) 'motor_pattern': motorPattern,
      if (executionCues != null) 'execution_cues': executionCues,
      'media_source': mediaSource,
      'media_url': mediaUrl,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      'is_offline_cached': true,
    };
  }

  ExerciseMedia copyWith({
    String? name,
    String? slug,
    String? muscleGroup,
    String? secondaryMuscles,
    String? equipment,
    String? motorPattern,
    String? executionCues,
    String? mediaSource,
    String? mediaUrl,
    String? thumbnailUrl,
    bool? isOfflineCached,
  }) {
    return ExerciseMedia(
      name: name ?? this.name,
      slug: slug ?? this.slug,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      motorPattern: motorPattern ?? this.motorPattern,
      executionCues: executionCues ?? this.executionCues,
      mediaSource: mediaSource ?? this.mediaSource,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isOfflineCached: isOfflineCached ?? this.isOfflineCached,
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
      if (clean.endsWith('.gif') ||
          clean.endsWith('.webp') ||
          clean.endsWith('.png') ||
          clean.endsWith('.jpg')) {
        return mediaUrl;
      }
    }
    return null;
  }
}

class ExerciseMediaService {
  static final Map<String, ExerciseMedia> _memoryCache = {};
  static const String _kOfflineMediaCachePrefix = 'b2b_offline_media_';
  static const String _kOfflineCatalogListKey = 'b2b_offline_cached_slugs';

  static SupabaseClient? get _supabaseOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeKey(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Verifica se o exercício já se encontra no cache local (memória ou persistente)
  static Future<bool> isCached(String exerciseName) async {
    final key = _normalizeKey(exerciseName);
    if (key.isEmpty) return false;
    if (_memoryCache.containsKey(key)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_kOfflineMediaCachePrefix$key');
    } catch (_) {
      return false;
    }
  }

  /// Salva o exercício no disco local do dispositivo (SharedPreferences)
  static Future<void> _saveToDisk(String key, ExerciseMedia media) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final marked = media.copyWith(isOfflineCached: true);
      await prefs.setString(
        '$_kOfflineMediaCachePrefix$key',
        jsonEncode(marked.toJson()),
      );

      final current = prefs.getStringList(_kOfflineCatalogListKey) ?? [];
      if (!current.contains(key)) {
        current.add(key);
        await prefs.setStringList(_kOfflineCatalogListKey, current);
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Erro ao salvar cache offline: $e');
    }
  }

  /// Tenta carregar o exercício do armazenamento persistente do dispositivo
  static Future<ExerciseMedia?> _loadFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kOfflineMediaCachePrefix$key');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final media = ExerciseMedia.fromJson(decoded);
        return media.copyWith(isOfflineCached: true);
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Erro ao ler cache offline: $e');
    }
    return null;
  }

  /// Pré-carrega todos os exercícios da ficha ativa do aluno para uso offline
  static Future<int> preloadWorkoutPlan(WorkoutPlanModel? plan) async {
    if (plan == null) return 0;
    final names = <String>{};
    for (final split in plan.splits) {
      for (final ex in split.exercises) {
        if (ex.name.trim().isNotEmpty) {
          names.add(ex.name.trim());
        }
      }
    }
    return preloadExerciseNames(names.toList());
  }

  /// Pré-carrega uma lista de exercícios em segundo plano e persiste localmente
  static Future<int> preloadExerciseNames(List<String> names) async {
    int loaded = 0;
    for (final name in names) {
      try {
        final res = await getMediaFor(name);
        if (res != null) loaded++;
      } catch (_) {}
    }
    return loaded;
  }

  /// Busca mídia (vídeo/animação/biomecânica) com resolução offline-first:
  /// 1. Memória RAM
  /// 2. Armazenamento Local (SharedPreferences)
  /// 3. Supabase Direto (se houver rede)
  /// 4. Backend HTTP oficial (se houver rede)
  /// 5. Dicionário canônico offline
  static Future<ExerciseMedia?> getMediaFor(String exerciseName) async {
    final clean = exerciseName.trim();
    if (clean.isEmpty) return null;

    final key = _normalizeKey(clean);

    // 1. Memória RAM
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    // 2. Armazenamento Local Persistente (Offline First)
    final fromDisk = await _loadFromDisk(key);
    if (fromDisk != null) {
      _memoryCache[key] = fromDisk;
      return fromDisk;
    }

    // 3. Supabase Direto
    try {
      final supabase = _supabaseOrNull;
      if (supabase != null) {
        final tokens = clean
            .toLowerCase()
            .split(' ')
            .map((w) => w.replaceAll(RegExp(r'[^a-z0-9]'), ''))
            .where((w) =>
                w.length > 2 &&
                !{'para', 'com', 'dos', 'das', 'nos', 'nas', 'que'}.contains(w))
            .toList();

        if (tokens.isNotEmpty) {
          final res = await supabase
              .from('exercise_library')
              .select('*')
              .ilike('name', '%${tokens.first}%')
              .limit(10);

          if (res.isNotEmpty) {
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

            if (best != null &&
                best['media_url'] != null &&
                (best['media_url'] as String).isNotEmpty) {
              final media =
                  ExerciseMedia.fromJson(best).copyWith(isOfflineCached: true);
              _memoryCache[key] = media;
              _saveToDisk(key, media);
              return media;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Supabase offline fallback: $e');
    }

    // 4. API Backend
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/exercises/media').replace(
        queryParameters: {'name': clean},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final media = ExerciseMedia.fromJson(data).copyWith(isOfflineCached: true);
        _memoryCache[key] = media;
        _saveToDisk(key, media);
        return media;
      }
    } catch (e) {
      debugPrint('[ExerciseMediaService] Backend offline fallback: $e');
    }

    // 5. Dicionário Canônico Offline Integrado
    final fallback = _findCanonicalOfflineMedia(clean, key);
    if (fallback != null) {
      _memoryCache[key] = fallback;
      _saveToDisk(key, fallback);
      return fallback;
    }

    return null;
  }

  /// Catálogo canônico offline das principais famílias de exercícios de musculação
  static ExerciseMedia? _findCanonicalOfflineMedia(String originalName, String key) {
    // Família Peito
    if (key.contains('supino') && (key.contains('inclinad') || key.contains('halteres'))) {
      return ExerciseMedia(
        name: originalName,
        slug: 'supino-inclinado-halteres',
        muscleGroup: 'Peitoral Superior',
        secondaryMuscles: 'Deltoide Anterior, Tríceps Braquial',
        equipment: 'Halteres e Banco Inclinado',
        motorPattern: 'Empurrar Inclinado',
        executionCues:
            'Ajuste o banco em 30° a 45°. Mantenha as escápulas retraídas, cotovelos em ~45° e desça controlando o peso sem projetar os ombros à frente.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('supino') && (key.contains('reto') || key.contains('barra'))) {
      return ExerciseMedia(
        name: originalName,
        slug: 'supino-reto-barra',
        muscleGroup: 'Peitoral Maior',
        secondaryMuscles: 'Tríceps Braquial, Deltoide Anterior',
        equipment: 'Barra e Banco Reto',
        motorPattern: 'Empurrar Horizontal',
        executionCues:
            'Pés firmes no chão, arco lombar anatômico preservado, desça a barra até a linha média do esterno com cotovelos a ~60° do tronco.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('crucifixo') || key.contains('crossover') || key.contains('peck')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'crucifixo-halteres',
        muscleGroup: 'Peitoral Maior',
        secondaryMuscles: 'Deltoide Anterior',
        equipment: 'Halteres / Polia',
        motorPattern: 'Adução Horizontal',
        executionCues:
            'Leve flexão nos cotovelos durante todo o movimento. Abra até sentir o alongamento máximo do peitoral sem sobrecarregar a cápsula anterior do ombro.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }

    // Família Costas
    if (key.contains('puxada') || key.contains('pulldown') || key.contains('barra_fixa')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'puxada-alta-aberta',
        muscleGroup: 'Latíssimo do Dorso',
        secondaryMuscles: 'Bíceps Braquial, Redondo Maior, Romboides',
        equipment: 'Polia Alta',
        motorPattern: 'Puxar Vertical',
        executionCues:
            'Inicie o movimento deprimindo as escápulas. Puxe a barra em direção à parte superior do peitoral mantendo o peito estufado.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('remada')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'remada-baixa-triangulo',
        muscleGroup: 'Dorsal e Meio das Costas',
        secondaryMuscles: 'Romboides, Trapézio, Bíceps',
        equipment: 'Polia / Barra / Halteres',
        motorPattern: 'Puxar Horizontal',
        executionCues:
            'Mantenha a coluna neutra. Puxe os cotovelos para trás junto às costelas, comprimindo as escápulas no final do movimento.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }

    // Família Pernas
    if (key.contains('agachamento') || key.contains('squat') || key.contains('bulgaro') || key.contains('sumo')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'agachamento-livre',
        muscleGroup: 'Quadríceps e Glúteos',
        secondaryMuscles: 'Isquiotibiais, Adutores, Core',
        equipment: 'Barra Olímpica / Halteres',
        motorPattern: 'Agachamento',
        executionCues:
            'Distribua o peso em todo o pé (tripé plantar). Joelhos alinhados com a ponta dos pés e coluna ereta durante toda a descida.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('leg_press') || key.contains('extensora')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'leg-press-45',
        muscleGroup: 'Quadríceps',
        secondaryMuscles: 'Glúteo Máximo',
        equipment: 'Aparelho Leg Press',
        motorPattern: 'Extensão de Joelho e Quadril',
        executionCues:
            'Pés na largura dos ombros. Desça até 90° sem arredondar a lombar nem desencostar o quadril do encosto. Nunca hiperestenda os joelhos no topo.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('flexora') || key.contains('stiff') || key.contains('isquio')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'mesa-flexora',
        muscleGroup: 'Isquiotibiais (Posterior de Coxa)',
        secondaryMuscles: 'Glúteos, Gastrocnêmio',
        equipment: 'Mesa / Cadeira Flexora',
        motorPattern: 'Flexão de Joelho / Dobradiça',
        executionCues:
            'Mantenha o quadril pressionado contra o banco. Flexione os joelhos controlando tanto a subida quanto o retorno excêntrico.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('panturrilha') || key.contains('gemeos')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'panturrilha-em-pe',
        muscleGroup: 'Panturrilhas (Gastrocnêmio e Sóleo)',
        secondaryMuscles: 'Pés e Tornozelos',
        equipment: 'Máquina de Panturrilha / Step',
        motorPattern: 'Flexão Plantar',
        executionCues:
            'Alongue completamente no ponto mais baixo e suba na ponta dos pés com pausa isométrica de 1 segundo na contração máxima.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }

    // Família Ombros
    if (key.contains('elevacao') || key.contains('desenvolvimento') || key.contains('ombro') || key.contains('deltoid')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'elevacao-lateral-halteres',
        muscleGroup: 'Deltoide Lateral',
        secondaryMuscles: 'Trapézio, Supraespinhal',
        equipment: 'Halteres',
        motorPattern: 'Abdução de Ombro no Plano Escapular',
        executionCues:
            'Eleve os braços levemente à frente do corpo (plano escapular, ~30°). Não use impulso do tronco e mantenha os ombros abaixados.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }

    // Família Braços
    if (key.contains('rosca') || key.contains('biceps')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'rosca-direta',
        muscleGroup: 'Bíceps Braquial',
        secondaryMuscles: 'Braquial, Braquiorradial',
        equipment: 'Barra W / Halteres',
        motorPattern: 'Flexão de Cotovelo',
        executionCues:
            'Cotovelos alinhados junto ao tronco sem balanço. Contraia o bíceps no topo sem elevar os cotovelos para a frente.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }
    if (key.contains('triceps') || key.contains('corda') || key.contains('testa')) {
      return ExerciseMedia(
        name: originalName,
        slug: 'triceps-corda-polia',
        muscleGroup: 'Tríceps Braquial',
        secondaryMuscles: 'Ancôneo',
        equipment: 'Polia com Corda',
        motorPattern: 'Extensão de Cotovelo',
        executionCues:
            'Estenda os cotovelos completamente abrindo a corda no final. Mantenha os braços colados ao tronco e os ombros estáveis.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
        isOfflineCached: true,
      );
    }

    // Fallback estruturado inteligente para qualquer outro exercício
    return ExerciseMedia(
      name: originalName,
      slug: key,
      muscleGroup: 'Musculação Geral',
      secondaryMuscles: 'Músculos Estabilizadores e Core',
      equipment: 'Equipamento de Academia',
      motorPattern: 'Movimento Muscular Controlado',
      executionCues:
          'Mantenha a postura ereta e a coluna neutra. Execute a fase excêntrica de forma controlada (2-3s) e a concêntrica com potência.',
      mediaSource: 'generic_offline_fallback',
      mediaUrl: 'https://lh3.googleusercontent.com/d/17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa',
      isOfflineCached: true,
    );
  }

  /// Limpa cache em memória e armazenamento persistente
  static Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList(_kOfflineCatalogListKey) ?? [];
      for (final key in currentList) {
        await prefs.remove('$_kOfflineMediaCachePrefix$key');
      }
      await prefs.remove(_kOfflineCatalogListKey);
    } catch (_) {}
  }
}

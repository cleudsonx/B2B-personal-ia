import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Modelo de medição antropométrica de evolução corporal (Bio-Hub 2.0).
class BodyMetricsRecord {
  final String id;
  final String studentId;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPct;
  final double? waistCm;
  final double? hipCm;
  final double? chestCm;
  final double? armRightCm;
  final double? armLeftCm;
  final double? thighRightCm;
  final double? thighLeftCm;
  final String? notes;
  final DateTime measuredAt;

  const BodyMetricsRecord({
    required this.id,
    required this.studentId,
    this.weightKg,
    this.heightCm,
    this.bodyFatPct,
    this.waistCm,
    this.hipCm,
    this.chestCm,
    this.armRightCm,
    this.armLeftCm,
    this.thighRightCm,
    this.thighLeftCm,
    this.notes,
    required this.measuredAt,
  });

  /// Cálculo automático de IMC (Índice de Massa Corporal)
  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final hMeters = heightCm! / 100.0;
    return weightKg! / (hMeters * hMeters);
  }

  String get bmiCategory {
    final val = bmi;
    if (val == null) return 'Não calculado';
    if (val < 18.5) return 'Abaixo do peso';
    if (val < 25.0) return 'Peso saudável';
    if (val < 30.0) return 'Sobrepeso';
    if (val < 35.0) return 'Obesidade Grau I';
    return 'Obesidade Grau II/III';
  }

  factory BodyMetricsRecord.fromJson(Map<String, dynamic> json) {
    return BodyMetricsRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
      waistCm: (json['waist_cm'] as num?)?.toDouble(),
      hipCm: (json['hip_cm'] as num?)?.toDouble(),
      chestCm: (json['chest_cm'] as num?)?.toDouble(),
      armRightCm: (json['arm_right_cm'] as num?)?.toDouble(),
      armLeftCm: (json['arm_left_cm'] as num?)?.toDouble(),
      thighRightCm: (json['thigh_right_cm'] as num?)?.toDouble(),
      thighLeftCm: (json['thigh_left_cm'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      measuredAt: json['measured_at'] != null
          ? DateTime.tryParse(json['measured_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'body_fat_pct': bodyFatPct,
        'waist_cm': waistCm,
        'hip_cm': hipCm,
        'chest_cm': chestCm,
        'arm_right_cm': armRightCm,
        'arm_left_cm': armLeftCm,
        'thigh_right_cm': thighRightCm,
        'thigh_left_cm': thighLeftCm,
        'notes': notes,
        'measured_at': measuredAt.toIso8601String(),
      };
}

class BodyMetricsService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static String _cacheKey(String studentId) => 'student_body_metrics_$studentId';

  /// Busca histórico ordenado de medições corporais (com fallback retrocompatível da Anamnese/Perfil)
  static Future<List<BodyMetricsRecord>> getMetricsHistory(String studentId) async {
    final client = _clientOrNull;
    if (client != null) {
      try {
        final List<dynamic> res = await client
            .from('student_body_metrics')
            .select('*')
            .eq('student_id', studentId)
            .order('measured_at', ascending: false);

        if (res.isNotEmpty) {
          final list = res.map((e) => BodyMetricsRecord.fromJson(Map<String, dynamic>.from(e))).toList();
          await _saveListToLocalCache(studentId, list);
          return list;
        }
      } catch (e) {
        debugPrint('[BodyMetricsService] Erro ao buscar métricas remotas: $e');
      }
    }

    final cached = await _loadListFromLocalCache(studentId);
    if (cached.isNotEmpty) return cached;

    // Fallback retrocompatível: hidrata a partir da Anamnese ou Perfil existente do aluno
    if (client != null) {
      try {
        final anamnesis = await client
            .from('anamnesis')
            .select('*')
            .eq('client_id', studentId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        double? weight;
        double? height;
        DateTime? date;

        if (anamnesis != null) {
          final details = (anamnesis['details'] as Map<String, dynamic>?) ?? {};
          weight = _parseNum(anamnesis['weight'] ?? details['weight']);
          height = _parseNum(anamnesis['height'] ?? details['height']);
          final rawDate = (anamnesis['completed_at'] ?? anamnesis['created_at'])?.toString();
          if (rawDate != null) date = DateTime.tryParse(rawDate);
        }

        if (weight == null || height == null) {
          final profile = await client
              .from('profiles')
              .select('weight_kg, height_cm, updated_at, created_at')
              .eq('id', studentId)
              .maybeSingle();
          if (profile != null) {
            weight ??= _parseNum(profile['weight_kg']);
            height ??= _parseNum(profile['height_cm']);
            final rawDate = (profile['updated_at'] ?? profile['created_at'])?.toString();
            if (rawDate != null && date == null) date = DateTime.tryParse(rawDate);
          }
        }

        if (height != null && height > 0 && height < 3.0) {
          height = height * 100.0; // Converte metros (ex: 1.75) para cm (175)
        }

        if ((weight != null && weight > 0) || (height != null && height > 0)) {
          final baseline = BodyMetricsRecord(
            id: 'baseline_$studentId',
            studentId: studentId,
            weightKg: weight,
            heightCm: height,
            notes: 'Marco Inicial (Anamnese)',
            measuredAt: date ?? DateTime.now(),
          );
          await _saveListToLocalCache(studentId, [baseline]);
          return [baseline];
        }
      } catch (e) {
        debugPrint('[BodyMetricsService] Aviso ao hidratar medidas da anamnese: $e');
      }
    }

    return [];
  }

  static double? _parseNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().replaceAll(',', '.').trim());
  }

  /// Busca a medição corporal mais recente
  static Future<BodyMetricsRecord?> getLatestMetrics(String studentId) async {
    final history = await getMetricsHistory(studentId);
    return history.isNotEmpty ? history.first : null;
  }

  /// Registra uma nova medição corporal
  static Future<BodyMetricsRecord?> saveMetrics({
    String? targetStudentId,
    double? weightKg,
    double? heightCm,
    double? bodyFatPct,
    double? waistCm,
    double? hipCm,
    double? chestCm,
    double? armRightCm,
    double? armLeftCm,
    double? thighRightCm,
    double? thighLeftCm,
    String? notes,
  }) async {
    final studentId = targetStudentId ?? AuthService.currentUser?.id;
    if (studentId == null || studentId.isEmpty) return null;

    double? normalizedHeight = heightCm;
    if (normalizedHeight != null && normalizedHeight > 0 && normalizedHeight < 3.0) {
      normalizedHeight = normalizedHeight * 100.0;
    }

    final now = DateTime.now();
    final tempId = 'metric_${now.millisecondsSinceEpoch}';

    final record = BodyMetricsRecord(
      id: tempId,
      studentId: studentId,
      weightKg: weightKg,
      heightCm: normalizedHeight,
      bodyFatPct: bodyFatPct,
      waistCm: waistCm,
      hipCm: hipCm,
      chestCm: chestCm,
      armRightCm: armRightCm,
      armLeftCm: armLeftCm,
      thighRightCm: thighRightCm,
      thighLeftCm: thighLeftCm,
      notes: notes,
      measuredAt: now,
    );

    final client = _clientOrNull;
    if (client != null) {
      try {
        final res = await client.from('student_body_metrics').insert({
          'student_id': studentId,
          'weight_kg': weightKg,
          'height_cm': normalizedHeight,
          'body_fat_pct': bodyFatPct,
          'waist_cm': waistCm,
          'hip_cm': hipCm,
          'chest_cm': chestCm,
          'arm_right_cm': armRightCm,
          'arm_left_cm': armLeftCm,
          'thigh_right_cm': thighRightCm,
          'thigh_left_cm': thighLeftCm,
          'notes': notes,
          'measured_at': now.toIso8601String(),
        }).select().maybeSingle();

        if (res != null) {
          final saved = BodyMetricsRecord.fromJson(res);
          await _appendLocalRecord(studentId, saved);
          return saved;
        }
      } catch (e) {
        debugPrint('[BodyMetricsService] Erro ao persistir remoto: $e');
      }
    }

    // Salva localmente com garantia imediata
    await _appendLocalRecord(studentId, record);
    return record;
  }

  static Future<void> _appendLocalRecord(String studentId, BodyMetricsRecord record) async {
    final current = await _loadListFromLocalCache(studentId);
    current.removeWhere((r) => r.id == record.id);
    current.insert(0, record);
    await _saveListToLocalCache(studentId, current);
  }

  static Future<void> _saveListToLocalCache(String studentId, List<BodyMetricsRecord> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey(studentId), jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<BodyMetricsRecord>> _loadListFromLocalCache(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(studentId));
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => BodyMetricsRecord.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}
    return [];
  }
}


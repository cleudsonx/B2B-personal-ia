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

  /// Busca histórico ordenado de medições corporais
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

    return _loadListFromLocalCache(studentId);
  }

  /// Busca a medição corporal mais recente
  static Future<BodyMetricsRecord?> getLatestMetrics(String studentId) async {
    final history = await getMetricsHistory(studentId);
    return history.isNotEmpty ? history.first : null;
  }

  /// Registra uma nova medição corporal
  static Future<BodyMetricsRecord?> saveMetrics({
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
    final user = AuthService.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    final tempId = 'metric_${now.millisecondsSinceEpoch}';

    final record = BodyMetricsRecord(
      id: tempId,
      studentId: user.id,
      weightKg: weightKg,
      heightCm: heightCm,
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
          'student_id': user.id,
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
          'measured_at': now.toIso8601String(),
        }).select().maybeSingle();

        if (res != null) {
          final saved = BodyMetricsRecord.fromJson(res);
          await _appendLocalRecord(user.id, saved);
          return saved;
        }
      } catch (e) {
        debugPrint('[BodyMetricsService] Erro ao persistir remoto: $e');
      }
    }

    // Salva localmente com garantia imediata
    await _appendLocalRecord(user.id, record);
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


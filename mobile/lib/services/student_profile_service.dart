import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import 'auth_service.dart';

const String kNoRestriction = 'Nenhuma';
const List<String> kStudentRestrictionOptions = [
  kNoRestriction,
  'Dor Lombar',
  'Condromalácia (Joelho)',
  'Manguito Rotador (Ombro)',
  'Hérnia de Disco',
  'Gestante',
  'Hipertensão',
  'Cotovelo / Tendinopatia',
  'Punho',
  'Quadril',
];

/// Dados persistidos do perfil/anamnese do aluno autenticado.
class StudentProfileData {
  final String name;
  final int? age;
  final double? weightKg;
  final int? heightCm;
  final Set<String> restrictions;
  final String? trainerId;
  final String timezone;

  const StudentProfileData({
    required this.name,
    this.age,
    this.weightKg,
    this.heightCm,
    required this.restrictions,
    this.trainerId,
    this.timezone = 'UTC',
  });

  String get restrictionsText => restrictions.join(', ');

  factory StudentProfileData.fromRow(Map<String, dynamic> row) {
    final raw = (row['clinical_restrictions'] as String?)?.trim() ?? '';
    final parsed = raw.isEmpty
        ? <String>{kNoRestriction}
        : raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final timezoneValue = ((row['timezone'] as String?) ?? '').trim();
    return StudentProfileData(
      name: (row['full_name'] as String?) ?? '',
      age: (row['age'] as num?)?.toInt(),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      heightCm: (row['height_cm'] as num?)?.toInt(),
      restrictions: parsed.isEmpty ? {kNoRestriction} : parsed,
      trainerId: row['trainer_id'] as String?,
      timezone: timezoneValue.isEmpty ? 'UTC' : timezoneValue,
    );
  }
}

/// Validação dos campos do formulário. Retorna mapa campo -> mensagem.
class StudentProfileValidator {
  static double? parseDecimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static Map<String, String> validate({
    required String name,
    required String age,
    required String weight,
    required String height,
  }) {
    final errors = <String, String>{};
    final n = name.trim();
    if (n.length < 2) {
      errors['name'] = 'Informe seu nome completo.';
    } else if (n.length > 100) {
      errors['name'] = 'Nome muito longo (máx. 100 caracteres).';
    }

    if (age.trim().isNotEmpty) {
      final v = int.tryParse(age.trim());
      if (v == null || v < 10 || v > 100) {
        errors['age'] = 'Idade entre 10 e 100.';
      }
    }
    if (weight.trim().isNotEmpty) {
      final v = parseDecimal(weight);
      if (v == null || v < 20 || v > 300) {
        errors['weight'] = 'Peso entre 20 e 300 kg.';
      }
    }
    if (height.trim().isNotEmpty) {
      final v = int.tryParse(height.trim());
      if (v == null || v < 100 || v > 250) {
        errors['height'] = 'Altura entre 100 e 250 cm.';
      }
    }
    return errors;
  }
}

/// Estado da revisão do treino após alteração de restrições.
enum ReviewStatus {
  /// Restrições não mudaram: nenhuma revisão necessária.
  notNeeded,

  /// Professor foi efetivamente notificado (alerta persistido, confirmado pela API).
  requested,

  /// Aluno ainda não tem professor vinculado: não há quem revise.
  noTrainer,

  /// Tentativa de notificar falhou; usuário pode tentar de novo.
  failed,
}

class SaveResult {
  final ReviewStatus review;
  const SaveResult(this.review);
}

/// Acesso a dados; abstrato para permitir testes sem rede.
abstract class StudentProfileGateway {
  Future<Map<String, dynamic>?> fetchProfile(String userId);

  /// Deve lançar exceção se nenhuma linha foi atualizada.
  Future<void> updateProfile(String userId, Map<String, dynamic> values);

  /// Retorna true somente se a API confirmou a criação do alerta.
  Future<bool> sendReviewAlert({
    required String studentId,
    required String studentName,
    required String trainerId,
    required String restrictions,
  });
}

class SupabaseStudentProfileGateway implements StudentProfileGateway {
  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return Supabase.instance.client
        .from('profiles')
        .select(
            'full_name, age, weight_kg, height_cm, clinical_restrictions, trainer_id, timezone')
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> values) async {
    final rows = await Supabase.instance.client
        .from('profiles')
        .update(values)
        .eq('id', userId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw Exception('Perfil não foi atualizado (sem permissão ou inexistente).');
    }
  }

  @override
  Future<bool> sendReviewAlert({
    required String studentId,
    required String studentName,
    required String trainerId,
    required String restrictions,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if ((AuthService.accessToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${AuthService.accessToken}',
      };
      final res = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/workouts/adaptations/alert'),
            headers: headers,
            body: jsonEncode({
              'student_id': studentId,
              'student_name': studentName,
              'trainer_id': trainerId,
              'original_exercise': 'Ficha atual',
              'adapted_exercise': 'Revisão pendente do professor',
              'reason': 'Aluno atualizou restrições clínicas: $restrictions',
              'severity': 'Moderada',
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}

class StudentProfileService {
  final StudentProfileGateway gateway;
  StudentProfileService({StudentProfileGateway? gateway})
      : gateway = gateway ?? SupabaseStudentProfileGateway();

  /// Lança exceção em erro; retorna null se o perfil não existe.
  Future<StudentProfileData?> load(String userId) async {
    final row = await gateway.fetchProfile(userId);
    return row == null ? null : StudentProfileData.fromRow(row);
  }

  /// Persiste e só então tenta a revisão. Exceção de persistência propaga.
  Future<SaveResult> save({
    required String userId,
    required StudentProfileData original,
    required StudentProfileData updated,
  }) async {
    await gateway.updateProfile(userId, {
      'full_name': updated.name.trim(),
      'age': updated.age,
      'weight_kg': updated.weightKg,
      'height_cm': updated.heightCm,
      'clinical_restrictions': updated.restrictionsText,
      'timezone': updated.timezone.isEmpty ? 'UTC' : updated.timezone,
    });
    if (original.restrictionsText == updated.restrictionsText) {
      return const SaveResult(ReviewStatus.notNeeded);
    }
    return SaveResult(await requestReview(userId: userId, data: updated));
  }

  Future<ReviewStatus> requestReview({
    required String userId,
    required StudentProfileData data,
  }) async {
    final trainerId = data.trainerId;
    if (trainerId == null || trainerId.isEmpty) return ReviewStatus.noTrainer;
    final ok = await gateway.sendReviewAlert(
      studentId: userId,
      studentName: data.name,
      trainerId: trainerId,
      restrictions: data.restrictionsText,
    );
    return ok ? ReviewStatus.requested : ReviewStatus.failed;
  }
}


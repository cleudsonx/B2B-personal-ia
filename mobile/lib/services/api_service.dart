import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/workout_plan_model.dart';
import '../models/adaptation_model.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
      _client = client ?? http.Client();

  Map<String, String> _buildHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final activeToken =
        (token != null && token.isNotEmpty) ? token : AuthService.accessToken;
    if (activeToken != null && activeToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $activeToken';
    }
    return headers;
  }

  /// Gera a periodização completa chamando o endpoint do backend
  Future<WorkoutPlanModel> generateWorkoutPlan({
    required String objective,
    required String trainingLevel,
    required int daysPerWeek,
    required String workoutLocation,
    required String injuriesOrRestrictions,
    String splitType = 'Automático (IA Sugere)',
    String? targetFocus,
    String? additionalNotes,
    String? authToken,
  }) async {
    final payload = <String, dynamic>{
      'objective': objective,
      'training_level': trainingLevel,
      'days_per_week': daysPerWeek,
      'workout_location': workoutLocation,
      'injuries_or_restrictions': injuriesOrRestrictions,
      'split_type': splitType,
    };
    if (targetFocus != null && targetFocus.isNotEmpty) {
      payload['target_focus'] = targetFocus;
    }
    if (additionalNotes != null && additionalNotes.isNotEmpty) {
      payload['additional_notes'] = additionalNotes;
    }
    final body = jsonEncode(payload);
    final uri = Uri.parse('$baseUrl/workouts/generate-plan');

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: authToken),
      body: body,
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return WorkoutPlanModel.fromJson(data);
    } else {
      String errorMessage =
          'Falha ao gerar treino (Status ${response.statusCode})';
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorJson['detail'] != null) {
          errorMessage = errorJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Substitui um exercício em tempo real no salão de musculação
  Future<AdaptationModel> adaptExercise({
    required String currentExercise,
    required String reason,
    required String workoutLocation,
    String? injuriesOrRestrictions,
    String? authToken,
  }) async {
    final uri = Uri.parse('$baseUrl/adaptations/adapt-exercise');
    final body = jsonEncode({
      'current_exercise': currentExercise,
      'reason': reason,
      'workout_location': workoutLocation,
      'injuries_or_restrictions': injuriesOrRestrictions ?? 'Nenhuma',
    });

    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(token: authToken),
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AdaptationModel.fromJson(data);
      }
    } catch (_) {
      // Cai para a contingência biomecânica local de alta disponibilidade
    }

    return buildContingencyAdaptation(
      currentExercise: currentExercise,
      reason: reason,
    );
  }

  /// Contingência Biomecânica de Alta Disponibilidade (Zero Downtime no Salão)
  static AdaptationModel buildContingencyAdaptation({
    required String currentExercise,
    required String reason,
  }) {
    final lower = currentExercise.toLowerCase();
    String adapted;
    String notes;
    String rationale;

    if (lower.contains('abdom') ||
        lower.contains('crunch') ||
        lower.contains('prancha') ||
        lower.contains('infra') ||
        lower.contains('supra')) {
      adapted = lower.contains('polia')
          ? 'Abdominal Supra na Máquina Articulada'
          : 'Abdominal Crunch na Polia Alta com Corda';
      notes =
          'Cadência 2-0-1-1. Flexionar a coluna torácica aproximando as costelas da pelve sem movimentar o quadril.';
      rationale =
          'Mantém a curva de resistência constante na flexão espinhal para isolamento do reto abdominal.';
    } else if (lower.contains('supino') ||
        lower.contains('peito') ||
        lower.contains('crucifixo') ||
        lower.contains('voador')) {
      adapted = (lower.contains('máquina') || lower.contains('maquina'))
          ? 'Supino Inclinado com Halteres'
          : 'Supino Inclinado na Máquina Articulada';
      notes =
          'Ajustar o assento na linha do peitoral superior. Manter escápulas aduzidas e deprimidas.';
      rationale =
          'Reduz o estresse glenoumeral anterior mantendo a trajetória controlada no vetor de empurrar horizontal.';
    } else if (lower.contains('desenvolvimento') ||
        lower.contains('ombro') ||
        lower.contains('elevação') ||
        lower.contains('elevacao')) {
      adapted = lower.contains('eleva')
          ? 'Elevação Lateral na Polia Baixa'
          : 'Desenvolvimento na Máquina Convergente';
      notes =
          'Pegada neutra ou semi-pronada. Cotovelos levemente à frente no plano escapular (30°).';
      rationale =
          'Diminui a compressão no manguito rotador preservando o recrutamento do deltoide.';
    } else if (lower.contains('triceps') ||
        lower.contains('tríceps') ||
        lower.contains('testa') ||
        lower.contains('francês')) {
      adapted = lower.contains('polia')
          ? 'Tríceps Francês Unilateral com Halter'
          : 'Tríceps na Polia com Corda';
      notes =
          'Cotovelos fixos ao lado do tronco. Estender completamente enfatizando a contração máxima.';
      rationale =
          'Isola o tríceps braquial com tensão mecânica contínua sem sobrecarga articular no olécrano.';
    } else if (lower.contains('biceps') ||
        lower.contains('bíceps') ||
        lower.contains('rosca')) {
      adapted = (lower.contains('halter') || lower.contains('barra'))
          ? 'Rosca Direta na Polia Baixa'
          : 'Rosca Alternada no Banco Inclinado 45°';
      notes =
          'Manter ombros estabilizados em extensão para enfatizar a cabeça longa do bíceps.';
      rationale =
          'Preserva o torque de flexão de cotovelo com excelente perfil de resistência no alongamento.';
    } else if (lower.contains('stiff') ||
        lower.contains('rdl') ||
        lower.contains('flexora') ||
        lower.contains('posterior')) {
      adapted = (lower.contains('mesa') || lower.contains('stiff'))
          ? 'Cadeira Flexora Sentado'
          : 'Mesa Flexora Deitado';
      notes =
          'Manter a pelve neutra apoiada e controlar a fase excêntrica em 3 segundos.';
      rationale =
          'Otimiza a relação comprimento-tensão dos isquiotibiais reduzindo o cisalhamento lombar.';
    } else if (lower.contains('agachamento') ||
        lower.contains('leg') ||
        lower.contains('perna') ||
        lower.contains('extensora') ||
        lower.contains('hack')) {
      adapted = lower.contains('leg')
          ? 'Agachamento Hack Machine'
          : 'Leg Press 45° com Pés Médios';
      notes =
          'Pés apoiados na largura dos ombros. Manter lombar 100% apoiada no encosto.';
      rationale =
          'Permite sobrecarga nos extensores de joelho e quadril com descarga axial da coluna vertebral.';
    } else if (lower.contains('puxada') ||
        lower.contains('remada') ||
        lower.contains('costas') ||
        lower.contains('dorsal') ||
        lower.contains('pulldown')) {
      adapted = lower.contains('remada')
          ? 'Puxada Alta com Triângulo (Pegada Neutra)'
          : 'Remada Sentada na Máquina com Apoio no Peito';
      notes =
          'Manter o esterno apoiado. Puxar cotovelos em direção ao quadril.';
      rationale =
          'Elimina a demanda estabilizadora sobre os eretores da espinha, focando na adução escapular e latíssimo.';
    } else if (lower.contains('panturrilha') ||
        lower.contains('gêmeos') ||
        lower.contains('gemeos') ||
        lower.contains('sóleo')) {
      adapted = (lower.contains('leg') || lower.contains('pé'))
          ? 'Panturrilha Sentado na Máquina (Sóleo)'
          : 'Panturrilha no Leg Press Horizontal';
      notes =
          'Amplitude máxima no alongamento com 1 segundo de pausa no topo.';
      rationale =
          'Mantém o estímulo no tríceps sural eliminando o reflexo miotático de rebote no tendão calcâneo.';
    } else {
      adapted = '$currentExercise (Variação Guiada na Máquina)';
      notes =
          'Mantenha a postura alinhada, execute a fase excêntrica em 3 segundos e evite movimentos balísticos.';
      rationale =
          'Substituição motivada por: "$reason". Preserva o mesmo vetor biomecânico e ativação muscular com maior estabilidade.';
    }

    return AdaptationModel(
      originalExercise: currentExercise,
      adaptedExercise: adapted,
      reason: reason,
      sets: 3,
      reps: '10-12',
      restSeconds: 60,
      notes: notes,
      biomechanicalRationale: rationale,
    );
  }
}

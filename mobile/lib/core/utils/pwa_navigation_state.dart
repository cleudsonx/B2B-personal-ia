import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerenciador de persistência de navegação e rotas para PWA e recarregamentos.
///
/// Garante que, ao aceitar uma atualização ou recarregar o navegador,
/// o usuário retorne exatamente à aba, tela ou recurso que estava visualizando.
class PwaNavigationState {
  static const _keyTrainerTab = 'pwa_last_trainer_tab';
  static const _keyStudentTab = 'pwa_last_student_tab';
  static const _keyActiveSubscreen = 'pwa_last_active_subscreen';

  /// Salva a aba ativa do treinador (0: Alunos, 1: Treinos, 2: Social, 3: Vitrine, 4: Conta)
  static Future<void> saveTrainerTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTrainerTab, index);
    } catch (e) {
      debugPrint('[PwaNavigationState] Erro ao salvar aba do treinador: $e');
    }
  }

  /// Recupera a última aba ativa do treinador
  static Future<int?> getTrainerTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyTrainerTab);
    } catch (_) {
      return null;
    }
  }

  /// Salva a aba ativa do aluno (0: Treino, 1: IA, 2: Bio Hub, 3: Perfil)
  static Future<void> saveStudentTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStudentTab, index);
    } catch (e) {
      debugPrint('[PwaNavigationState] Erro ao salvar aba do aluno: $e');
    }
  }

  /// Recupera a última aba ativa do aluno
  static Future<int?> getStudentTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyStudentTab);
    } catch (_) {
      return null;
    }
  }

  /// Registra uma subtela ou recurso aberto (ex: 'trainer_profile_setup', 'whatsapp_connection')
  static Future<void> saveActiveSubscreen(String screenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveSubscreen, screenId);
    } catch (e) {
      debugPrint('[PwaNavigationState] Erro ao salvar subtela ativa: $e');
    }
  }

  /// Limpa a subtela ativa (quando o usuário sai da tela)
  static Future<void> clearActiveSubscreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveSubscreen);
    } catch (_) {}
  }

  /// Consome a subtela ativa (recupera e apaga para evitar loops)
  static Future<String?> consumeActiveSubscreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final screen = prefs.getString(_keyActiveSubscreen);
      if (screen != null) {
        await prefs.remove(_keyActiveSubscreen);
      }
      return screen;
    } catch (_) {
      return null;
    }
  }
}


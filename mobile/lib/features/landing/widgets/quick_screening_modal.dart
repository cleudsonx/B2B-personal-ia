import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/public_showcase_model.dart';
import '../../../services/api_service.dart';

class QuickScreeningModal extends StatefulWidget {
  final String username;
  final String trainerName;
  final String? trainerPhone;
  final ApiService? apiService;

  const QuickScreeningModal({
    super.key,
    required this.username,
    required this.trainerName,
    this.trainerPhone,
    this.apiService,
  });

  static Future<void> show(
    BuildContext context, {
    required String username,
    required String trainerName,
    String? trainerPhone,
    ApiService? apiService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickScreeningModal(
        username: username,
        trainerName: trainerName,
        trainerPhone: trainerPhone,
        apiService: apiService,
      ),
    );
  }

  @override
  State<QuickScreeningModal> createState() => _QuickScreeningModalState();
}

class _QuickScreeningModalState extends State<QuickScreeningModal> {
  late final ApiService _apiService;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedGoal = 'Hipertrofia';
  final Set<String> _selectedPains = {};
  int _frequencyWeekly = 3;
  String _activityLevel = 'iniciante';

  bool _isSubmitting = false;
  String? _errorMessage;
  LeadScreeningResponse? _response;

  final List<String> _goals = [
    'Hipertrofia',
    'Emagrecimento',
    'Alívio de Dores',
    'Condicionamento Físico',
  ];

  final List<String> _availablePains = [
    'Lombar',
    'Ombro',
    'Joelho',
    'Cervical',
    'Nenhuma dor',
  ];

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final effectivePains = _selectedPains.contains('Nenhuma dor')
          ? <String>[]
          : _selectedPains.toList();

      final request = LeadScreeningRequest(
        leadName: _nameController.text.trim(),
        leadPhone: _phoneController.text.trim(),
        goal: _selectedGoal,
        jointPains: effectivePains,
        trainingFrequencyWeekly: _frequencyWeekly,
        currentActivityLevel: _activityLevel,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      final res = await _apiService.submitLeadScreening(widget.username, request);

      if (mounted) {
        setState(() {
          _response = res;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao processar triagem. Tente novamente.';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openWhatsApp(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF00E676);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_response != null)
              _buildSuccessView(isDark, primaryColor)
            else
              _buildFormView(isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(bool isDark, Color primaryColor) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.biotech_rounded, color: Color(0xFF00E676), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Triagem Biomecânica Rápida',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Para o time de ${widget.trainerName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Nome
          TextFormField(
            key: const Key('input_lead_name'),
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Seu Nome Completo',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: isDark ? const Color(0xFF14171E) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
          ),
          const SizedBox(height: 12),

          // Telefone / WhatsApp
          TextFormField(
            key: const Key('input_lead_phone'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Seu WhatsApp (com DDD)',
              prefixIcon: const Icon(Icons.phone_outlined),
              filled: true,
              fillColor: isDark ? const Color(0xFF14171E) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            validator: (v) => (v == null || v.trim().length < 8) ? 'Informe um WhatsApp válido' : null,
          ),
          const SizedBox(height: 16),

          // Objetivo Principal
          const Text(
            'Qual o seu objetivo prioritário?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.map((g) {
              final isSelected = _selectedGoal == g;
              return ChoiceChip(
                key: Key('chip_goal_$g'),
                label: Text(g),
                selected: isSelected,
                selectedColor: primaryColor.withValues(alpha: 0.25),
                onSelected: (val) {
                  if (val) setState(() => _selectedGoal = g);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Desconfortos / Dores Articulares
          const Text(
            'Possui algum incômodo ou dor articular?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availablePains.map((p) {
              final isSelected = _selectedPains.contains(p);
              return FilterChip(
                key: Key('chip_pain_$p'),
                label: Text(p),
                selected: isSelected,
                selectedColor: Colors.amber.withValues(alpha: 0.25),
                onSelected: (val) {
                  setState(() {
                    if (p == 'Nenhuma dor') {
                      _selectedPains.clear();
                      if (val) _selectedPains.add('Nenhuma dor');
                    } else {
                      _selectedPains.remove('Nenhuma dor');
                      if (val) {
                        _selectedPains.add(p);
                      } else {
                        _selectedPains.remove(p);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Frequência Semanal
          const Text(
            'Quantos dias você pretende treinar por semana?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [2, 3, 4, 5, 6].map((d) {
              final isSelected = _frequencyWeekly == d;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    key: Key('chip_freq_$d'),
                    label: Text('${d}x'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _frequencyWeekly = d);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Nível de Condicionamento
          const Text(
            'Qual o seu nível de experiência atual?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ('iniciante', 'Iniciante'),
              ('intermediario', 'Intermediário'),
              ('avancado', 'Avançado'),
            ].map((entry) {
              final isSelected = _activityLevel == entry.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    key: Key('chip_level_${entry.$1}'),
                    label: Text(entry.$2),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _activityLevel = entry.$1);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),

          // Botão de Envio
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('btn_submit_screening'),
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.flash_on_rounded, color: Colors.black),
              label: Text(
                _isSubmitting ? 'Gerando Análise Cinesiológica...' : 'Gerar Análise e Conectar no WhatsApp',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark, Color primaryColor) {
    final res = _response!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 44),
              const SizedBox(height: 8),
              const Text(
                'Triagem Concluída com Sucesso! 🎉',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Confira a diretriz preliminar recomendada pela IA para o seu perfil:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Box com insight biomecânico
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14171E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  res.biomechanicalInsight,
                  style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Botão WhatsApp direto
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            key: const Key('btn_open_whatsapp_result'),
            onPressed: () => _openWhatsApp(res.whatsappDirectUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
            label: const Text(
              'Enviar Diagnóstico para o Treinador',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

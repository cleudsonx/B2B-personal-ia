import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Dados Cadastrais
  final _nameCtrl = TextEditingController(text: 'Aluno Silva');
  
  // Anamnese
  final _ageCtrl = TextEditingController(text: '28');
  final _weightCtrl = TextEditingController(text: '76.5');
  final _heightCtrl = TextEditingController(text: '178');
  
  // CondiÃ§Ãµes / RestriÃ§Ãµes
  final List<String> _availableRestrictions = [
    'Nenhuma',
    'Dor Lombar',
    'CondromalÃ¡cia (Joelho)',
    'Manguito Rotador (Ombro)',
    'HÃ©rnia de Disco',
    'Gestante',
    'HipertensÃ£o',
  ];
  final Set<String> _selectedRestrictions = {'Nenhuma'};

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // SimulaÃ§Ã£o de chamada para salvar perfil e anamnese no back-end
      await Future.delayed(const Duration(seconds: 2));
      
      // Regra de NegÃ³cio (IA): O Backend intercepta se a restriÃ§Ã£o mudou.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Perfil atualizado! A IA estÃ¡ revisando seu treino para garantir a seguranÃ§a com base nos seus novos dados.'
            ),
            backgroundColor: AppColors.emerald(context),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meu Perfil & Anamnese',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INFO PESSOAL
              Text(
                'DADOS PESSOAIS',
                style: TextStyle(
                  color: AppColors.emerald(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: AppColors.text(context)),
                decoration: InputDecoration(
                  labelText: 'Nome Completo',
                  filled: true,
                  fillColor: AppColors.card(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ANAMNESE FÃ SICA
              Text(
                'ANAMNESE FÃ SICA (IA)',
                style: TextStyle(
                  color: AppColors.emerald(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mantenha atualizado. A IA readapta seu treino automaticamente.',
                style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Idade',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        labelText: 'Altura (cm)',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // RESTRIÃ‡Ã•ES CLÃ NICAS
              Text(
                'RESTRIÃ‡Ã•ES OU LESÃ•ES ATUAIS',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: _availableRestrictions.map((r) {
                  final isSelected = _selectedRestrictions.contains(r);
                  return FilterChip(
                    label: Text(r),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (r == 'Nenhuma') {
                          _selectedRestrictions.clear();
                          _selectedRestrictions.add('Nenhuma');
                        } else {
                          _selectedRestrictions.remove('Nenhuma');
                          if (selected) {
                            _selectedRestrictions.add(r);
                          } else {
                            _selectedRestrictions.remove(r);
                            if (_selectedRestrictions.isEmpty) {
                              _selectedRestrictions.add('Nenhuma');
                            }
                          }
                        }
                      });
                    },
                    selectedColor: AppColors.danger.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.danger,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.danger : AppColors.text(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.card(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                      side: BorderSide(
                        color: isSelected ? AppColors.danger : AppColors.cardBorder(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 64),
              
              // BOTÃƒO SALVAR
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar & Revisar Treino',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



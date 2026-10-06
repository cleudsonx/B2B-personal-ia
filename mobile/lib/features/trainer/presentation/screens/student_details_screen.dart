import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';

class StudentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const StudentDetailsScreen({super.key, required this.studentData});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  late Map<String, dynamic> student;
  bool _hasActiveWorkout = false; // Mock, in the future this will be fetched from API

  @override
  void initState() {
    super.initState();
    student = widget.studentData;
    _hasActiveWorkout = student['status'] == 'Ativo'; 
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final text = Uri.encodeComponent(
      "Oi $name, vi que você ainda não acessou seu treino. Clica aqui no link para ativarmos sua periodização: https://app.shaipados.com/convite"
    );
    final url = Uri.parse("https://wa.me/$cleanPhone?text=$text");
    if (!await launchUrl(url)) {
      debugPrint("Não foi possível abrir o WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = student['status'] ?? 'Aguardando Ativação';
    final name = student['full_name'] ?? 'Aluno';
    final phone = student['phone'] ?? '';
    
    // Status colors
    Color statusColor = MetaColors.textSecondary;
    if (status == 'Ativo' || status == 'Treinando') statusColor = MetaColors.emerald;
    if (status == 'Aguardando Ativação' || status == 'Pendente Confirmação') statusColor = const Color(0xFFF59E0B); // Amber
    if (status == 'Inativo' || status == 'Arquivado') statusColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: MetaColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MetaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil do Aluno',
          style: TextStyle(color: MetaColors.textPrimary, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (Info Básica & Gamificação)
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: MetaColors.surfaceHighlight,
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: MetaColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(color: MetaColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_hasActiveWorkout)
                      const Text(
                        '🔥 14 Dias de Ofensiva',
                        style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. CONVITE E INTEGRAÇÃO (Se Pendente)
              if (status == 'Aguardando Ativação' || status == 'Pendente Confirmação') ...[
                const MetaSectionTitle(title: 'Ações de Convite'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Reenviar via WhatsApp',
                    icon: Icons.chat_bubble,
                    isPrimary: true,
                    onPressed: () => _launchWhatsApp(phone, name),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Reenviar via E-mail',
                    icon: Icons.email,
                    isPrimary: false,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('E-mail reenviado com sucesso!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // 3. PERIODIZAÇÃO (Treino)
              const MetaSectionTitle(title: 'Periodização'),
              const SizedBox(height: 16),
              if (!_hasActiveWorkout)
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center, color: MetaColors.textSecondary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma ficha ativa ainda.',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: '✨ Prescrever com IA em 30s',
                          isPrimary: true,
                          onPressed: () {
                            // TODO: Navegar para geração de treino
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ficha Atual',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Treino ABC - Hipertrofia',
                        style: TextStyle(color: MetaColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atualizada há 12 dias',
                        style: TextStyle(color: MetaColors.emerald, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SquircleButton(
                              label: 'Ver/Ajustar',
                              icon: Icons.visibility,
                              isPrimary: true,
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SquircleButton(
                              label: 'Renovar',
                              icon: Icons.refresh,
                              isPrimary: false,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Excluir Ficha', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // 4. ADMINISTRAÇÃO (Menu de Configurações)
              const MetaSectionTitle(title: 'Administração'),
              const SizedBox(height: 16),
              MetaCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit, color: MetaColors.textSecondary),
                      title: const Text('Editar Perfil do Aluno', style: TextStyle(color: MetaColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, color: MetaColors.textSecondary),
                      onTap: () {},
                    ),
                    const Divider(color: MetaColors.surfaceHighlight, height: 1),
                    ListTile(
                      leading: const Icon(Icons.pause_circle_outline, color: MetaColors.textSecondary),
                      title: const Text('Arquivar Aluno', style: TextStyle(color: MetaColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, color: MetaColors.textSecondary),
                      onTap: () {},
                    ),
                    const Divider(color: MetaColors.surfaceHighlight, height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: const Text('Excluir Definitivamente', style: TextStyle(color: Colors.redAccent)),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

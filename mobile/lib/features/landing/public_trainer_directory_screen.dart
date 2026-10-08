import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/widgets/meta_components.dart';

class PublicTrainerDirectoryScreen extends StatefulWidget {
  const PublicTrainerDirectoryScreen({super.key});

  @override
  State<PublicTrainerDirectoryScreen> createState() =>
      _PublicTrainerDirectoryScreenState();
}

class _PublicTrainerDirectoryScreenState
    extends State<PublicTrainerDirectoryScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _trainers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/public/trainers?limit=50'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Não foi possível carregar os treinadores.');
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _trainers = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível carregar o diretório agora.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTrainers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _trainers;
    return _trainers.where((trainer) {
      final searchable = [
        trainer['full_name'],
        trainer['bio'],
        ...(trainer['specialties'] as List<dynamic>? ?? const []),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final trainers = _filteredTrainers;
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        title: const Text('Treinadores'),
        backgroundColor: MetaColors.background,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Encontre seu treinador',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Conheça o trabalho de profissionais com registro CREF.',
                    style: TextStyle(color: MetaColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: MetaColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nome ou especialidade',
                      hintStyle: const TextStyle(color: MetaColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: MetaColors.emerald),
                      filled: true,
                      fillColor: MetaColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: MetaColors.emerald),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: MetaColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              IconButton(
                                tooltip: 'Tentar novamente',
                                onPressed: _loadTrainers,
                                icon: const Icon(Icons.refresh, color: MetaColors.emerald),
                              ),
                            ],
                          ),
                        )
                      : trainers.isEmpty
                          ? Center(
                              child: Text(
                                _trainers.isEmpty
                                    ? 'Nenhum treinador disponível no momento.'
                                    : 'Nenhum resultado para esta busca.',
                                style: const TextStyle(color: MetaColors.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTrainers,
                              color: MetaColors.emerald,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: trainers.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final trainer = trainers[index];
                                  final specialties =
                                      (trainer['specialties'] as List<dynamic>? ?? [])
                                          .map((item) => item.toString())
                                          .join(' · ');
                                  final photo = trainer['photo_url'] as String?;
                                  return Material(
                                    color: MetaColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/prof/${Uri.encodeComponent(trainer['username'] as String)}',
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 28,
                                              backgroundColor: MetaColors.surfaceHighlight,
                                              backgroundImage: photo == null || photo.isEmpty
                                                  ? null
                                                  : NetworkImage(photo),
                                              child: photo == null || photo.isEmpty
                                                  ? const Icon(Icons.person_outline, color: MetaColors.emerald)
                                                  : null,
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    trainer['full_name'] as String? ?? 'Treinador',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: MetaColors.textPrimary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (specialties.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      specialties,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: MetaColors.emerald, fontSize: 12),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    trainer['bio'] as String? ?? '',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: MetaColors.textSecondary,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right, color: MetaColors.textSecondary),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
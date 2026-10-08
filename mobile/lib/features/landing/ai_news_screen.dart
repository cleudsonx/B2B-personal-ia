import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

class AiNewsScreen extends StatefulWidget {
  const AiNewsScreen({super.key});

  @override
  State<AiNewsScreen> createState() => _AiNewsScreenState();
}

class _AiNewsScreenState extends State<AiNewsScreen> {
  static const _ink = Color(0xFF18241F);
  static const _muted = Color(0xFF64716A);
  static const _green = Color(0xFF286B4D);
  static const _paper = Color(0xFFF3F5F0);

  bool _isLoading = true;
  String? _error;
  bool _isStale = false;
  DateTime? _updatedAt;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _sources = [];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/public/ai-news'))
          .timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw const FormatException('O feed está temporariamente indisponível.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida do feed.');
      }
      final rawItems = decoded['items'];
      final rawSources = decoded['sources'];
      final items = rawItems is List
          ? rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final sources = rawSources is List
          ? rawSources.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _sources = sources;
        _isStale = decoded['stale'] == true;
        _updatedAt = DateTime.tryParse(decoded['updated_at']?.toString() ?? '')
            ?.toLocal();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar as notícias agora.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openArticle(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || !await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return 'Data não informada';
    const months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatUpdatedAt(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Atualizado em ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')} às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildIntro()),
              if (_isStale)
                const SliverToBoxAdapter(
                  child: _Notice(
                    text: 'Exibindo a última atualização disponível.',
                    icon: Icons.history_rounded,
                  ),
                ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: _green)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'Feed indisponível',
                    detail: _error!,
                    action: true,
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessage(
                    icon: Icons.article_outlined,
                    title: 'Sem notícias por enquanto',
                    detail: 'As fontes oficiais não publicaram atualizações recentes.',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                  sliver: SliverToBoxAdapter(
                    child: _buildSourceLine(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  sliver: SliverList.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildArticle(_items[index]),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: _buildFooter()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 680;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_icon_black.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'SHAIPADOS LABS',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (isWide)
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/b2b'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Mr. Coach B2B'),
                  style: TextButton.styleFrom(foregroundColor: _ink),
                ),
              const SizedBox(width: 6),
              _AccessButton(compact: !isWide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 38, 22, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INTELIGÊNCIA ARTIFICIAL · FONTES OFICIAIS',
                style: TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'IA, em movimento.',
                style: TextStyle(
                  color: _ink,
                  fontSize: MediaQuery.sizeOf(context).width > 680 ? 54 : 40,
                  fontWeight: FontWeight.w900,
                  height: 1.03,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Atualizações recentes de pesquisa e produto, direto de quem está construindo a tecnologia.',
                style: TextStyle(color: _muted, fontSize: 16, height: 1.55),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: _muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _formatUpdatedAt(_updatedAt),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar notícias',
                    onPressed: _isLoading ? null : _loadNews,
                    icon: const Icon(Icons.refresh_rounded),
                    color: _green,
                  ),
                ],
              ),
              const Divider(color: Color(0xFFD9DED7), height: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceLine() {
    final available = _sources
        .where((source) => source['status'] == 'ok')
        .map((source) => source['name']?.toString())
        .whereType<String>()
        .toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'FONTES',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        ...available.map(
          (source) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD9DED7)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              source,
              style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArticle(Map<String, dynamic> item) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: () => _openArticle(item['url']?.toString()),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDE2DA)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      Text(
                        item['source']?.toString() ?? 'Fonte oficial',
                        style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _formatDate(item['published_at']?.toString()),
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['title']?.toString() ?? 'Notícia de IA',
                    style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  if ((item['summary']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item['summary'].toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ler na fonte', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w800)),
                      SizedBox(width: 6),
                      Icon(Icons.open_in_new_rounded, size: 15, color: _green),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String detail,
    bool action = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _green, size: 34),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 14)),
            if (action) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadNews,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
      child: Center(
        child: Text(
          'Fontes: ${_sources.map((source) => source['name']).whereType<String>().join(' · ')}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Notice({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: [
              Icon(icon, size: 16, color: _AiNewsScreenState._green),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: _AiNewsScreenState._muted, fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessButton extends StatelessWidget {
  final bool compact;

  const _AccessButton({required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Acessar plataforma',
        onPressed: () => Navigator.pushNamed(context, '/home'),
        icon: const Icon(Icons.login_rounded),
        color: _AiNewsScreenState._green,
      );
    }
    return FilledButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/home'),
      icon: const Icon(Icons.login_rounded, size: 17),
      label: const Text('Acessar plataforma'),
      style: FilledButton.styleFrom(
        backgroundColor: _AiNewsScreenState._green,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }
}

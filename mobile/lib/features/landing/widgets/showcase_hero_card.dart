import 'package:flutter/material.dart';
import '../../../models/public_showcase_model.dart';

class ShowcaseHeroCard extends StatelessWidget {
  final PublicTrainerProfile profile;
  final VoidCallback? onStartScreening;
  final VoidCallback? onDirectWhatsApp;

  const ShowcaseHeroCard({
    super.key,
    required this.profile,
    this.onStartScreening,
    this.onDirectWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E222B) : Colors.white;
    final primaryColor = const Color(0xFF00E676);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar com Selo de CREF Verificado
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primaryColor, const Color(0xFF00B0FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: isDark ? const Color(0xFF2A2E39) : Colors.grey[200],
                    backgroundImage: (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                        ? NetworkImage(profile.photoUrl!)
                        : null,
                    child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                        ? Text(
                            profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'T',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                ),
                if (profile.crefVerified)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Nome do Treinador
            Text(
              profile.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),

            // CREF Badge
            if (profile.cref != null && profile.cref!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00E676)),
                    const SizedBox(width: 4),
                    Text(
                      profile.cref!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ],
                ),
              ),

            // Bio
            if (profile.bio != null && profile.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Prova Social / Métricas em Linha
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14171E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetricItem(
                    icon: Icons.star_rounded,
                    iconColor: Colors.amber,
                    title: '${profile.ratingAvg.toStringAsFixed(1)} ★',
                    subtitle: '${profile.ratingCount} avaliações',
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.3)),
                  _MetricItem(
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF00B0FF),
                    title: profile.activeStudentsRange.split(' ')[0],
                    subtitle: 'Alunos ativos',
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.3)),
                  _MetricItem(
                    icon: Icons.bolt_rounded,
                    iconColor: primaryColor,
                    title: '${profile.transformationStoriesCount}+',
                    subtitle: 'Resultados',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Badges de Confiança / Especialidades
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: profile.showcaseBadges.map((badge) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262C38) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Botão Principal: Triagem Biomecânica Gratuita (Lead Magnet)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('btn_lead_magnet_screening'),
                onPressed: onStartScreening,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.biotech_rounded, size: 20, color: Colors.black),
                label: const Text(
                  'Fazer Triagem Biomecânica Gratuita',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            if (onDirectWhatsApp != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  key: const Key('btn_direct_whatsapp_hero'),
                  onPressed: onDirectWhatsApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Conversar no WhatsApp',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

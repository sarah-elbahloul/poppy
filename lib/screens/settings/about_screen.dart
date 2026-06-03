import 'package:flutter/material.dart';
import 'package:poppy/core/app_routes.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/core/widgets/poppy_logo.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — About Screen
//  Location: lib/screens/settings/about_screen.dart
//
//  Shows app version, build, a short description, and links to
//  the legal screens.
// ─────────────────────────────────────────────────────────────

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Update this when you bump the version in pubspec.yaml.
  // Replace with package_info_plus when you add that dep.
  static const _version = '1.0.0';
  static const _build   = '1';

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('About Poppy',
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [

          // ── Logo + version ──────────────────────────────
          Center(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                const PoppyLogo(size: AppIconSize.logo, prominent: false),
                const SizedBox(height: AppSpacing.md),
                Text('Poppy',
                    style: AppTextStyles.titleLarge(t.textPrimary, fp)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Version $_version (build $_build)',
                  style:
                  AppTextStyles.labelLargeSans(t.textTertiary, fp),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical:   AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: t.accentLight,
                    borderRadius:
                    BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'End-to-end encrypted diary',
                    style:
                    AppTextStyles.labelLargeSans(t.accent,fp),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),

          // ── Description ────────────────────────────────
          Text(
            'About',
            style: AppTextStyles.labelLargeSans(t.textTertiary,fp)
                .copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: t.border, width: AppStroke.hairline),
            ),
            child: Text(
              'Poppy is a private diary app. Every entry is encrypted '
                  'on your device before it leaves — nobody but you can '
                  'read your words, not even us.',
              style: AppTextStyles.bodySmallSans(t.textSecondary,fp)
                  .copyWith(height: 1.7),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Legal links ─────────────────────────────────
          Text(
            'Legal',
            style: AppTextStyles.labelLargeSans(t.textTertiary,fp)
                .copyWith(letterSpacing: 0.6),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LegalCard(children: [
            _LegalRow(
              icon:  AppIcons.privacyPolicy,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalPrivacy),
            ),
            _LegalDivider(),
            _LegalRow(
              icon:  AppIcons.Tos,
              label: 'Terms of Use',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalTerms),
            ),
            _LegalDivider(),
            _LegalRow(
              icon:  AppIcons.Osl,
              label: 'Open Source Licenses',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.legalOpensource),
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          Center(
            child: Text(
              '© 2025 Poppy. Made with care.',
              style: AppTextStyles.labelSmall(t.textTertiary,fp),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  final List<Widget> children;
  const _LegalCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
        Border.all(color: t.border, width: AppStroke.hairline),
      ),
      child: Column(children: children),
    );
  }
}

class _LegalRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _LegalRow({
    required this.icon, required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon,
                size:  AppComponentSize.settingsIconCol,
                color: t.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.titleSmallSans(t.textPrimary,fp)),
            ),
            Icon(AppIcons.chevronRight,
                size: AppIconSize.xs, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _LegalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    return Divider(
      height:    AppStroke.hairline,
      thickness: AppStroke.hairline,
      color:     t.border,
      indent: AppSpacing.md +
          AppComponentSize.settingsIconCol +
          AppSpacing.md,
    );
  }
}
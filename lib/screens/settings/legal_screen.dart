import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Legal Screen
//  Location: lib/screens/settings/legal_screen.dart
// ─────────────────────────────────────────────────────────────

enum LegalDoc { privacy, terms, opensource }

/// Displays legal documents such as Privacy Policy, Terms of Use, 
/// or Open Source Licenses.
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final title = switch (doc) {
      LegalDoc.privacy    => 'Privacy Policy',
      LegalDoc.terms      => 'Terms of Use',
      LegalDoc.opensource => 'Open Source Licenses',
    };

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: switch (doc) {
          LegalDoc.privacy    => _PrivacyContent(),
          LegalDoc.terms      => _TermsContent(),
          LegalDoc.opensource => _OpenSourceContent(),
        },
      ),
    );
  }
}

// ─── Privacy Policy ───

class _PrivacyContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Privacy Policy', style: AppTextStyles.headlineLarge(t.textPrimary, fp)),
        const SizedBox(height: AppSpacing.xs),
        Text('Last updated: January 2025',
            style: AppTextStyles.labelLargeSerif(t.textTertiary, fp)),
        const SizedBox(height: AppSpacing.lg),

        const _Section(title: 'What we collect', body:
        'Poppy collects only what is necessary to run the app. '
            'This includes your email address for account authentication, '
            'the diary entries and photos you choose to create, '
            'and basic device information used to deliver the service.',
        ),
        const _Section(title: 'How we use your data', body:
        'Your data is used solely to provide the Poppy diary service. '
            'We do not sell, rent, or share your personal information '
            'with third parties for marketing purposes. '
            'Your entries are stored securely and are accessible only to you.',
        ),
        const _Section(title: 'Data storage', body:
        'Your entries and account data are stored on Supabase, '
            'a secure cloud database provider. Photos are stored in '
            'Supabase Storage with private access — only you can access your photos. '
            'Data is encrypted in transit and at rest.',
        ),
        const _Section(title: 'Your rights', body:
        'You have the right to access, correct, or delete your data at any time. '
            'You can export all your entries from the Settings screen. '
            'To permanently delete your account and all associated data, '
            'contact us at support@poppydiary.app.',
        ),
        const _Section(title: 'Data retention', body:
        'We retain your data for as long as your account is active. '
            'When you delete your account, all data including entries, '
            'photos, and account information is permanently deleted '
            'within 30 days.',
        ),
        const _Section(title: 'Children\'s privacy', body:
        'Poppy is not directed at children under the age of 13. '
            'We do not knowingly collect personal information from '
            'children under 13.',
        ),
        const _Section(title: 'Contact', body:
        'If you have questions about this privacy policy, '
            'please contact us at support@poppydiary.app.',
        ),
      ],
    );
  }
}

// ─── Terms of Use ───

class _TermsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Terms of Use', style: AppTextStyles.headlineLarge(t.textPrimary, fp)),
        const SizedBox(height: AppSpacing.xs),
        Text('Last updated: January 2025',
            style: AppTextStyles.labelLargeSerif(t.textTertiary, fp)),
        const SizedBox(height: AppSpacing.lg),

        const _Section(title: 'Acceptance', body:
        'By using Poppy, you agree to these terms. '
            'If you do not agree, please do not use the app.',
        ),
        const _Section(title: 'Your account', body:
        'You are responsible for maintaining the security of your account '
            'and password. You are responsible for all activity that occurs '
            'under your account.',
        ),
        const _Section(title: 'Your content', body:
        'You retain full ownership of all diary entries and photos '
            'you create in Poppy. By using the service, you grant us '
            'a limited license to store and display your content '
            'solely for the purpose of providing the service to you.',
        ),
        const _Section(title: 'Acceptable use', body:
        'You agree not to use Poppy to store or transmit content '
            'that is unlawful, harmful, or violates the rights of others. '
            'You agree not to attempt to gain unauthorised access to '
            'other users\' data.',
        ),
        const _Section(title: 'Service availability', body:
        'We aim to keep Poppy available at all times but cannot '
            'guarantee uninterrupted service. We are not liable for '
            'any loss of data or interruption of service.',
        ),
        const _Section(title: 'Termination', body:
        'We reserve the right to terminate or suspend access '
            'to Poppy for violations of these terms. '
            'You may delete your account at any time.',
        ),
        const _Section(title: 'Changes to terms', body:
        'We may update these terms from time to time. '
            'We will notify you of significant changes via the app. '
            'Continued use of Poppy after changes constitutes acceptance.',
        ),
        const _Section(title: 'Contact', body:
        'Questions about these terms? Contact us at support@poppydiary.app.',
        ),
      ],
    );
  }
}

// ─── Open Source Licenses ───

class _OpenSourceContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    final packages = [
      ('supabase_flutter', 'MIT License', 'Supabase Inc.'),
      ('provider',         'MIT License', 'Remi Rousselet'),
      ('navigator',        'BSD 3-Clause License', 'Flutter Team'),
      ('flutter_secure_storage', 'BSD 3-Clause License', 'Julian Steenbuck'),
      ('image_picker',     'BSD 3-Clause License', 'Flutter Team'),
      ('cached_network_image', 'MIT License', 'Baseflow'),
      ('path_provider',    'BSD 3-Clause License', 'Flutter Team'),
      ('share_plus',       'BSD 3-Clause License', 'FlutterCommunity'),
      ('file_picker',      'MIT License', 'Miguel Ruivo'),
      ('crypto',           'BSD 3-Clause License', 'Dart Team'),
      ('intl',             'BSD 3-Clause License', 'Dart Team'),
      ('flutter_svg',      'MIT License', 'Dan Field'),
      ('google_fonts',     'MIT License', 'Flutter Team'),
      ('flutter_image_compress', 'MIT License', 'OpenFlutter'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Open Source Licenses',
            style: AppTextStyles.headlineLarge(t.textPrimary, fp)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Poppy is built on the shoulders of these open source projects.',
          style: AppTextStyles.bodyMedium(t.textSecondary,fp),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...packages.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppStroke.colorStrip,
                height: 36,
                decoration: BoxDecoration(
                  color: t.accentMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.$1,
                        style: AppTextStyles.bodySmallSans(t.textPrimary,fp)),
                    Text('${p.$3} · ${p.$2}',
                        style: AppTextStyles.labelLargeSerif(t.textTertiary, fp)),
                  ],
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: AppSpacing.lg),
        TextButton.icon(
          onPressed: () => showLicensePage(context: context),
          icon: Icon(AppIcons.info, size: AppIconSize.xs, color: t.accent),
          label: Text('View all Flutter licenses',
              style: AppTextStyles.bodySmallSans(t.accent,fp)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.read<ThemeProvider>().currentFontPairData;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodySmallSans(t.textPrimary,fp)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTextStyles.bodyMedium(t.textSecondary,fp)),
        ],
      ),
    );
  }
}

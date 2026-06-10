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
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(AppIcons.back,
              size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: AppTextStyles.titleLarge(t.textPrimary, fp)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: switch (doc) {
            LegalDoc.privacy    => _PrivacyContent(),
            LegalDoc.terms      => _TermsContent(),
            LegalDoc.opensource => _OpenSourceContent(),
          },
        ),
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
        const SizedBox(height: AppSpacing.xl),

        const _Section(title: 'Overview', body:
        'At Poppy, your privacy is not a feature—it is our foundation. '
            'We use a Zero-Knowledge architecture, meaning we have designed '
            'the system so that only YOU hold the keys to your data.',
        ),
        const _Section(title: 'Zero-Knowledge Encryption', body:
        'Every entry and title you create is encrypted on your device using '
            'AES-256-GCM before it ever reaches our servers. The master key '
            'is generated locally and is protected by your password. We do '
            'not have access to your password, your encryption keys, or your '
            'decrypted content. If you lose your credentials and recovery access, '
            'your data is unrecoverable even by us.',
        ),
        const _Section(title: 'Data Collection', body:
        'We collect your email address solely for account management, '
            'synchronization, and security purposes. We do not track your '
            'location, your search queries, or your usage patterns for '
            'advertising purposes. We do not sell your data to third parties.',
        ),
        const _Section(title: 'Media & Storage', body:
        'Photos are stored in private cloud storage. While the files are stored '
            'on Supabase infrastructure, they are linked to your account and '
            'protected by Row-Level Security (RLS). References to these photos '
            'within your diary entries are encrypted.',
        ),
        const _Section(title: 'Third-Party Services', body:
        'We use Supabase for authentication and database management, and '
            'Google Fonts for typography. These services may collect basic '
            'technical logs necessary for service delivery, such as IP addresses '
            'and device types, in accordance with their own privacy policies.',
        ),
        const _Section(title: 'Data Retention & Deletion', body:
        'You have full control over your data. You can delete individual entries '
            'or your entire account at any time through the app settings. '
            'Deletion is permanent and removes all associated cloud data.',
        ),
        const _Section(title: 'Contact', body: // todo: change this to actual email
        'For privacy concerns or data requests, contact us at sa.albahloul@gmail.com.',
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
        const SizedBox(height: AppSpacing.xl),

        const _Section(title: 'Agreement to Terms', body:
        'By creating an account or using Poppy, you agree to be bound by these '
            'Terms. If you do not agree, you may not use the service.',
        ),
        const _Section(title: 'User Responsibility', body:
        'Because Poppy uses end-to-end encryption, you are solely responsible '
            'for maintaining the confidentiality of your account credentials. '
            'We cannot reset your encryption key if you forget your password. '
            'You are responsible for all activity that occurs under your account.',
        ),
        const _Section(title: 'Content Ownership', body:
        'You retain all rights to the content you post in Poppy. We claim '
            'no ownership. By using the app, you grant us a license only to '
            'store and transmit your (encrypted) data to facilitate '
            'synchronization across your devices.',
        ),
        const _Section(title: 'Prohibited Use', body:
        'You may not use Poppy for any illegal purposes. While your data is '
            'encrypted, we reserve the right to terminate accounts that '
            'interfere with the stability or security of our infrastructure.',
        ),
        const _Section(title: 'No Warranty', body:
        'Poppy is provided "as is" without warranty of any kind. We do not '
            'guarantee that the service will be uninterrupted or error-free. '
            'We strongly recommend using the "Export" feature regularly to '
            'maintain your own backups.',
        ),
        const _Section(title: 'Changes to Service', body:
        'We reserve the right to modify or discontinue Poppy at any time. '
            'We will provide notice of significant changes through the app.',
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

    // Updated to reflect pubspec.yaml
    final packages = [
      ('supabase_flutter',    'MIT',      'Supabase Inc.'),
      ('cryptography',        'Apache 2.0','Daco Harkes'),
      ('sqflite',             'MIT',      'Alexandre Roux'),
      ('provider',            'MIT',      'Remi Rousselet'),
      ('flutter_secure_storage','BSD 3-Clause','Julian Steenbuck'),
      ('flutter_local_notifications','BSD 3-Clause','Maarten Huijsmans'),
      ('google_fonts',        'Apache 2.0','Google LLC'),
      ('image_picker',        'BSD 3-Clause','Flutter Team'),
      ('cached_network_image','MIT',      'Baseflow'),
      ('path_provider',       'BSD 3-Clause','Flutter Team'),
      ('share_plus',          'BSD 3-Clause','Flutter Community'),
      ('file_picker',         'MIT',      'Miguel Ruivo'),
      ('flutter_svg',         'MIT',      'Dan Field'),
      ('iconsax',             'MIT',      'AmsamDesign'),
      ('intl',                'BSD 3-Clause','Dart Team'),
      ('crypto',              'BSD 3-Clause','Dart Team'),
      ('connectivity_plus',   'BSD 3-Clause','Flutter Community'),
      ('timezone',            'Apache 2.0','Dart Team'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Open Source Licenses',
            style: AppTextStyles.headlineLarge(t.textPrimary, fp)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Poppy is made possible by the following open source software.',
          style: AppTextStyles.bodyMedium(t.textSecondary, fp),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...packages.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
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
                        style: AppTextStyles.bodySmallSans(t.textPrimary, fp)),
                    const SizedBox(height: 2),
                    Text('${p.$3} · ${p.$2}',
                        style: AppTextStyles.labelLargeSerif(t.textTertiary, fp)),
                  ],
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Poppy',
              applicationVersion: '1.0.0',
            ),
            icon: Icon(AppIcons.info, size: AppIconSize.xs, color: t.accent),
            label: Text('View all Flutter licenses',
                style: AppTextStyles.bodySmallSans(t.accent, fp)),
          ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), 
            style: AppTextStyles.bodySmallSans(t.accent, fp).copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTextStyles.bodyMedium(t.textSecondary, fp).copyWith(
            height: 1.5,
          )),
        ],
      ),
    );
  }
}

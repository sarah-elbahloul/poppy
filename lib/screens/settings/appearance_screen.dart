import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poppy/core/constants.dart';
import 'package:poppy/core/theme/themes.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Appearance Screen
//  Location: lib/screens/settings/appearance_screen.dart
//
//  Lets the user pick one of the 5 flower themes.
//  Each theme is shown as a large tappable card with a
//  colour swatch, name, and a checkmark when selected.
//  The app re-themes instantly on tap.
// ─────────────────────────────────────────────────────────────

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: t.textSecondary),
          onPressed: () => context.pop(),
        ),
        title: Text('Appearance',
            style: TextStyle(fontSize: 18, color: t.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpaceLG),
        children: [
          Text(
            'Theme',
            style: TextStyle(
              fontSize: 11,
              color: t.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: kSpaceSM),

          // ── Theme cards ───────────────────────────────────
          ...PoppyThemes.all.map((themeData) {
            final isSelected =
                themeProvider.currentTheme == themeData.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: kSpaceSM),
              child: _ThemeCard(
                themeData: themeData,
                isSelected: isSelected,
                onTap: () => themeProvider.setTheme(themeData.id),
              ),
            );
          }),

          const SizedBox(height: kSpaceLG),
          Text(
            'All themes use soft pastel tones.\nBackgrounds stay near-white in every theme.',
            style: TextStyle(
              fontSize: 12,
              color: t.textTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme card ─────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final PoppyThemeData themeData;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.themeData,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAnimNormal,
        padding: const EdgeInsets.all(kSpaceMD),
        decoration: BoxDecoration(
          color: themeData.surface,
          borderRadius: BorderRadius.circular(kRadiusMD),
          border: Border.all(
            color: isSelected ? themeData.accent : themeData.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // ── Color swatch ────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeData.accentMuted,
                    themeData.accent,
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  themeData.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(width: kSpaceMD),

            // ── Name ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    themeData.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: themeData.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Mini color strip preview
                  Row(
                    children: [
                      themeData.accent,
                      themeData.accentMuted,
                      themeData.accentLight,
                      themeData.surface,
                      themeData.border,
                    ].map((color) {
                      return Container(
                        width: 16,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ── Selected checkmark ────────────────────────────
            AnimatedOpacity(
              duration: kAnimFast,
              opacity: isSelected ? 1.0 : 0.0,
              child: Icon(
                Icons.check_circle,
                color: themeData.accent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
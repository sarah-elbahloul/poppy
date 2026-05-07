import 'package:flutter/material.dart';
import 'package:poppy/core/style/style.dart';
import 'package:poppy/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t             = context.poppyTheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: AppIconSize.xs, color: t.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Appearance', style: AppTextStyles.appBarTitle(t.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Theme', style: AppTextStyles.sectionLabel(t.textTertiary)),
          const SizedBox(height: AppSpacing.sm),
          ...PoppyThemes.all.map((themeData) {
            final isSelected = themeProvider.currentTheme == themeData.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => themeProvider.setTheme(themeData.id),
                child: AnimatedContainer(
                  duration: AppDuration.normal,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: themeData.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected ? themeData.accent : themeData.border,
                      width: isSelected ? AppStroke.medium : AppStroke.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [themeData.accentMuted, themeData.accent],
                          ),
                        ),
                        child: Center(
                          child: Text(themeData.emoji,
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(themeData.name,
                                style: AppTextStyles.themeName(themeData.textPrimary)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                themeData.accent,
                                themeData.accentMuted,
                                themeData.accentLight,
                                themeData.surface,
                                themeData.border,
                              ].map((color) => Container(
                                width: 16, height: 6,
                                margin: const EdgeInsets.only(right: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(AppRadius.xs),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        duration: AppDuration.fast,
                        opacity: isSelected ? 1.0 : 0.0,
                        child: Icon(AppIcons.checkCircle,
                            color: themeData.accent, size: AppIconSize.sm),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'All themes use soft pastel tones.\nBackgrounds stay near-white in every theme.',
            style: AppTextStyles.themeNote(t.textTertiary),
          ),
        ],
      ),
    );
  }
}

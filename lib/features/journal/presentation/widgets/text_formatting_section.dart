import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:poppy/core/core.dart';
import 'package:poppy/features/journal/presentation/widgets/photo_full_viewer.dart';
import 'package:poppy/features/settings/presentation/providers/theme_provider.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────
//  POPPY — Text Formatting Section Widget
// ─────────────────────────────────────────────────────────────

/// A collapsible section for managing photos attached to a journal entry.
class TextFormattingSection extends StatelessWidget {
  const TextFormattingSection({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poppyTheme;
    final fp = context.watch<ThemeProvider>().currentFontPairData;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: t.border, width: AppStroke.hairline),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.undo, size: AppIconSize.xs, color: t.textTertiary),

              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.redo, size: AppIconSize.xs, color: t.textTertiary),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.checkSquare, size: AppIconSize.xs, color: t.textTertiary),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.listNumber, size: AppIconSize.xs, color: t.textTertiary),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.unnumberedList, size: AppIconSize.xs, color: t.textTertiary),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.indent, size: AppIconSize.xs, color: t.textTertiary),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(AppIconSize.xs, AppIconSize.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: (){},
                icon: Icon(AppIcons.outdent, size: AppIconSize.xs, color: t.textTertiary),
              ),

            ],
          ),
        )
      ],
    );
  }
}

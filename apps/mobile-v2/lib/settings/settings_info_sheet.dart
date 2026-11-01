/// The S7 information sheets (design-spec §4.8, state row "许可 / 隐私":
/// "信息弹层，文案明确字体、图标、插画来源与本地语音策略").
///
/// Both use the shared [AppSheet] frame: heading, paragraphs, an optional
/// caption and one secondary "Close" action. Nothing here is editable — the
/// sheets exist to be read, so they carry no settings controls.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/components/app_sheet.dart';

/// Paragraph gap inside the sheet body (`.sheet-body` lines are one flow).
const double _paragraphGap = 9;

/// `.sheet-actions { margin-top: 20px }` + `.btn { height: 52px }`.
const double _actionsGap = 20;
const double _actionHeight = 52;

/// Secondary CTA recipe (`.btn--secondary`): `surface` fill, 1 px
/// `line-strong` outline, ink label. The app theme ships primary and ghost
/// styles only, so the sheet builds this one locally.
const ButtonStyle _secondaryAction = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, _actionHeight)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 20),
  ),
  shape: WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder()),
  elevation: WidgetStatePropertyAll<double>(0),
  animationDuration: Duration(milliseconds: 150),
  backgroundColor: WidgetStatePropertyAll<Color>(AppColors.surface),
  foregroundColor: WidgetStatePropertyAll<Color>(AppColors.ink),
  overlayColor: WidgetStatePropertyAll<Color>(AppColors.primaryGhost),
  side: WidgetStatePropertyAll<BorderSide>(
    BorderSide(color: AppColors.lineStrong),
  ),
);

/// Opens a read-only information sheet.
///
/// [body] may contain `\n`-separated paragraphs (the copy keeps its line
/// breaks so translators control the grouping). [attributionLabel] /
/// [attributionLine] append the content-pack attribution when present.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String body,
  String? caption,
  String? attributionLabel,
  String? attributionLine,
  required String closeLabel,
}) {
  return showAppSheet<void>(
    context,
    title: title,
    child: Builder(
      builder: (BuildContext sheetContext) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String paragraph in body.split('\n'))
              Padding(
                padding: const EdgeInsets.only(bottom: _paragraphGap),
                child: Text(
                  paragraph,
                  // `.sheet-body { font: 400 12.5px/1.65; color: ink-2 }`.
                  style: AppTypography.meta.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.65,
                    color: AppColors.ink2,
                  ),
                ),
              ),
            if (attributionLine != null && attributionLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: _paragraphGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      attributionLabel,
                      style: AppTypography.label
                          .copyWith(color: AppColors.ink3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      attributionLine,
                      style: AppTypography.meta.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: AppTypography.meta.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: AppColors.ink3,
                  ),
                ),
              ),
            const SizedBox(height: _actionsGap),
            OutlinedButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: _secondaryAction,
              child: Text(closeLabel),
            ),
          ],
        );
      },
    ),
  );
}

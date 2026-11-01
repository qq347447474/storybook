/// S0 shelf view switch (`.lib-tools` / `.lib-view` / `.lib-view__btn`,
/// `visual/app.css`).
///
/// A pill-shaped segmented control that flips the shelf between the card
/// layout (featured book + grid) and the flat list. Both buttons are 44 dp
/// tall so the tap target clears the house minimum, and the pressed state is
/// announced through `Semantics.toggled` rather than colour alone.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../ui/app_icon.dart';

/// Shelf layout chosen in the tools row.
enum LibraryViewMode {
  /// Featured card plus a two-column grid of the remaining books.
  cards,

  /// One compact row per book, sorted by title.
  list,
}

class LibraryViewToggle extends StatelessWidget {
  const LibraryViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.groupLabel,
    required this.cardsLabel,
    required this.listLabel,
  });

  final LibraryViewMode mode;
  final ValueChanged<LibraryViewMode> onChanged;

  /// Accessibility label for the group as a whole.
  final String groupLabel;
  final String cardsLabel;
  final String listLabel;

  /// `.lib-view__btn { height: 44px; padding: 0 11px; gap: 5px }`.
  static const double _height = 44;
  static const EdgeInsets _btnPadding = EdgeInsets.symmetric(horizontal: 11);
  static const double _iconSize = 16;
  static const double _iconGap = 5;

  /// `.lib-view { padding: 2px; gap: 2px; border-radius: var(--r-pill) }`.
  static const double _outerPadding = 2;
  static const double _innerGap = 2;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: groupLabel,
      child: Container(
        padding: const EdgeInsets.all(_outerPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_height),
          border: Border.all(color: AppColors.line),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Segment(
              icon: 'grid',
              label: cardsLabel,
              selected: mode == LibraryViewMode.cards,
              onTap: () => onChanged(LibraryViewMode.cards),
              keyName: 'library-view-cards',
            ),
            const SizedBox(width: _innerGap),
            _Segment(
              icon: 'list',
              label: listLabel,
              selected: mode == LibraryViewMode.list,
              onTap: () => onChanged(LibraryViewMode.list),
              keyName: 'library-view-list',
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.keyName,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(LibraryViewToggle._height),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key(keyName),
          onTap: onTap,
          child: SizedBox(
            height: LibraryViewToggle._height,
            child: Padding(
              padding: LibraryViewToggle._btnPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppIcon(
                    icon,
                    size: LibraryViewToggle._iconSize,
                    color: selected ? AppColors.surface : AppColors.ink3,
                  ),
                  const SizedBox(width: LibraryViewToggle._iconGap),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: selected ? AppColors.surface : AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

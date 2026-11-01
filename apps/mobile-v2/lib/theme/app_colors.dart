/// Design tokens — colour palette. Single source of truth for every colour in
/// the app; Phase 3 screens replace their local hard-coded colours with these
/// constants.
///
/// Values are copied 1:1 from the visual hand-off: `visual/app.css` `:root`
/// (L11-48 warm paper / ink / brand / semantic, L92 focus, L843-844 disabled
/// CTA) and `visual/design-spec.md` §2.1. Nothing may be invented here — a new
/// colour needs a token row in the spec first, then a mirror in this file.
library;

import 'dart:ui' show Color;

/// Static palette. Use these instead of literal `Color(0x...)` values.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- surfaces
  /// `--paper` — page background, dock fill, trail node ring.
  static const Color paper = Color(0xFFF6F0E3);

  /// `--paper-deep` — status bar band, dividers, locked node fill.
  static const Color paperDeep = Color(0xFFEEE4D1);

  /// `--surface` — cards, player, sheets, flip-card faces.
  static const Color surface = Color(0xFFFFFCF6);

  /// `--surface-raised` — the only pure white in the system (chips on media).
  static const Color surfaceRaised = Color(0xFFFFFFFF);

  /// `--surface-sunken` — media placeholders, chips, unselected tracks.
  static const Color surfaceSunken = Color(0xFFEFE6D5);

  // --------------------------------------------------------------------- ink
  /// `--ink` — body copy and headings (13.3:1 on paper).
  static const Color ink = Color(0xFF27233A);

  /// `--ink-2` — secondary copy, option text (6.1:1 on paper).
  static const Color ink2 = Color(0xFF5D566E);

  /// `--ink-3` — meta, counters, helper text (5.0:1 paper / 4.6:1 sunken).
  static const Color ink3 = Color(0xFF6B6378);

  /// `--line` — 1 px separators. Decorative, never carries text.
  static const Color line = Color(0xFFE7DDCA);

  /// `--line-strong` — outlines and dashed placeholders. Decorative.
  static const Color lineStrong = Color(0xFFD3C6AC);

  // ------------------------------------------------------------------- brand
  /// `--primary` — actionable / current step / selected (6.1:1 with white).
  static const Color primary = Color(0xFF5B4BD6);

  /// `--primary-strong` — pressed state for primary fills.
  static const Color primaryStrong = Color(0xFF4939C4);

  /// `--primary-soft` — level chips, current step, light selected tint.
  static const Color primarySoft = Color(0xFFECE7FF);

  /// `--primary-ghost` — rgba(91,75,214,0.09), progress panel tint.
  static const Color primaryGhost = Color(0x175B4BD6);

  /// `--accent` — warm decorative orange; never carries small text.
  static const Color accent = Color(0xFFC97C4C);

  /// `--accent-strong` — glossary underline / editorial emphasis (4.9:1).
  static const Color accentStrong = Color(0xFF9E552B);

  /// `--accent-soft` — vocabulary chip fill.
  static const Color accentSoft = Color(0xFFF9E8D7);

  /// `--focus` — 3 px focus ring on paper (≥3:1 non-text).
  static const Color focus = Color(0xFF7A67F0);

  // -------------------------------------------------------- semantic states
  /// Success / correct / speech ready.
  static const Color successInk = Color(0xFF276B4B);
  static const Color successBg = Color(0xFFE8F2E9);
  static const Color successLine = Color(0xFFBFDCC8);

  /// Warning / wrong answer / permission missing.
  static const Color warningInk = Color(0xFF855714);
  static const Color warningBg = Color(0xFFFBF0D6);
  static const Color warningLine = Color(0xFFEAD3A3);

  /// Blocked / microphone denied / cannot continue.
  static const Color dangerInk = Color(0xFF9C3F34);
  static const Color dangerBg = Color(0xFFF9E7E3);
  static const Color dangerLine = Color(0xFFEAC5BD);

  /// Quiet information / quiz labels.
  static const Color tealInk = Color(0xFF2C6257);
  static const Color tealBg = Color(0xFFE4F0ED);
  static const Color tealLine = Color(0xFFC3DCD6);

  /// Retell (step 4) labels.
  static const Color plumInk = Color(0xFF8C4560);
  static const Color plumBg = Color(0xFFF6E7ED);
  static const Color plumLine = Color(0xFFE7C8D3);

  // ------------------------------------------------------------- components
  /// Disabled CTA fill (`.btn:disabled`, app.css L843).
  static const Color disabledFill = Color(0xFFEAE1D1);

  /// Disabled CTA label (`.btn:disabled`, app.css L844).
  static const Color disabledInk = Color(0xFF8D8577);

  /// Foreground on brand fills (`.btn--primary` colour).
  static const Color onPrimary = surfaceRaised;

  /// Stage-progress track. `#e4dac7`, the one literal outside the `:root`
  /// block (`visual/app.css` L983, `.top-progress { background: #e4dac7 }`);
  /// it sits between `--paper-deep` and `--line`, so it earns a token here
  /// instead of being re-typed at the call site.
  static const Color progressTrack = Color(0xFFE4DAC7);

  /// Toast scrim. `rgba(32,27,45,.94)` (`visual/app.css` L1079, `.toast`);
  /// dark ink at 94 % so the paper page still reads through the edge.
  static const Color toastScrim = Color(0xF0201B2D);

  /// Modal scrim behind a sheet, a centred dialog or the unlock panel.
  ///
  /// `rgba(32,27,45,.44)` — design-spec §5.9 ("遮罩 `rgba(32,27,45,.44)`"),
  /// which is the value the three overlays share. `visual/app.css` draws it
  /// twice with a slightly different ink: `.overlay` `rgba(23,18,35,.46)`
  /// (L2470) and `.sheet-backdrop` `rgba(23,18,35,.45)` (L3499). The spec
  /// states one number for all of them, so the spec wins and the two CSS
  /// values collapse into this token.
  static const Color scrim = Color(0x70201B2D);

  /// Record key while it listens (`.record-btn.is-recording { background:
  /// #c8503c }`, `visual/app.css` L2951) — the red-brown of design-spec §5.7.
  /// A one-off literal in the hand-off, outside the `:root` block, promoted
  /// here so the key and its pulse ring cannot drift apart.
  static const Color recordRed = Color(0xFFC8503C);

  /// Record key with no recorder behind it (`.record-btn:disabled
  /// { background: #ddd2bf }`, `visual/app.css` L2973; design-spec §5.7
  /// "禁用：`#DDD2BF`,无光圈"). Sits one step darker than `paperDeep` so a
  /// disabled key still reads as a hole in the dock rather than a flat patch.
  static const Color recordDisabled = Color(0xFFDDD2BF);
}

/// A three-part semantic state from design-spec §2.1: text/icon ink, fill and
/// border travel together so a status is never colour-only (§7.2).
class Tone {
  const Tone({required this.ink, required this.bg, required this.line});

  final Color ink;
  final Color bg;
  final Color line;
}

/// Named [Tone]s — success / warning / danger / teal / plum.
class AppTones {
  const AppTones._();

  static const Tone success = Tone(
    ink: AppColors.successInk,
    bg: AppColors.successBg,
    line: AppColors.successLine,
  );

  static const Tone warning = Tone(
    ink: AppColors.warningInk,
    bg: AppColors.warningBg,
    line: AppColors.warningLine,
  );

  static const Tone danger = Tone(
    ink: AppColors.dangerInk,
    bg: AppColors.dangerBg,
    line: AppColors.dangerLine,
  );

  static const Tone teal = Tone(
    ink: AppColors.tealInk,
    bg: AppColors.tealBg,
    line: AppColors.tealLine,
  );

  static const Tone plum = Tone(
    ink: AppColors.plumInk,
    bg: AppColors.plumBg,
    line: AppColors.plumLine,
  );
}

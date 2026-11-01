/// Result types of pack loading and validation (`docs/07-modules.md` §2.2).
///
/// Loading and validation never throw to the caller (C5): every failure is
/// reported as a [PackInvalid] carrying [PackError] entries whose `code`
/// values reuse the `contentctl` rule codes (`docs/02-content-spec.md` §9)
/// so client errors line up with authoring-time lint errors.
library;

import 'models.dart';

/// A single validation problem inside a content pack.
class PackError {
  const PackError({
    required this.code,
    required this.pointer,
    required this.message,
  });

  /// `contentctl` rule code, e.g. `QUIZ-ANSWER`, `I18N-MISSING`.
  final String code;

  /// Location inside the pack, e.g. `books[0].chapters[1].quiz[2].answer`.
  final String pointer;

  /// Human-readable detail (English); for diagnostics only.
  final String message;

  @override
  String toString() => 'PackError($code @ $pointer :: $message)';
}

/// Outcome of `ContentRepository.loadFromFile` / `loadFromAsset`.
sealed class PackLoadResult {
  const PackLoadResult();
}

/// The pack parsed and validated successfully.
class PackOk extends PackLoadResult {
  const PackOk({
    required this.pack,
    this.upgradeRecommended = false,
  });

  /// The validated pack.
  final ContentPack pack;

  /// True when `pack.minAppVersion` is greater than the current app version.
  /// The pack still loads (C5): the UI shows an upgrade hint and renders only
  /// the fields it understands. Loading is never rejected.
  final bool upgradeRecommended;
}

/// The pack is unusable; [errors] lists every problem found.
class PackInvalid extends PackLoadResult {
  const PackInvalid(this.errors);

  /// Non-empty list of problems; the first entries are the root causes.
  final List<PackError> errors;
}

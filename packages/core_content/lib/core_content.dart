/// Content layer of the graded reader: pack parsing/validation, media
/// resolution, progress persistence and the chapter state machine
/// (`docs/07-modules.md` §2).
///
/// Pure Dart only — this package must never import `package:flutter/*`
/// (constraint C2) and must run under `dart test` on the Dart VM. Platform
/// specifics are injected from `apps/mobile` at registration time (C8).
library;

export 'src/chapter_state.dart';
export 'src/content_repository.dart';
export 'src/media_resolver.dart';
export 'src/models.dart';
export 'src/offline_media_map.dart';
export 'src/pack_error.dart';
export 'src/pack_parser.dart' show compareSemver, parsePack;
export 'src/progress_doc.dart';
export 'src/progress_store.dart';

/// Identity of this package; referenced by the app shell to verify wiring.
const String coreContentName = 'core_content';

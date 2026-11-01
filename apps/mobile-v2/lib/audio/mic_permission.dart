/// Microphone permission seam (C8: platform specifics live in the
/// `apps/mobile` registration; tests inject a fake).
///
/// Docs/09 §2 + §5: permission is requested only on the first record tap,
/// after a `perm.mic.*` pre-explanation dialog. Revocation mid-session
/// returns the UI to guidance and discards the recording.
library;

enum MicPermissionState {
  granted,
  denied,

  /// Denied with "don't ask again": only the OS settings route is left.
  permanentlyDenied,
}

abstract class MicPermissionService {
  /// Current state without prompting the user.
  Future<MicPermissionState> check();

  /// Shows the system prompt. Never throws.
  Future<MicPermissionState> request();

  /// Opens the app's system settings page (the `perm.mic.settings` route).
  Future<void> openSettings();
}

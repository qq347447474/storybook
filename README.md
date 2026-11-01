# StoryBook

Offline graded English reader — Flutter shell over the pure-Dart core packages.

## iOS build (GitHub Actions)

Every push to `main` that touches the app runs [`build-ios.yml`](.github/workflows/build-ios.yml):

1. `flutter build ipa --no-codesign` on a macOS runner
2. Uploads `storyapp-ios-<run>.ipa` as a workflow artifact (kept 30 days)

The IPA is **unsigned on purpose** — a paid Apple Developer Program is not
needed. Install it with **Sideloadly** (free Apple ID):

1. Download the `.ipa` from the workflow run's *Artifacts* section
2. Open Sideloadly, plug in the iPhone, drop the `.ipa` in
3. Enter your Apple ID → *Start* → trust the developer profile on the phone
   (*Settings → General → VPN & Device Management*)

Signing expires after 7 days with a free Apple ID; re-run Sideloadly to refresh.

## Layout

```
apps/mobile-v2/     Flutter app (Android + iOS)
packages/
  core_content/     pack schema, parser, media resolver
  core_scoring/     retell scoring
  core_speech/      ASR seam
```

## Local development

```bash
cd apps/mobile-v2
flutter pub get
flutter run
```

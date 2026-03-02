# mbl_app_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Common Flutter commands

Run on a connected device or emulator in debug mode:

```bash
flutter run
```

Build an Android debug APK:

```bash
flutter build apk --debug
```

Build an Android release APK:

```bash
flutter build apk --release
```

Build an iOS release (requires macOS and code signing set up):

```bash
flutter build ios --release
```

Analyze the project for issues:

```bash
flutter analyze
```

Troubleshooting note: If your Android build fails due to missing keystore (e.g. a null cast in `android/app/build.gradle.kts`), either provide a `key.properties` file with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`, or build a debug APK instead.

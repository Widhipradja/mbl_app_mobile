# APK Build Guide - MBL App Mobile

This guide explains how to build a release APK for the MBL App Mobile application.

## Prerequisites

- Flutter SDK installed
- Android SDK installed
- Java/JDK installed (for keytool)

## Step 1: Create Keystore (One-time setup)

The keystore is already created, but here's how it was done for reference:

```bash
cd /Users/dewanta/workspaces/mbl_app_mobile
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important:** Keep your keystore file and passwords safe! You'll need them for all future app updates.

### Keystore Information:
- **Location:** `android/app/upload-keystore.jks`
- **Alias:** `upload`
- **Validity:** 10,000 days (~27 years)
- **Organization:** desalab
- **Organizational Unit:** research
- **Location:** Bogor, Jawa Barat, Indonesia

## Step 2: Configure key.properties

The file `android/key.properties` contains your signing credentials:

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=upload-keystore.jks
```

**Security Note:** This file is already added to `.gitignore` and should NEVER be committed to version control.

## Step 3: Application Configuration

### Package Name
- **Namespace:** `com.desalabs.mbl_app`
- **Application ID:** `com.desalabs.mbl_app`

### Version Information
Located in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```
- First number (1.0.0) = Version Name (shown to users)
- Second number (+1) = Version Code (internal, must increment for each release)

## Step 4: Pre-Build Checklist

Before building, ensure:

- ✅ Debug print statements removed/converted to debugPrint
- ✅ API URL configured correctly in `lib/services/config_service.dart`
- ✅ Passwords set in `android/key.properties`
- ✅ Version updated in `pubspec.yaml`
- ✅ App tested in release mode: `flutter run --release`

## Step 5: Build Commands

### Option 1: Standard Release APK
```bash
flutter build apk --release
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk` (~50-60 MB)

### Option 2: Split APKs by Architecture (Recommended)
```bash
flutter build apk --split-per-abi
```
**Outputs:**
- `app-armeabi-v7a-release.apk` (32-bit ARM, older devices)
- `app-arm64-v8a-release.apk` (64-bit ARM, most modern devices)
- `app-x86_64-release.apk` (x86 devices, emulators)

Each file ~20-25 MB

### Option 3: Build for Specific Architecture
```bash
flutter build apk --target-platform android-arm64
```

## Step 6: Testing the Release APK

### Install on Device
```bash
flutter install
```

Or manually:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Test Checklist
- [ ] App launches successfully
- [ ] Login works
- [ ] All modules accessible based on roles
- [ ] API calls work correctly
- [ ] No debug logs visible
- [ ] App performance is smooth

## Step 7: Distribution

### Internal Testing
1. Share APK via email, drive, or file sharing
2. Install on test devices
3. Gather feedback

### Google Play Store (Optional)
For Play Store release, you'll need to:
1. Create a Google Play Console account
2. Build an App Bundle (AAB) instead of APK:
   ```bash
   flutter build appbundle --release
   ```
3. Upload to Play Store
4. Complete store listing

## Troubleshooting

### Build Fails - Keystore Issues
**Error:** "Keystore file not found" or "Incorrect password"

**Solution:**
1. Verify `android/key.properties` has correct passwords
2. Check keystore file exists: `ls android/app/upload-keystore.jks`
3. Verify passwords match those used during keystore creation

### Build Fails - Gradle Issues
**Error:** Gradle build errors

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### App Crashes on Startup
**Likely causes:**
- API URL not configured correctly
- Missing dependencies
- ProGuard/R8 obfuscation issues

**Solution:**
1. Test with `flutter run --release` first
2. Check logcat: `adb logcat | grep flutter`
3. Add ProGuard rules if needed in `android/app/proguard-rules.pro`

## Version Updates

When releasing a new version:

1. **Update version in pubspec.yaml:**
   ```yaml
   version: 1.0.1+2  # Increment version name and code
   ```

2. **Clean previous build:**
   ```bash
   flutter clean
   ```

3. **Build new APK:**
   ```bash
   flutter build apk --release
   ```

## Security Best Practices

- ✅ Never commit `key.properties` to version control
- ✅ Never commit `upload-keystore.jks` to version control
- ✅ Keep backup of keystore in secure location (encrypted drive, password manager)
- ✅ Use different keystores for development vs production if needed
- ✅ Remove all sensitive data (API keys, secrets) from code before building

## File Structure

```
android/
├── app/
│   ├── upload-keystore.jks          # Keystore file (gitignored)
│   └── build.gradle.kts             # Build configuration with signing
├── key.properties                   # Signing credentials (gitignored)
└── .gitignore                       # Ensures secrets not committed
```

## Additional Resources

- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter Build Modes](https://docs.flutter.dev/testing/build-modes)

---

**Last Updated:** December 15, 2025
**App Version:** 1.0.0+1
**Package:** com.desalabs.mbl_app

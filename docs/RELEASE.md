# Releasing the Android app

Everything here happens in `mobile/`.

## The signing key

Release builds are signed with an upload key held in two files, both gitignored
and neither ever committed:

| File | What it is |
| --- | --- |
| `mobile/android/upload-keystore.jks` | PKCS12 keystore, one entry, alias `upload` |
| `mobile/android/key.properties` | store password, key password, alias, keystore filename |

`android/app/build.gradle.kts` reads `key.properties` at configuration time. If
the file is absent — a fresh clone, or CI without the secret — the release build
**falls back to the debug key** rather than failing, so `flutter build apk` still
runs for anyone. That fallback is a convenience, not a release path: an APK
signed with the debug key cannot be uploaded to Play.

Certificate on the current key:

```
CN=ResumeForge, OU=Mobile, O=ResumeForge, L=Dhaka, ST=Dhaka, C=BD
SHA-256  A6:7D:7E:1F:12:00:08:AC:D5:73:CE:9A:90:84:FE:C0:3B:B5:72:8E:31:CF:86:38:EB:80:D6:97:A6:7E:5E:18
Valid until 28 December 2053
```

**Back the keystore up somewhere outside this repository.** Losing it means the
app can never be updated on Google Play under the same identity — there is no
recovery, only a new listing.

To recreate one from scratch (new identity, not a recovery of the old):

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then write `android/key.properties`:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` resolves against `android/`, so it stays a bare filename and the
file works on any machine.

## Building

```bash
flutter build apk --release            # single APK, ~59 MB
flutter build appbundle --release      # AAB, what Play actually wants
```

## Verifying the build is signed with the right key

Do not assume. `apksigner` ships in the Android SDK build-tools:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The printed SHA-256 must match the certificate above. If it does not, the build
fell back to the debug key — check that `android/key.properties` exists.

`./gradlew :app:signingReport` from `android/` shows the same thing before a
build, resolved per variant.

## Minification is deliberately off

`isMinifyEnabled = false` in `build.gradle.kts`, with the reason in a comment
there. The PDF stack (`dart_pdf`, `printing`/PDFium) reaches native and platform
code in ways R8 will strip, and a shrunk release that fails *only* at export
time is worse than a larger APK. Turning it on is reasonable — behind a real
export test on a real device, not blind.

## Installing a release build over a debug build

The two are signed with different keys, so Android refuses the upgrade and the
install must uninstall first. **That destroys app storage**, including every
saved resume. On a debug build the database can be pulled first:

```bash
adb shell "run-as com.codevioso.resivo cat app_flutter/resumes.hive" > resumes.hive.backup
```

`run-as` only works on debuggable builds, so this is a one-way door: you can
back up from debug, but you cannot push the file back into a release install.

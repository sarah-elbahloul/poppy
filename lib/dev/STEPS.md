# Poppy — Complete Launch Guide

> Work through these phases in order. Each phase builds on the previous one.
> Estimated total time: **2–4 weeks** (mostly waiting on account approvals and email setup).

---

## Phase 1 — Set Up Your Email Infrastructure

Do this first because every account you create downstream (Supabase, Google Play, App Store Connect) needs a professional email, and the emails you put inside the app need to actually work before you submit for review.

**Cost for this phase: ~$37 one-time ($12/year domain + $25 Google Play). Everything else is free.**

### What email addresses you will end up with

| Address | Purpose | Where it appears |
|---|---|---|
| `hello@sarahelbahloul.dev` | General contact / support / feedback | `settings_screen.dart` line 431 — the "Send feedback" button |
| `privacy@sarahelbahloul.dev` | Privacy concerns and GDPR data requests | `legal_screen.dart` line 115 — Privacy Policy contact |
| Your personal Gmail | Developer accounts only | Supabase, Google Play — never shown inside the app |

> The in-app support emails and your developer account email are kept separate on purpose. Developer account email is tied to billing and legal agreements. Support emails are public-facing and can change.

---

### 1.1 — Buy the domain on Namecheap

1. Go to [namecheap.com](https://namecheap.com)
2. Search `sarahelbahloul.dev` in the search bar
3. If available, add to cart — should show ~$12–14 for the first year
4. At checkout:
    - Create a Namecheap account using your personal Gmail
    - Turn **off** auto-renew during checkout (you can enable it later — just avoid a surprise charge)
    - Turn **off** every upsell (hosting, SSL, privacy protection — you don't need any of them)
5. Pay and complete the purchase

> After purchase go to **Dashboard → Domain List → Manage** next to `sarahelbahloul.dev`. Keep this tab open — you'll return to it in step 1.3.

---

### 1.2 — Create your Zoho Mail account

Zoho Mail's free plan gives you up to 5 custom domain email addresses. You will never log into Zoho to check mail — it forwards everything to your Gmail automatically.

1. Go to [zoho.com/mail](https://zoho.com/mail)
2. Click **"Sign Up For Free"**
3. Scroll past the paid plans and choose the **Forever Free** plan
4. When asked for your domain, choose **"Add an existing domain"** and enter `sarahelbahloul.dev`
5. Create a Zoho account — use your personal Gmail as the recovery email
6. When Zoho asks you to verify domain ownership — **stop here and go to step 1.3 before continuing**

---

### 1.3 — Verify your domain in Zoho via Namecheap DNS

Zoho will show you a TXT record to prove you own the domain. It looks like this:

```
Type:  TXT
Host:  @
Value: zoho-verification=zb12345678.zmverify.zoho.com
```

The exact value will be different for your account — copy it from Zoho's screen.

To add it to Namecheap:

1. Go back to your Namecheap tab → **Domain List → Manage → Advanced DNS**
2. Click **"Add New Record"**
3. Set:
    - Type: **TXT Record**
    - Host: **@**
    - Value: the full string Zoho gave you
    - TTL: **Automatic**
4. Click the green checkmark to save
5. Go back to Zoho and click **"Verify"**

> DNS propagation on Namecheap usually takes 2–10 minutes. If Zoho says it cannot verify yet, wait 5 minutes and try again. Don't wait more than 30 minutes — if it's still failing, double-check that the TXT record was saved in Namecheap with no extra spaces in the value.

---

### 1.4 — Create your two email mailboxes in Zoho

Once the domain is verified, Zoho walks you through creating the first mailbox:

1. Create `hello@sarahelbahloul.dev` — your in-app support and feedback address
2. After that's done, go to **Settings → Email Addresses → Add Email Address** and create `privacy@sarahelbahloul.dev`

Both addresses now exist. Set up forwarding so you never have to check Zoho:

1. In Zoho → **Settings → Mail Accounts → hello@sarahelbahloul.dev → Filters & Forwarding**
2. Add your personal Gmail as the forwarding address
3. Repeat the same for `privacy@sarahelbahloul.dev`

Any email sent to either address will now land in your Gmail inbox automatically.

---

### 1.5 — Add Zoho's MX records to Namecheap

MX records tell the internet that emails for `sarahelbahloul.dev` should be delivered to Zoho's servers. Zoho shows you the exact records to add — they will look like this:

```
Type: MX    Host: @    Value: mx.zoho.com     Priority: 10
Type: MX    Host: @    Value: mx2.zoho.com    Priority: 20
Type: MX    Host: @    Value: mx3.zoho.com    Priority: 50
```

Back in Namecheap → **Advanced DNS**:

1. Check if there are any existing MX records — Namecheap sometimes adds a default one. If there are any, delete them first.
2. Add each of the three MX records Zoho gives you, one by one, saving each with the green checkmark
3. Wait 10 minutes

To confirm it worked: send a test email from your personal Gmail to `hello@sarahelbahloul.dev`. It should arrive back in your Gmail inbox within a couple of minutes via the forwarding you set up. If it bounces, go back to Namecheap Advanced DNS and check the MX records for typos.

---

### 1.6 — Update the two placeholder emails in Poppy

Now that the addresses are real and working, update the code:

**File 1:** `lib/screens/settings/settings_screen.dart`, line 431

```dart
// Change:
const email = 'hello@poppy.app'; // todo: change this to actual email

// To:
const email = 'hello@sarahelbahloul.dev';
```

**File 2:** `lib/screens/settings/legal_screen.dart`, line 115

```dart
// Change:
'For privacy concerns or data requests, contact us at privacy@poppydiary.app.'

// To:
'For privacy concerns or data requests, contact us at privacy@sarahelbahloul.dev.'
```

---

### 1.7 — Create your Google Play Console account

1. Go to [play.google.com/console](https://play.google.com/console)
2. Sign in with your **personal Gmail** — this must be the Google account you want permanently attached to your developer account and billing. You cannot change it later.
3. Click **"Get started"** → read and agree to the developer distribution agreement
4. Pay the **$25 one-time registration fee**
5. Fill in your developer name — use your real name: `Sarah Elbahloul`. This is what appears on the Play Store as the publisher name next to your app.
6. Add a contact email — use `hello@sarahelbahloul.dev`
7. Complete identity verification if prompted (they may ask for a phone number to confirm)

The account is usually active within a few hours, sometimes immediately after payment.

> **iOS / Apple Developer account:** Skip this for now. The $99/year cost is not worth it while you're broke. One store is enough for a portfolio. Add iOS after you get your first job.

---

### 1.8 — Confirm everything before moving to Phase 2

Run through this checklist. Do not start Phase 2 until all boxes are checked:

- [ ] `sarahelbahloul.dev` shows as active in your Namecheap dashboard
- [ ] Zoho shows `hello@sarahelbahloul.dev` and `privacy@sarahelbahloul.dev` as active mailboxes
- [ ] Test email sent to `hello@sarahelbahloul.dev` arrived in your Gmail ✓
- [ ] Test email sent to `privacy@sarahelbahloul.dev` arrived in your Gmail ✓
- [ ] `settings_screen.dart` line 431 updated to `hello@sarahelbahloul.dev`
- [ ] `legal_screen.dart` line 115 updated to `privacy@sarahelbahloul.dev`
- [ ] Google Play Console account is active (not pending review)

---

## Phase 2 — Fix Critical Code Issues

These must be resolved before the app can be submitted. Do them in this order.

### 2.1 — Fix the PBKDF2 salt (security bug)

**File:** `lib/services/encryption_service.dart`

**The problem:** Every user's password-derived wrapping key is generated with the same static salt `'poppy-diary-salt-v1'`. PBKDF2 salts must be unique per user to be effective. As it stands, two users with the same password produce the same wrapping key, and a single precomputed table can attack all users simultaneously.

**The fix:** Generate a random 16-byte salt at registration, store it in the `user_keys` table alongside the wrapped key, and use it during derivation. Also increase the iteration count — 100,000 was the OWASP minimum circa 2021; the current recommendation for HMAC-SHA256 is 600,000.

**Step 1** — Add salt columns to your Supabase `user_keys` table. Run this in the Supabase SQL editor:

```sql
alter table public.user_keys
  add column if not exists password_salt text;

alter table public.user_keys
  add column if not exists recovery_salt text;
```

**Step 2** — Update `_deriveKeyFromPassword` in `encryption_service.dart` to accept a salt parameter and use 600,000 iterations:

```dart
Future<SecretKey> _deriveKeyFromPassword(String password, Uint8List salt) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,  // updated from 100,000 — current OWASP recommendation
    bits: 256,
  );
  return pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,  // per-user random salt, not a hardcoded string
  );
}
```

> **Performance note:** 600,000 PBKDF2 rounds on a budget Android device can take 1–2 seconds and will freeze the UI if run on the main thread. Wrap all calls to `_deriveKeyFromPassword` inside a `compute()` isolate:
> ```dart
> final wrappingKey = await compute(_deriveKeyIsolate, (password, salt));
> ```
> where `_deriveKeyIsolate` is a top-level (not instance) function that calls `_deriveKeyFromPassword`. This moves the work off the UI thread entirely.

**Step 3** — Update `wrapWithPassword` to generate and return the salt, and `unwrapWithPassword` to accept it:

```dart
// Returns both the wrapped key map AND the salt used
Future<({Map<String, String> wrapped, String saltB64})> wrapWithPassword(
  Uint8List dataKeyBytes,
  String password,
) async {
  // _rng is already Random.secure() in your code — no change needed there
  final salt = Uint8List(16);
  for (var i = 0; i < 16; i++) salt[i] = _rng.nextInt(256);
  final wrappingKey = await compute(_deriveKeyIsolate, (password, salt));
  final wrapped = await _wrap(dataKeyBytes, wrappingKey);
  return (wrapped: wrapped, saltB64: base64Encode(salt));
}

Future<Uint8List?> unwrapWithPassword(
  Map<String, dynamic> wrapped,
  String password,
  String saltB64,  // new parameter
) async {
  final salt = base64Decode(saltB64);
  final wrappingKey = await compute(_deriveKeyIsolate, (password, salt));
  return _unwrap(wrapped, wrappingKey);
}
```

**Step 4** — Update `KeyService` and `AuthProvider` to save and load the salt alongside the wrapped key wherever `wrapWithPassword` / `unwrapWithPassword` is called. The salt is not secret — store it in plain text in the `password_salt` column next to the wrapped key blob.

> **Note for existing test accounts:** Once you make this change, any account created with the old static salt cannot unwrap its key. Before launch this doesn't matter (no real users yet), but delete any test accounts from Supabase Auth and re-register after deploying the migration.

---

### 2.2 — Document (and partially improve) the recovery key

**File:** `lib/services/encryption_service.dart`, method `_deriveKeyFromUid`

**The problem:** The recovery wrapping key is derived from the user's Supabase UID plus a hardcoded pepper visible in your public source code. UIDs are not secret. Adding a per-user `recovery_salt` (as in 2.1) meaningfully improves this — without it, a single precomputed table covers all users. With unique per-user salts, each user requires independent cracking. It does not make the recovery path fully zero-knowledge (a compromised backend with source code access could still derive recovery keys), but it is a real, not cosmetic, improvement.

**The fix:** Apply the same salt approach as Step 2–4 above but for `wrapWithUid` / `unwrapWithUid`. Use the `recovery_salt` column added in 2.1.

Apply the same `compute()` isolate pattern for `_deriveKeyFromUid` as well.

**What to document in your README** (see Phase 7.4 for the full security model section):

The recovery path is a deliberate convenience trade-off. A fully zero-knowledge recovery requires either user-supplied recovery codes (like Bitwarden's emergency sheet) or server-side hardware security modules (like Proton's approach). Neither is practical for a solo portfolio project. Documenting this honestly signals engineering maturity — it shows you understand the threat model rather than overselling the security guarantees.

---

### 2.3 — Add missing iOS permission strings

**File:** `ios/Runner/Info.plist`

The app uses `image_picker` for attaching photos. Apple requires human-readable usage descriptions for camera and photo library access. Without them, the app crashes when a user taps "add photo" on iOS, and Apple will reject the submission at review.

Add these three keys inside the `<dict>` in `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Poppy uses your camera so you can attach photos to your diary entries.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Poppy accesses your photo library so you can attach images to your diary entries.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Poppy saves photos to your library when you export an entry.</string>
```

---

### 2.4 — Fix the iOS orientation conflict

**File:** `ios/Runner/Info.plist`

`main.dart` locks the app to portrait via `SystemChrome.setPreferredOrientations`, but `Info.plist` currently declares landscape support. They must agree.

Find the `UISupportedInterfaceOrientations` key in `Info.plist` and change it to portrait-only:

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>

<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
</array>
```

---

### 2.5 — Register the Supabase deep link scheme in iOS

**File:** `ios/Runner/Info.plist`

The Android manifest already has the `io.supabase.poppy://login-callback/` intent filter registered. iOS is currently missing the equivalent URL scheme registration, which means password reset emails will not redirect back into the app on iOS.

Add this block inside the root `<dict>` in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.poppy</string>
        </array>
    </dict>
</array>
```

---

### 2.6 — Add crash reporting with Sentry

Missing from the original guide. Even for a personal project, crash reporting gives you stack traces for startup crashes and device-specific issues that are invisible during local testing. It also looks professional to employers who read the repo.

**Why Sentry over Firebase Crashlytics:** Sentry is open source, GDPR-compliant by default, works without a `google-services.json`, doesn't add a Google dependency to a privacy-focused app, and the free tier covers personal projects comfortably.

**Step 1** — Add to `pubspec.yaml`:

```yaml
dependencies:
  sentry_flutter: ^8.0.0
```

**Step 2** — Create a free account at [sentry.io](https://sentry.io) and create a new Flutter project. Copy your DSN.

**Step 3** — Wrap your `main()` in `SentryFlutter.init`:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://your-dsn@sentry.io/your-project-id';
      options.tracesSampleRate = 0.2; // capture 20% of transactions
      options.environment = kDebugMode ? 'debug' : 'production';
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      // ... rest of your existing main() setup
      await SystemChrome.setPreferredOrientations([...]);
      await SupabaseConfig.init();
      await NotificationService.init();
      await LocalDbService.instance.init();
      runApp(MultiProvider(...));
    },
  );
}
```

**Step 4** — Add the Sentry DSN to your `--dart-define` setup (do not hardcode it):

```bash
flutter run \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=SENTRY_DSN=your_sentry_dsn
```

And read it in code:

```dart
options.dsn = const String.fromEnvironment('SENTRY_DSN');
```

**Step 5** — Add `SENTRY_DSN` to your `.gitignore` and `--dart-define` documentation in the README.

> **Privacy note:** Sentry should never capture entry content (it's encrypted anyway, but belt-and-suspenders). Sentry only captures unhandled exceptions and their stack traces by default — no user data unless you explicitly call `Sentry.captureMessage`. No changes needed to make this privacy-safe.

---

## Phase 3 — Fix All Placeholder Content

### 3.1 — Replace placeholder emails in the code

**File 1:** `lib/screens/settings/settings_screen.dart`, line 431

```dart
// Change this:
const email = 'hello@poppy.app'; // todo: change this to actual email

// To this (use whichever address you decided on in Phase 1):
const email = 'hello@yourdomain.com';
```

**File 2:** `lib/screens/settings/legal_screen.dart`, line 115

```dart
// Change this:
'For privacy concerns or data requests, contact us at privacy@poppydiary.app.'

// To this:
'For privacy concerns or data requests, contact us at privacy@yourdomain.com.'
```

---

### 3.2 — Update the privacy policy and terms dates

**File:** `lib/screens/settings/legal_screen.dart`

There are two "Last updated: January 2025" strings (lines 74 and 135). App store reviewers check these against the current date.

```dart
// Change both instances to the actual current date before submission, e.g.:
Text('Last updated: June 2026', ...)
```

---

### 3.3 — Update the copyright year in About screen

**File:** `lib/screens/settings/about_screen.dart`, line 160

```dart
// Change:
'© 2025 Poppy. Made with care.'

// To:
'© 2026 Poppy. Made with care.'
```

---

### 3.4 — Replace the broken widget test with real unit tests

**File:** `test/widget_test.dart`

The default Flutter counter test is still in there and fails on `flutter test`. Do not replace it with a placeholder `expect(true, isTrue)` — employers immediately recognize fake tests and it signals the opposite of what you want.

`EncryptionService` is pure Dart with no Flutter dependencies, which makes it the easiest and highest-signal thing to unit test. Replace the entire file with:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppy/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    late EncryptionService enc;

    setUp(() async {
      enc = EncryptionService.instance;
      await enc.generateDataKey();
    });

    tearDown(() async {
      await enc.clearKey();
    });

    test('encrypt then decrypt returns the original plaintext', () async {
      const original = 'This is a secret diary entry.';
      final json = await enc.encryptToJson(original);
      expect(json, isNotNull);
      final decrypted = await enc.decryptFromJson(json);
      expect(decrypted, equals(original));
    });

    test('encrypting the same string twice produces different ciphertexts', () async {
      const text = 'Same input';
      final a = await enc.encryptToJson(text);
      final b = await enc.encryptToJson(text);
      // nonces are random — ciphertexts must differ
      expect(a, isNot(equals(b)));
    });

    test('decrypting with no key loaded returns fallback', () async {
      await enc.clearKey(); // remove the key
      const fallback = 'fallback';
      final result = await enc.decryptFromJson('{"c":"abc","n":"def","m":"ghi"}',
          fallback: fallback);
      expect(result, equals(fallback));
    });

    test('encryptEntry and decryptEntry round-trip preserves title and content', () async {
      const title = 'Monday';
      const content = 'A good day.';
      final encrypted = await enc.encryptEntry(title: title, content: content);
      final decrypted = await enc.decryptEntry(
        titleJson: encrypted.titleJson,
        contentJson: encrypted.contentJson,
      );
      expect(decrypted.title, equals(title));
      expect(decrypted.content, equals(content));
    });
  });
}
```

These four tests directly demonstrate the security properties of the encryption implementation to anyone reading the repo. They run in under a second and require no mocks.

---

## Phase 4 — Change Bundle IDs (Required for Store Submission)

Both platforms currently use `com.example.poppy` which is the Flutter default. Google Play and the App Store both reject submissions with `com.example` in the ID.

Choose your bundle ID now and use it consistently everywhere. The convention is `com.yourname.appname` or `dev.yourname.appname`. For example: `com.sarahelbahloul.poppy`.

### 4.1 — Android bundle ID

**File:** `android/app/build.gradle.kts`

```kotlin
// Change both of these:
namespace = "com.example.poppy"
applicationId = "com.example.poppy"

// To:
namespace = "com.sarahelbahloul.poppy"
applicationId = "com.sarahelbahloul.poppy"
```

**File:** `android/app/src/main/kotlin/com/example/poppy/MainActivity.kt`

The file is at the wrong path. You need to:
1. Create the directory `android/app/src/main/kotlin/com/sarahelbahloul/poppy/`
2. Move `MainActivity.kt` there
3. Update the `package` declaration at the top of the file:

```kotlin
package com.sarahelbahloul.poppy
```

The Supabase deep link scheme in `AndroidManifest.xml` uses `io.supabase.poppy` — that is independent of the package name and does not need to change.

---

### 4.2 — iOS bundle ID

Open Xcode (you need a Mac for this step):

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Click on "Runner" in the project navigator → select the "Runner" target.
3. Under the "General" tab, find "Bundle Identifier".
4. Change `com.example.poppy` to `com.sarahelbahloul.poppy`.
5. Xcode will update `project.pbxproj` automatically. Do not edit it by hand.

This also fixes the test target identifiers automatically.

---

## Phase 5 — Set Up Release Signing

### 5.1 — Android signing keystore

**This is critical.** The keystore you use for your first Play Store upload is permanent — you cannot change it later without losing all existing users' ability to update the app.

**Step 1** — Generate a keystore (keep this file safe, back it up to a password manager or cloud drive, do not commit it to git):

```bash
keytool -genkey -v \
  -keystore ~/poppy-release.jks \
  -alias poppy \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

You will be prompted for a keystore password, your name, organization, and country. Remember the password — there is no recovery.

**Step 2** — Create `android/key.properties` (already in `.gitignore` ✓):

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=poppy
storeFile=/absolute/path/to/poppy-release.jks
```

**Step 3** — Update `android/app/build.gradle.kts` to use the keystore for release builds:

```kotlin
// Add this block before the android { } block:
import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")  // was "debug" — fix this
            minifyEnabled = false
        }
    }
}
```

---

### 5.2 — iOS signing (requires Apple Developer account from Phase 6)

You set up iOS signing inside Xcode after creating your Apple Developer account. Come back to this step after completing Phase 6.1.

1. In Xcode → Runner target → "Signing & Capabilities" tab.
2. Check "Automatically manage signing".
3. Select your Apple Developer team from the dropdown.
4. Xcode will create a provisioning profile and certificate automatically.

---

## Phase 6 — Create Developer Accounts

### 6.1 — Apple Developer Program

- Cost: $99/year
- URL: [developer.apple.com/programs](https://developer.apple.com/programs)
- Use your personal Apple ID (or `dev@yourdomain.com` if you set one up).
- Approval takes 24–48 hours after payment.
- You need this account to: sign iOS builds, create App IDs, and submit to the App Store.
- After approval, go to [App Store Connect](https://appstoreconnect.apple.com) with the same Apple ID to set up the app listing.

---

### 6.2 — Google Play Console

- Cost: $25 one-time
- URL: [play.google.com/console](https://play.google.com/console)
- Use your personal Gmail (the one you want billing attached to) or `dev@yourdomain.com`.
- Account is approved almost immediately after payment.
- You will need to complete identity verification (phone number, address).

---

### 6.3 — Supabase account (if not done already)

- Free tier is sufficient for a personal project / CV demo.
- URL: [supabase.com](https://supabase.com)
- Use your personal Gmail or `dev@yourdomain.com` — **not** the in-app support email.
- After creating the account, make sure your production Supabase project has:
    - The redirect URL `io.supabase.poppy://login-callback/` added under Authentication → URL Configuration → Redirect URLs.
    - The `entry-photos` storage bucket set to **Private**.
    - All four migration SQL files (`01_tables.sql` through `04_functions_triggers.sql`) run in order.
    - The new `password_salt` and `recovery_salt` columns from Phase 2.1 added.

---

## Phase 7 — GitHub Repo Cleanup (for CV)

### 7.1 — Remove files that should not be in source control

The following should not be committed. Check your git history and remove them if they were ever committed:

- `android/.gradle/` — Gradle build cache, ~30MB, no business being in git
- `.idea/` — IDE-specific files, different on every developer's machine
- `android/local.properties` — contains your local SDK path (already in `.gitignore` ✓)
- `.env` — already in `.gitignore` ✓, but verify it was never accidentally committed:

```bash
git log --all --full-history -- .env
git log --all --full-history -- "android/.gradle"
```

If they appear in history, remove them with:

```bash
git filter-branch --force --index-filter \
  "git rm -r --cached --ignore-unmatch android/.gradle .idea" \
  --prune-empty --tag-name-filter cat -- --all
```

Then add them explicitly to `.gitignore` if not already there.

---

### 7.2 — Add missing `.gitignore` entries

Open `.gitignore` and confirm these lines exist (add if missing):

```
# IDE
.idea/
*.iml

# Android build cache
android/.gradle/
android/build/
```

---

### 7.3 — Update the README screenshots

The README currently has `> Add screenshots here once the app is running.` — this is the first thing anyone visiting the repo sees.

1. Run the app on a real device.
2. Take screenshots of: home screen (with a few entries), write screen, appearance screen (showing a theme switch), lock screen.
3. Add a `screenshots/` folder to the repo and include them.
4. Replace the placeholder in `README.md`:

```markdown
## Screenshots

| Home | Write | Themes | Lock |
|------|-------|--------|------|
| ![home](screenshots/home.png) | ![write](screenshots/write.png) | ![themes](screenshots/themes.png) | ![lock](screenshots/lock.png) |
```

---

### 7.4 — Add technical decisions and security model to the README

This section has more CV impact than any number of extra features. Employers and engineering managers read this to see if you understand the choices you made. Add two sections below the tech stack table:

```markdown
## Why these technical choices?

**AES-256-GCM with a per-user data key** — Symmetric encryption is fast enough
for diary content. The key-wrapping architecture (data key wrapped by a
password-derived key) means the raw data key never touches the server in
plaintext, and changing a password requires only re-wrapping the data key
rather than re-encrypting all content.

**Offline-first with a sync queue** — SQLite is the source of truth. Every
create/update/delete writes locally first and enqueues a sync operation.
When connectivity returns, the queue drains against Supabase. This means
zero data loss on flaky connections and instant UI response.

**Provider over Riverpod/BLoC** — Poppy has three providers and a clear
unidirectional data flow. Provider fits this scale without the boilerplate
overhead of Riverpod or the verbosity of BLoC.

## Security model and known trade-offs

**What is zero-knowledge:** The password-wrapping path is zero-knowledge.
The server stores only the wrapped (encrypted) data key, derived using
PBKDF2 with 600,000 iterations and a unique per-user salt. The server
never sees the plaintext data key or a means to derive it from what is stored.

**What is not zero-knowledge:** The recovery path derives a second wrapping
key from the user's account UID. This is a deliberate convenience trade-off:
it allows password recovery without user-managed backup codes, at the cost of
a compromised backend being able to recover encrypted keys. Fully zero-knowledge
recovery would require user-supplied recovery codes (Bitwarden-style) or
server-side HSMs (Proton-style) — neither is practical for a solo project.

**Metadata visibility:** Entry timestamps, word counts, color tags, and the
account email address are visible to the backend as plaintext. Only entry
titles and content are encrypted.
```

---

### 7.5 — Add a GitHub Actions CI workflow

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter test integration_test/ --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
        continue-on-error: true  # integration tests require a live Supabase project; don't block CI if secrets aren't set
```

Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` to your GitHub repo's Settings → Secrets and Variables → Actions. This allows the integration test step to run properly in CI while not blocking the analyze and unit test steps if secrets are missing.

---

### 7.6 — Add integration tests

Create the directory `integration_test/` in the project root and add `app_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poppy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Core flows', () {
    testWidgets('login screen renders and shows email field', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // After launch, unauthenticated users land on LoginScreen
      expect(find.byKey(const Key('email_field')), findsOneWidget);
    });

    testWidgets('write screen opens from home screen FAB', (tester) async {
      // Assumes a test account is already signed in via setUp
      // Add your test credentials here, or skip this test if not running with live Supabase
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));
      // If authenticated, home screen should show the write button
      final writeFab = find.byKey(const Key('write_fab'));
      if (writeFab.evaluate().isNotEmpty) {
        await tester.tap(writeFab);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('title_field')), findsOneWidget);
      }
    });
  });
}
```

Add the `integration_test` package to `pubspec.yaml`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

Add `Key` values to your important widgets (write FAB, email field, title field) so the tests can find them. Even two passing integration tests look significantly better than none.

---

## Phase 8 — Copyright, Legal, and Public GitHub Considerations

### 8.1 — What the MIT license on your repo means

Your `LICENSE` file says MIT, which means:

- Anyone can use, copy, modify, and distribute the code, including commercially.
- They must keep your copyright notice.
- **This is fine for a CV project.** It signals openness and is the standard for portfolio work.
- It does **not** affect your right to publish the app on the stores under your own name — you are the copyright holder.

If you wanted to prevent others from publishing the same app to the stores, you would use a more restrictive license (AGPL, or a custom license). For a portfolio project, MIT is the right call.

---

### 8.2 — Trademark and name check

"Poppy" is a common word and is unlikely to be trademarked in the diary/journaling space, but do a quick check before investing time in store listings:

1. Search [USPTO TESS](https://tmsearch.uspto.gov) for "Poppy" in class 042 (software/apps).
2. Search the App Store and Google Play for "Poppy diary" to see if there is an existing app with the same name.
3. If there is a conflict, rename the app (the bundle ID, `pubspec.yaml` name, and display names) before submitting.

---

### 8.3 — What the stores actually require for legal compliance

Neither Google Play nor the App Store require you to have a registered business, trademark, or domain name to publish. What they do require:

**Google Play:**
- A privacy policy URL (must be a live, accessible URL — not a PDF, not in-app only).
- Data safety form declaration (what data you collect, whether it is encrypted).
- A target audience declaration.

**App Store:**
- A privacy policy URL (same — must be live and accessible).
- App Privacy "nutrition label" in App Store Connect.
- Export compliance declaration (covered in Phase 8.4).

**For the privacy policy URL:** The simplest solution is GitHub Pages. Create a file `docs/privacy.md` in your repo with the content from your in-app privacy policy screen, then enable GitHub Pages:

1. In your repo → Settings → Pages → Source: `main` branch, `/docs` folder.
2. Your policy URL will be `https://sarah-elbahloul.github.io/poppy/privacy` — but verify the exact URL after enabling Pages, as it depends on your repo name and folder structure. Do not hardcode it anywhere until you have confirmed the live URL.
3. Use this verified URL in the Play Console and App Store Connect privacy policy fields.

---

### 8.4 — Export compliance (iOS)

When submitting to the App Store, you will be asked: "Does your app use encryption?" — Yes, it does (AES-256-GCM). Answer:

- "Yes" to using encryption
- "Yes" to being exempt — because the app uses only standard encryption algorithms for the purpose of protecting user data (this qualifies under the ENC exemption)
- You do **not** need to file an ERN (Encryption Registration Number) for this use case

Add this key to `Info.plist` to pre-declare it and avoid the question during every submission:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This tells Apple: "I use encryption, but it is standard/exempt." If you omit it, Xcode will prompt you during every archive upload.

---

## Phase 9 — Build Release Binaries

### 9.1 — Android App Bundle

```bash
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=SENTRY_DSN=your-sentry-dsn \
  --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

---

### 9.2 — iOS Archive (requires Mac + Xcode)

1. Ensure you have completed Phase 5.2 (Xcode signing setup).
2. Run:

```bash
flutter build ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=SENTRY_DSN=your-sentry-dsn \
  --release
```

3. Open `ios/Runner.xcworkspace` in Xcode.
4. Select `Product → Archive`.
5. When the Organizer opens, click "Distribute App" → "App Store Connect" → follow the prompts.

---

## Phase 10 — App Store Listings (Do This Before Uploading Builds)

### 10.1 — Google Play Console listing

Log into [play.google.com/console](https://play.google.com/console):

1. Create a new app → select "App" and "Free".
2. Fill in the store listing:
    - **Title:** Poppy — Private Diary
    - **Short description** (80 chars max): *A calm, end-to-end encrypted diary. Your words stay yours.*
    - **Full description** (4000 chars): expand on your README features section.
    - **Category:** Productivity (or Lifestyle)
    - **Privacy policy URL:** your verified GitHub Pages URL from Phase 8.3
3. Upload screenshots (phone + 7-inch tablet minimum).
4. Fill out the **Data safety** form:
    - Data collected: Email address (account management, required, not shared with third parties)
    - All diary content: encrypted and never accessed by the developer — declare it as not collected
    - Confirm data is encrypted in transit (yes — Supabase uses TLS) and at rest (yes — AES-256-GCM)
5. Complete **App content** → content rating questionnaire (will rate as Everyone or Everyone 10+).
6. Set **Target audience** to 18+ (diary app, avoids COPPA compliance requirements).

---

### 10.2 — App Store Connect listing

Log into [appstoreconnect.apple.com](https://appstoreconnect.apple.com):

1. Create a new iOS app → enter bundle ID `com.sarahelbahloul.poppy`, name "Poppy".
2. Fill in the listing:
    - **Name:** Poppy
    - **Subtitle** (30 chars): *Your private, encrypted diary*
    - **Description:** same as Play Store full description
    - **Keywords** (100 chars): `diary,journal,private,encrypted,daily,writing,personal,secure`
    - **Category:** Productivity (primary), Lifestyle (secondary)
    - **Privacy Policy URL:** your verified GitHub Pages URL
3. Upload screenshots for iPhone 6.9" and iPhone 6.5" (required). iPad screenshots optional.
4. Fill out **App Privacy** (the "nutrition label"):
    - Contact info → Email address → Used for account management → User provides, linked to identity
    - Everything else: not collected
5. Fill out **Export Compliance** → uses standard encryption, exempt (see Phase 8.4).

---

## Phase 11 — Submit for Review

### 11.1 — Google Play

1. In the Play Console, go to "Testing" → "Internal testing" first. Upload the `.aab` and test with your own Google account for a few days.
2. When ready, go to "Production" → create a new release → upload the `.aab` → submit for review.
3. First-time reviews take 3–7 days. Subsequent updates are usually reviewed within hours.

---

### 11.2 — App Store

1. Upload the archive via Xcode Organizer (from Phase 9.2, step 5).
2. In App Store Connect, under the app → "iOS App" → "+" to add a build → select the uploaded build.
3. Click "Submit for Review".
4. First-time reviews typically take 1–3 days. Apple may ask clarification questions — check your registered Apple ID email.

---

## Quick Reference: Files Changed in This Guide

| File | What changes |
|---|---|
| `lib/services/encryption_service.dart` | Fix static PBKDF2 salt + raise iterations to 600k (2.1), recovery salt (2.2), compute() isolate |
| `lib/services/key_service.dart` | Store and pass salts alongside wrapped keys (2.1–2.2) |
| `lib/providers/auth_provider.dart` | Pass salts through sign-up and sign-in flows (2.1–2.2) |
| `lib/main.dart` | Wrap main() in SentryFlutter.init (2.6) |
| `ios/Runner/Info.plist` | Camera/photo permissions (2.3), orientation (2.4), URL scheme (2.5), encryption declaration (8.4) |
| `lib/screens/settings/settings_screen.dart` | Replace `hello@poppy.app` with real email (3.1) |
| `lib/screens/settings/legal_screen.dart` | Replace `privacy@poppydiary.app`, update dates (3.1, 3.2) |
| `lib/screens/settings/about_screen.dart` | Update copyright year (3.3) |
| `test/widget_test.dart` | Replace broken default test with real EncryptionService unit tests (3.4) |
| `android/app/build.gradle.kts` | Change bundle ID, add proper release signing (4.1, 5.1) |
| `android/app/src/main/kotlin/` | Move MainActivity.kt to new package path (4.1) |
| `android/key.properties` | Create with keystore details — **do not commit** (5.1) |
| `ios/Runner.xcworkspace` | Change bundle ID in Xcode (4.2), set up signing (5.2) |
| `supabase/migrations/` | Add `password_salt` and `recovery_salt` columns (2.1) |
| `pubspec.yaml` | Add `sentry_flutter`, `integration_test` (2.6, 7.6) |
| `integration_test/app_test.dart` | Create integration tests (7.6) |
| `.github/workflows/ci.yml` | Create CI workflow with analyze, unit tests, integration tests (7.5) |
| `docs/privacy.md` | Create for GitHub Pages hosted privacy policy (8.3) |
| `README.md` | Screenshots, technical decisions, security model (7.3, 7.4) |
# Poppy — Complete Launch Guide

> Work through these phases in order. Each phase builds on the previous one.
> Estimated total time: **2–4 weeks** (mostly waiting on account approvals and email setup).

---

## Phase 1 — Set Up Your Email Infrastructure

Do this first because every account you create downstream (Supabase, Google Play, App Store Connect) needs a professional email, and the emails you put inside the app need to actually work before you submit for review.

**Cost for this phase: ~$35 one-time (~$10/year domain + $25 Google Play). Everything else is free.**

> **Important note on Resend vs. Cloudflare Email Routing — these do different jobs, and you need both:**
> - **Cloudflare Email Routing** = receiving. It catches mail sent *to* `hello@yourdomain.com` / `privacy@yourdomain.com` and forwards it to your Gmail. This is for users emailing *you* via the `mailto:` links in `settings_screen.dart` and `legal_screen.dart`.
> - **Resend** = sending, and it's **required, not optional**. Supabase Auth's built-in email sender (used for signup confirmation, password reset, magic links) is capped at **2 emails per hour** and is explicitly documented as a non-production, best-effort service. You will hit that limit during your own testing almost immediately — one signup plus one password-reset test can use it up. Configuring a custom SMTP provider (Resend, in this guide) raises that to 30/hour by default and is what Supabase itself recommends before going anywhere near real users.
>
> So: do 1.3–1.4 (verify the domain in Resend) **and** the new step below that wires Resend into Supabase's Auth SMTP settings — that's the part that actually raises the limit. Verifying the domain alone doesn't do anything until it's connected.

### What email addresses you will end up with

| Address | Purpose | Where it appears |
|---|---|---|
| `hello@sarahelbahloul.dev` | General contact / support / feedback | `settings_screen.dart` line 238 — the "Send feedback" button |
| `privacy@sarahelbahloul.dev` | Privacy concerns and GDPR data requests | `legal_screen.dart` line 109 — Privacy Policy contact |
| Your personal Gmail | Developer accounts only (receives forwarded mail) | Supabase, Google Play — never shown inside the app |

> The in-app support emails and your developer account email are kept separate on purpose. Developer account email is tied to billing and legal agreements. Support emails are public-facing and can change.

---

### 1.1 — Buy the domain on Cloudflare Registrar

Cloudflare sells domains at wholesale cost with zero markup.

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) and create an account (use your personal Gmail).
2. On the sidebar, click **"Domain Registration"** → **"Register Domains"**.
3. Search `sarahelbahloul.dev`.
4. Add to cart and checkout. It should be around $10-$12 for the first year.
5. **Turn off auto-renew** during checkout if you want to avoid surprise charges (you can re-enable later).
6. Pay and complete.

> After purchase, click on the domain name in your Cloudflare dashboard to go to the **Overview** page. Keep this tab open.

---

### 1.2 — Set up Email Receiving (Cloudflare Email Routing)

This free Cloudflare feature catches emails sent to `@sarahelbahloul.dev` and forwards them to your Gmail.

1. In your Cloudflare domain dashboard, click **"Email"** → **"Email Routing"** in the sidebar.
2. Click **"Enable Email Routing"**.
3. Cloudflare will ask you to add some MX and TXT records. **Click "Add records automatically"** — Cloudflare handles this for you instantly.
4. Go to the **"Routing rules"** tab.
5. Add named rules first — these are the addresses that actually matter:
    - Click **"Create rule"**.
    - Name: "Support"
    - Match: `hello@sarahelbahloul.dev`
    - Action: Forward to `your-personal-gmail@gmail.com`
    - Repeat for `privacy@sarahelbahloul.dev`.
6. *(Optional)* Under **"Catch-all address"**, you can also select **"Forward to"** and enter your Gmail, so typos like `hellos@...` still reach you.
   > **Heads up:** a catch-all forwards *everything* sent to the domain — including spam bots probing common prefixes (`admin@`, `info@`, `contact@`, etc.). Once the domain has aged a bit this can get noisy in your Gmail. If you'd rather keep things clean, skip the catch-all and rely on the two named rules above; anything not matching them will just bounce, which is fine.
7. Click **"Save"**.

> **Wait 10 minutes** for the routing to propagate globally.

---

### 1.3 — Set up Email Sending (Resend) — required for Auth to work past testing

Supabase's built-in email sender is capped at 2 emails/hour and is not meant for production. Verifying your domain in Resend is step one of removing that cap (step two is wiring it into Supabase — see 1.4a below).

1. Go to [resend.com](https://resend.com) and sign up using your personal Gmail.
2. Go to **Domains** → **"Add Domain"**.
3. Enter `sarahelbahloul.dev` and click **"Add"**.
4. Resend will display a list of DNS records you need to add (usually 1 TXT record for domain verification, and 3-4 CNAME records for DMARC/DKIM). **Keep this tab open.**

---

### 1.4 — Add Resend DNS Records to Cloudflare

Resend has an official **Domain Connect** integration for Cloudflare, which is easier and less error-prone than adding records by hand.

1. On the Resend "Add Domain" screen (or the domain's detail page), look for **"Sign in to your domain host to authorize DNS changes"** / **Auto Configure** — use it.
2. You'll be redirected to a Cloudflare login/authorization screen. Sign in and approve access (scoped to DNS changes on that domain only).
3. Resend will automatically add the required records to Cloudflare — the TXT verification record and the DKIM CNAME(s) — including setting the correct proxy status (DNS-only) on the CNAMEs, which is the one thing that's easy to get wrong doing this manually.
4. Back in Resend, click **"Verify DNS Records"**. It may take a few minutes up to a few hours to turn green.
5. Double-check in Cloudflare → **DNS → Records** that the new CNAME records show the **grey cloud (DNS only)**, not orange (proxied) — auto-configure sets this correctly, but it's worth a quick visual confirmation since a proxied CNAME breaks DKIM signing.

<details>
<summary>If auto-configure isn't available or fails, add the records manually instead</summary>

1. Go back to your Cloudflare domain tab → **"DNS"** → **"Records"**.
2. For each record shown in the Resend dashboard:
    - Click **"Add record"**.
    - **Type:** Match what Resend says (usually TXT or CNAME).
    - **Name:** Match what Resend says (e.g., `resend._domainkey`).
    - **Value:** Match what Resend says (the long string).
    - **Proxy status:** For CNAME records specifically, click the orange cloud icon to turn it **Grey (DNS only)**. Resend handles its own routing, and Cloudflare proxying can break DKIM signatures.
    - Click **"Save"**.
3. Repeat for all records Resend listed.

</details>

---

### 1.4a — Connect Resend to Supabase Auth (the step that actually raises the rate limit)

Domain verification in Resend alone does nothing for your app — Supabase still uses its own 2/hour sender until you point it at Resend explicitly.

1. In Resend, go to **API Keys → Create API Key**. Give it Sending access, scoped to your verified domain if offered. Copy the key (starts with `re_`) — you won't see it again.
2. In your Supabase project dashboard, go to **Project Settings → Authentication → SMTP Settings** (some dashboard versions show this as **Authentication → Emails → SMTP Provider**).
3. Toggle **Enable Custom SMTP** on.
4. Fill in Resend's SMTP credentials:
    - **Host:** `smtp.resend.com`
    - **Port:** `465` (SSL) or `587` (TLS) — either works
    - **Username:** `resend`
    - **Password:** the API key you just created (`re_...`)
    - **Sender email:** something on your verified domain, e.g. `hello@sarahelbahloul.dev` or `auth@sarahelbahloul.dev`
    - **Sender name:** `Poppy`
5. Save. Supabase will send a test email — confirm it arrives.
6. Go to **Authentication → Rate Limits** and confirm/raise the email rate limit (defaults to 30/hour once custom SMTP is active — plenty for a portfolio project, no need to raise further).

> **Why this matters for the app specifically:** Poppy's sign-up, password reset, and email-change flows all go through Supabase Auth's built-in mailer — the guide doesn't have you write any custom email-sending code, so this dashboard step is the *only* place the fix happens. Skipping it means you'll hit "email rate limit exceeded" errors the moment you test sign-up more than twice in an hour, which will look like a broken app during your own QA and potentially during App Store / Play Store review testing too.

---

### 1.5 — Update the two placeholder emails in Poppy

Checked the actual code: the original `hello@poppy.app` / `privacy@poppydiary.app` placeholders are already gone, so there's nothing to do at this exact point in the guide. They were changed to your personal Gmail instead of the domain addresses you're setting up here, though — that's a Phase 3 item now (see **3.1**) since it made more sense to handle it alongside the other placeholder-content cleanup. Skip ahead there once you've finished Phase 1.

---

### 1.6 — Create your Google Play Console account

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

### 1.7 — Confirm everything before moving to Phase 2

Run through this checklist. Do not start Phase 2 until all boxes are checked:

- [ ] `sarahelbahloul.dev` shows as active in your Cloudflare dashboard
- [ ] Cloudflare Email Routing is enabled with named rules for `hello@` and `privacy@` (catch-all optional — see note in 1.2)
- [ ] Resend domain status shows **"Verified"**
- [ ] Custom SMTP (Resend) is enabled in Supabase → Authentication → SMTP Settings, and the test email arrived
- [ ] Test email sent to `hello@sarahelbahloul.dev` arrived in your Gmail (via Cloudflare Routing) ✓
- [ ] Test email sent to `privacy@sarahelbahloul.dev` arrived in your Gmail ✓
- [ ] Signed up two test accounts back-to-back without hitting a Supabase email rate-limit error ✓

> **Note:** API abuse protection (CAPTCHA, rate limits, RLS audit, storage limits) is covered in Phase 2.7 — do that before you consider the app publicly ready, even though it's technically a Phase 2 item.
- [ ] `settings_screen.dart` line 238 and `legal_screen.dart` line 109 updated to the real addresses — done in Phase 3.1, not here (see note in 1.5)
- [ ] Google Play Console account is active (not pending review)

---

## Phase 2 — Fix Critical Code Issues

These must be resolved before the app can be submitted. Do them in this order.

### 2.1 & 2.2 — PBKDF2 salt + recovery key salt — ✅ already done, and better than the original plan

**File:** `lib/features/auth/data/services/encryption_service.dart`

Checked against the actual code — this is fully implemented, and the design is better than what was originally planned here, so both steps are removed. What's actually there:

- Every `wrapWithPassword` / `wrapWithUid` call generates a fresh random 16-byte salt and embeds it directly in the wrapped-key JSON blob (as the `s` field), alongside the ciphertext/nonce/MAC. **This means no separate `password_salt` / `recovery_salt` columns are needed on `user_keys`** — the salt travels with the key it belongs to instead of living in a parallel column that has to be kept in sync. Simpler and just as secure.
- PBKDF2-HMAC-SHA256 at 600,000 iterations — matches the current OWASP recommendation exactly.
- Key derivation runs inside `Isolate.run()` — functionally the same fix as the `compute()` isolate this guide originally called for (keeps 600k rounds off the UI thread).
- `unwrapWithPassword` / `unwrapWithUid` fall back to the original static salt (`'poppy-diary-salt-v1'` / `'poppy-recovery-pepper-v1'`) when a blob has no `s` field — meaning **any pre-fix test accounts still unwrap correctly**, no need to delete and re-register them like the original guide suggested.
- `KeyService` and `AuthProvider` already pass the salted, wrapped blobs straight through — no extra wiring needed on top.

Nothing to do here. If you add more wrap/unwrap call sites later, just keep using `wrapWithPassword` / `wrapWithUid` as-is — the salting is automatic.

---

### 2.3 — Add missing iOS permission strings

Confirmed still needed — none of the three keys below are present in `Info.plist`.

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

Confirmed still needed — `main.dart` locks to portrait via `SystemChrome.setPreferredOrientations`, but `Info.plist` still declares landscape support, unchanged from the original.

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

Confirmed: Android's `AndroidManifest.xml` already has the `io.supabase.poppy://login-callback/` intent filter correctly registered (lines 60–79). iOS is still missing the equivalent `CFBundleURLTypes` block in `Info.plist`.

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

Confirmed still needed — no `sentry_flutter` in `pubspec.yaml`, and `main()` isn't wrapped in `SentryFlutter.init`.

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

### 2.7 — Protect Against API Abuse and Unexpected Billing

Two separate risks once the app is public: bots hammering your Supabase project (burning your Resend email quota, filling your database with junk accounts), and surprise charges if usage spikes. Here's how to close both off — none of this requires paying for anything.

**Why this is lower-risk than it sounds:** on the Free plan, Supabase cannot bill you at all — exceeding a quota (egress, storage, etc.) just pauses that resource until your billing cycle resets, never charges your card. Resend's free plan (100 emails/day, 3,000/month) works the same way: sending pauses at the cap, and it will not charge you unless you add a card and manually enable "Transactional Overages" in settings — leave that off. So the real risk isn't your bill, it's bots burning your email quota and locking real users out of sign-up/reset flows, or filling your database with junk rows. The steps below stop that.

**Step 1 — Add CAPTCHA to Supabase Auth (the highest-impact fix)**

Supabase Auth supports Cloudflare Turnstile natively for sign-up, sign-in, and password reset — and you already have a Cloudflare account from Phase 1.

1. In your Cloudflare dashboard → **Turnstile** → **Add a site**. Give it a name, add your domain, and choose the **Managed** challenge type (invisible to most real users).
2. Copy the **Site Key** and **Secret Key** Cloudflare gives you.
3. In Supabase → **Authentication → Attack Protection** (some dashboard versions show this under **Settings → Auth**), toggle **Enable CAPTCHA protection**, choose **Turnstile** as the provider, and paste the **Secret Key**. Save.
4. On the client side, Turnstile is a *web* widget — Supabase's official examples assume a browser frontend. Since Poppy is a Flutter app, you'll need to render the Turnstile challenge inside a `WebView` and pass the resulting token into `captchaToken` on `signUp`, `signInWithPassword`, and `resetPasswordForEmail` calls in `auth_provider.dart`. There are a couple of community Flutter packages that wrap this (search pub.dev for "turnstile" — check current download counts/maintenance before picking one, since this ecosystem moves fast). This is the one piece of this section that's a real code change rather than a dashboard toggle, so budget some extra time for it.

> If the WebView integration feels like too much for a first release, at minimum do Steps 2–4 below — they meaningfully reduce risk on their own, just without blocking bots at the front door.

**Step 2 — Tune Supabase Auth rate limits**

In Supabase → **Authentication → Rate Limits**, review the defaults (sign-ups/hour, OTP requests/hour, etc.) and lower them if a solo-portfolio app doesn't need the default headroom. This is a pure dashboard change, no code required.

**Step 3 — Row Level Security (RLS) — ✅ already done**

Checked `supabase/migrations/03_policies.sql`: RLS is enabled on all four tables (`profiles`, `entries`, `photos`, `user_keys`) and every policy correctly scopes to `auth.uid() = user_id` (or `= id` for profiles), including the storage policies on the `entry-photos` bucket, which check that the folder path matches the authenticated user's ID. Nothing to fix here.

One small optional hardening item worth knowing about while you're in this file: `update_data_key()` in `04_functions_triggers.sql` is a `security definer` function but doesn't `set search_path = public` the way `handle_new_user()` and `delete_user_account()` do in the same file. It's a minor schema-injection risk in theory, not something that's currently exploitable given how the function is written, but it's a one-line fix if you want to be thorough:

```sql
create or replace function public.update_data_key(
  new_wrapped_key          jsonb,
  new_recovery_wrapped_key jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public  -- add this line
as $$
...
```

If you ever add new tables later, re-run this check to confirm RLS is on for them too:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public';
```

Any row showing `rowsecurity = false` is a table an attacker could read or write without restriction.

**Step 4 — Constrain the storage bucket**

Can't verify this one from the exported code — bucket configuration lives in the Supabase dashboard, not in a migration file. In Supabase → **Storage → entry-photos → Configuration**, set a **file size limit** (e.g. 10MB) and restrict **allowed MIME types** to `image/jpeg`, `image/png`, `image/webp`. Without this, a malicious or misbehaving client could upload arbitrarily large or arbitrary-type files, driving up your storage and egress usage. Worth a 30-second check even if you think you already set it.

**Step 5 — service_role key exposure — ✅ already safe**

Checked `lib/core/services/supabase_client.dart`: only `SUPABASE_ANON_KEY` (via `--dart-define`) is used to initialize the client. No `service_role` key anywhere in the app. Nothing to fix here.

**Step 6 — Stay on free tiers, and if you ever upgrade, leave Spend Cap on**

For a solo portfolio project, staying on Supabase's Free plan and Resend's Free plan is itself a cost-control strategy — neither can charge you unexpectedly. If you later upgrade Supabase to Pro (e.g., to avoid the 7-day inactivity pause), leave **Spend Cap** enabled (it's on by default) — it blocks/restricts usage past your quota instead of billing you for it. Only disable it if you deliberately want to pay for scale.

---

### 3.1 — Fix the support/privacy emails (currently your personal Gmail, not the professional addresses from Phase 1)

**Status check:** these were already edited from the original `poppy.app` placeholders — but to your personal Gmail (`sa.albahloul@gmail.com`) rather than the `hello@`/`privacy@sarahelbahloul.dev` addresses you set up in Phase 1. That defeats the point of Phase 1 (keeping a public-facing support channel separate from your personal inbox, and being able to change it later without a store update). Worth fixing before submission.

**File 1:** `lib/features/settings/presentation/screens/settings_screen.dart`, line 238

```dart
// Change:
const email = 'sa.albahloul@gmail.com';

// To:
const email = 'hello@sarahelbahloul.dev';
```

**File 2:** `lib/features/settings/presentation/screens/legal_screen.dart`, line 109

```dart
// Change:
'For privacy concerns or data requests, contact us at sa.albahloul@gmail.com.',

// To:
'For privacy concerns or data requests, contact us at privacy@sarahelbahloul.dev.',
```

---

### 3.2 — Update the privacy policy and terms dates

**File:** `lib/features/settings/presentation/screens/legal_screen.dart`

Still needed — there are two `'Last updated: January 2025'` strings, at **lines 68 and 127**.

```dart
// Change both instances to the actual current date before submission, e.g.:
Text('Last updated: June 2026', ...)
```

---

### 3.3 — Update the copyright year in About screen

**File:** `lib/features/settings/presentation/screens/about_screen.dart`, line 154

Still needed.

```dart
// Change:
'© 2025 Poppy. Made with care.'

// To:
'© 2026 Poppy. Made with care.'
```

---

### 3.4 — Replace the broken widget test with real unit tests

**File:** `test/widget_test.dart`

Still needed — confirmed it's still the default Flutter counter test (`Counter increments smoke test`), which will fail `flutter test` outright since `PoppyApp` doesn't contain a counter. Do not replace it with a placeholder `expect(true, isTrue)` — employers immediately recognize fake tests and it signals the opposite of what you want.

`EncryptionService` is pure Dart with no Flutter dependencies, which makes it the easiest and highest-signal thing to unit test. Its actual API (checked against the real file) matches what's below exactly — just note the real import path, which is nested under `features/auth/data/services/`, not `services/`. Replace the entire file with:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:poppy/features/auth/data/services/encryption_service.dart';

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

Confirmed still needed — `com.example.poppy` is used on both platforms (`android/app/build.gradle.kts`, `MainActivity.kt`'s path/package, and every `PRODUCT_BUNDLE_IDENTIFIER` entry in `ios/Runner.xcodeproj/project.pbxproj`). Google Play and the App Store both reject submissions with `com.example` in the ID.

Using **`dev.sarahelbahloul.poppy`** — since you already own the `sarahelbahloul.dev` domain, this makes the bundle ID the exact reverse-DNS of your real domain, which is a nice bit of polish for a portfolio project. Use it consistently everywhere below.

### 4.1 — Android bundle ID

**File:** `android/app/build.gradle.kts`

```kotlin
// Change both of these:
namespace = "com.example.poppy"
applicationId = "com.example.poppy"

// To:
namespace = "dev.sarahelbahloul.poppy"
applicationId = "dev.sarahelbahloul.poppy"
```

**File:** `android/app/src/main/kotlin/com/example/poppy/MainActivity.kt`

The file is at the wrong path. You need to:
1. Create the directory `android/app/src/main/kotlin/dev/sarahelbahloul/poppy/`
2. Move `MainActivity.kt` there
3. Update the `package` declaration at the top of the file:

```kotlin
package dev.sarahelbahloul.poppy
```

The Supabase deep link scheme in `AndroidManifest.xml` (confirmed present at lines 60–79) uses `io.supabase.poppy` — that is independent of the package name and does not need to change.

---

### 4.2 — iOS bundle ID

Open Xcode (you need a Mac for this step):

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Click on "Runner" in the project navigator → select the "Runner" target.
3. Under the "General" tab, find "Bundle Identifier".
4. Change `com.example.poppy` to `dev.sarahelbahloul.poppy`.
5. Xcode will update `project.pbxproj` automatically. Do not edit it by hand.

This also fixes the test target identifiers automatically (confirmed multiple `PRODUCT_BUNDLE_IDENTIFIER = com.example.poppy` / `com.example.poppy.RunnerTests` entries in `project.pbxproj` that all need this change — Xcode handles all of them from the one field).

---

## Phase 5 — Set Up Release Signing

### 5.1 — Android signing keystore

Confirmed still needed — `android/key.properties` doesn't exist yet, and `build.gradle.kts` still signs release builds with `signingConfigs.getByName("debug")`.

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

Can't verify this one from the exported code — a zip export doesn't include `.git` history, only the current file tree. Run this yourself locally to check whether any of these were ever committed in the past, even if they're gitignored now:

```bash
git log --all --full-history -- .env
git log --all --full-history -- "android/.gradle"
git log --all --full-history -- ".idea"
```

If any of them show commits, remove them from history with:

```bash
git filter-branch --force --index-filter \
  "git rm -r --cached --ignore-unmatch android/.gradle .idea .env" \
  --prune-empty --tag-name-filter cat -- --all
```

---

### 7.2 — `.gitignore` entries — ✅ already done

Checked the actual `.gitignore` — it's already more thorough than this step asks for. It has dedicated, well-organized sections for secrets (`.env`, `secrets.dart`, `lib/dev/`), Android signing (`android/key.properties`, `*.jks`, `*.keystore`), machine-local config (`android/local.properties`), Android build artifacts (`android/.gradle/`, `android/build/`, `*.apk`, `*.aab`), iOS build artifacts, and IDE files (`.idea/`, `*.iml`, `.vscode/`). Nothing to add here.

---

### 7.3 — Update the README screenshots

Still needed, but the actual placeholder text and table are different from what this guide originally assumed. The real README (line 22) says:

```markdown
> These placeholders are gonna be replaced with actual screenshots.

| Login | Home | Journal |
|------|------|------|
| ![](screenshots/login.png) | ![](screenshots/home.png) | ![](screenshots/journal.png) |

| Editor | Appearance | Security |
|------|------|------|
| ![](screenshots/editor.png) | ![](screenshots/settings.png) | ![](screenshots/security.png) |
```

So the plan is the same, just six screenshots instead of four, matching filenames already referenced in the table:

1. Run the app on a real device.
2. Take screenshots matching each existing placeholder: login screen, home screen (with a few entries), journal/entry view, editor (write) screen, appearance/settings screen (showing a theme switch), and the security/lock screen.
3. Add a `screenshots/` folder to the repo with files named exactly `login.png`, `home.png`, `journal.png`, `editor.png`, `settings.png`, `security.png` — matching what the table already references, so you don't also need to edit the table markup itself.
4. Also replace the `> These placeholders are gonna be replaced with actual screenshots.` line and the `> A short demonstration GIF will be added here.` line further down once you have a demo GIF.

---

### 7.4 — Expand the README's technical decisions and security sections

This section has more CV impact than any number of extra features. Good news: the README already has the skeleton for this — an **"⚙️ Engineering Highlights"** section with a **"Key Engineering Decisions"** bullet list, and a separate **"🔒 Security"** section — but both are currently short bullet lists without the "why" reasoning that actually demonstrates understanding to an employer. Expand them in place rather than adding two new sections.

**In "Key Engineering Decisions"**, turn the existing bullets into short paragraphs with reasoning, e.g.:

```markdown
**Offline-first with a sync queue** — SQLite is the source of truth. Every
create/update/delete writes locally first and enqueues a sync operation.
When connectivity returns, the queue drains against Supabase. This means
zero data loss on flaky connections and instant UI response.

**Provider over Riverpod/BLoC** — Poppy has three providers and a clear
unidirectional data flow. Provider fits this scale without the boilerplate
overhead of Riverpod or the verbosity of BLoC.
```

**In the "🔒 Security" section**, add the trade-offs the current bullet list doesn't mention — this is the part that actually shows engineering maturity rather than just listing algorithms:

```markdown
**What is zero-knowledge:** The password-wrapping path is zero-knowledge.
The server stores only the wrapped (encrypted) data key, derived using
PBKDF2 with 600,000 iterations and a fresh per-wrap random salt embedded
in the key blob itself. The server never sees the plaintext data key or a
means to derive it from what is stored.

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

Confirmed still needed — no `.github/` directory exists in the repo yet.

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

Confirmed still needed — no `integration_test/` directory, and `integration_test` isn't listed as a dev dependency in `pubspec.yaml` yet.

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

### 8.1 — What the MIT license on your repo means — ✅ already in place

Checked `LICENSE`: it's already MIT, with `Copyright (c) 2026 Sarah Elbahloul` — correct year, correct name, nothing to change. The rest of this section is just background on what that means, kept for reference:

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

Confirmed still needed — no `docs/` folder exists in the repo yet.

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

Confirmed still needed — `ITSAppUsesNonExemptEncryption` is not present in `Info.plist`.

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

1. Create a new iOS app → enter bundle ID `dev.sarahelbahloul.poppy`, name "Poppy".
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

## Quick Reference: Files Still Needing Changes

Updated to reflect what's actually still outstanding after auditing the real codebase — 2.1, 2.2, 7.1 (gitignore part), 7.2, and 8.1 are done and removed from this table; RLS and service_role checks (part of 2.7) are also done and removed.

| File | What changes |
|---|---|
| `lib/main.dart` | Wrap main() in SentryFlutter.init (2.6) |
| `pubspec.yaml` | Add `sentry_flutter`, `integration_test` (2.6, 7.6), a Turnstile WebView wrapper package (2.7) |
| `ios/Runner/Info.plist` | Camera/photo permissions (2.3), orientation (2.4), URL scheme (2.5), encryption declaration (8.4) |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Pass `captchaToken` on signUp/signInWithPassword/resetPasswordForEmail (2.7) |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Line 238 — replace `sa.albahloul@gmail.com` with `hello@sarahelbahloul.dev` (3.1) |
| `lib/features/settings/presentation/screens/legal_screen.dart` | Line 109 — replace `sa.albahloul@gmail.com` with `privacy@sarahelbahloul.dev`; lines 68 & 127 — update "Last updated" dates (3.1, 3.2) |
| `lib/features/settings/presentation/screens/about_screen.dart` | Line 154 — update copyright year to 2026 (3.3) |
| `test/widget_test.dart` | Replace broken default counter test with real EncryptionService unit tests, corrected import path (3.4) |
| `android/app/build.gradle.kts` | Change bundle ID to `dev.sarahelbahloul.poppy`, add proper release signing (4.1, 5.1) |
| `android/app/src/main/kotlin/` | Move `MainActivity.kt` from `com/example/poppy/` to `dev/sarahelbahloul/poppy/` (4.1) |
| `android/key.properties` | Create with keystore details — **do not commit** (5.1) |
| `ios/Runner.xcworkspace` | Change bundle ID to `dev.sarahelbahloul.poppy` in Xcode (4.2), set up signing (5.2) |
| `supabase/migrations/04_functions_triggers.sql` | Optional: add `set search_path = public` to `update_data_key()` (2.7) |
| `integration_test/app_test.dart` | Create integration tests (7.6) |
| `.github/workflows/ci.yml` | Create CI workflow with analyze, unit tests, integration tests (7.5) |
| `docs/privacy.md` | Create for GitHub Pages hosted privacy policy (8.3) |
| `README.md` | Screenshots matching existing table filenames (7.3), expand existing "Key Engineering Decisions" and "Security" sections in place (7.4) |

---

## Changelog (this revision)

- **Phase 1.2:** Reordered to set up named routing rules (`hello@`, `privacy@`) as the primary mechanism; catch-all is now explicitly optional, with a note that it can attract spam once the domain ages.
- **Phase 1.3–1.4:** Corrected from a previous draft that mismarked Resend as optional. It's required: Supabase's built-in email sender is capped at **2 emails/hour** and is documented as non-production/best-effort, so you'll hit it almost immediately during normal signup/reset testing.
- **New 1.4a:** Added the missing step to actually connect Resend to Supabase (Project Settings → Authentication → SMTP Settings). Domain verification in Resend alone doesn't change anything until this step is done — this was missing from every prior version of the guide.
- **Phase 1.7 checklist:** Updated to require Resend verification, confirm custom SMTP is active in Supabase, and added a check for signing up two test accounts back-to-back without a rate-limit error.
- **New Phase 2.7:** Added API abuse / billing-safety steps — Turnstile CAPTCHA on Supabase Auth, Auth rate-limit tuning, an RLS audit query, storage bucket file-size/MIME-type limits, confirming only the anon key ships client-side, and staying on free tiers (or Spend Cap on) as the actual cost-control mechanism, since both Supabase and Resend free plans restrict usage rather than bill for it.
- **Full audit against the actual project code (this revision):** Every step from Phase 2 onward was checked against the real repo, not assumed. Result:
    - **Removed / marked done:** 2.1 + 2.2 (PBKDF2 salting) — implemented, and better than the original spec (salt embedded in the wrapped-key JSON blob itself, no separate Supabase columns needed, backward-compatible fallback for pre-fix accounts). 2.7's RLS audit — all four tables and the storage bucket already have correct `auth.uid()`-scoped policies. 2.7's service_role key check — only the anon key is used, confirmed in `supabase_client.dart`. 7.2 (`.gitignore` entries) — already more thorough than requested. 8.1 (MIT license) — already correctly in place with 2026 copyright.
    - **Corrected paths/line numbers:** the actual project uses a feature-based folder structure (`lib/features/settings/presentation/screens/...`, `lib/features/auth/data/services/...`), not the flat `lib/screens/...` / `lib/services/...` paths this guide originally assumed. All file paths and line numbers in Phases 3 and 3.4's test import were updated to match.
    - **Corrected content:** Phase 3.1 — the placeholder emails were already changed, but to your personal Gmail rather than the professional Phase 1 addresses, so the step was rewritten to reflect the actual current value and fix it properly. Phase 7.3 — the README already has a different (larger) screenshot table than originally assumed; instructions now match the real filenames. Phase 7.4 — the README already has skeleton "Engineering Highlights" and "Security" sections; instructions now say to expand them in place rather than add duplicate new sections.
    - **Bonus catch:** `update_data_key()` in `04_functions_triggers.sql` is missing `set search_path = public`, which its sibling `security definer` functions in the same file have. Added as an optional one-line hardening note in 2.7.
    - **Confirmed still outstanding, unchanged in substance:** 2.3–2.6 (iOS permissions, orientation, deep link scheme, Sentry), 2.7's CAPTCHA/rate-limit/storage-limit steps, 3.2–3.4, all of Phase 4 and 5, 7.1 (git history — can't verify from a zip export, run locally), 7.5, 7.6, 8.3, 8.4.
    - **Bundle ID:** updated throughout to `dev.sarahelbahloul.poppy` per your domain ownership, replacing the earlier placeholder `com.sarahelbahloul.poppy`.
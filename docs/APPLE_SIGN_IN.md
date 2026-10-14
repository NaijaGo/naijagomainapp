# Sign in with Apple — local implementation and release checklist

## Scope and current status

Customer app only, with matching backend support. Existing Google, password,
biometric login, customer navigation, orders, wallet and delivery flows are retained.
Login and registration display the package's Apple-branded button on iPhone/iPad.
Apple authorization requests name and email only. Creating a customer account does
not require a phone number or an invented name. Terms consent is explicit; delivery
addresses/contact details remain part of the existing order flow.

Version is **1.0.28+66**, retaining the GitHub version name and increasing the build
number as requested. The supplied rejection names 10.23 (65), which differs from the
repository's version. Before uploading, confirm the actual version of the selected
App Store Connect draft matches the IPA's `CFBundleShortVersionString`. Do not silently
rename the app version or attempt to create a lower store version.

No production deployment, Apple submission, database initialization, migration or real
Apple-account test was performed. Apple Developer settings and signing are not verified.

## Backend behavior

- `POST /api/auth/apple/challenge`: five-minute, random, server-issued nonce/challenge,
  bound to the device fingerprint hash. Rate limited; no-store responses.
- `POST /api/auth/apple`: checks Apple RSA signature against the fixed official JWKS
  endpoint, exact issuer/audience, subject, expiry/issuance and nonce. The unverified
  token cannot choose a key URL or account email. No tokens or secrets are logged.
- Existing Apple subjects are resolved through `appleidentities` to the actual User.
  New subjects with an existing verified email require the existing NaijaGo password
  to link. There is no email-only automatic merge or client-controlled role.
- New users use verified token email (including private relay), an unguessable internal
  password, ordinary customer role and optional cosmetic name. Marketing preferences
  default off for new Apple accounts. Vendor/admin profile validation remains strict.
- Nonce consumption, User creation/linking and unique identity creation commit together
  in a MongoDB transaction. Successful requests consume the nonce; replay fails. Profile
  and password-link prompts leave the challenge usable until its expiry. Expired or
  uncertain client outcomes require fresh authorization; no automatic POST retry.
- Existing JWT format/lifetime is retained. App logout clears the NaijaGo session;
  provider tokens are not stored in Flutter. Apple sessions do not upload email/name
  or purchase/advertising tags to OneSignal; its external user ID supports order alerts.
- Account deletion also removes only that User's Apple association. Published provider
  consent is not revoked by this local JWT-verification implementation. No Apple
  refresh tokens, authorization-code exchange or server-to-server revocation handler
  is included; withdrawing Apple permission does not immediately revoke an already
  issued NaijaGo JWT. Existing sessions expire normally or fail when the User is deleted.
  This limitation must be considered before production rollout.

## Explicit database setup — not executed

MongoDB **5+ replica set/sharded transaction support** is required. New collections
`appleidentities` and `appleauthchallenges` disable automatic collection/index creation.
The identity `_id` uniquely represents the stable Apple subject. Challenges have a TTL
index `apple_challenge_expiry` on `expiresAt`. Backend readiness requires these indexes,
unique email protection and a partial unique phone index.

The old unique phone index permits only one missing phone value. The replacement,
`user_phone_string_unique`, uniquely protects every populated string phone number while
allowing multiple customers without one. The schema marks this index `_autoIndex:false`;
the actual Mongoose automatic initialization is tested to skip it. Startup does not
run the setup script. Existing index/data are not silently changed by this work.
For fresh databases, new populated-phone accounts and phone changes refuse to save
without safe unique protection; neither missing setup nor the model change permits
duplicate-phone registration. Existing safe legacy phone indexes continue to qualify.

The initializer performs replica/version, duplicate and index-conflict checks before
writes; duplicate values are never printed or merged. It creates replacement uniqueness
before dropping the legacy phone index. User data is never rewritten. A failure can
leave partial additive setup: inspect indexes before rerunning, and leave Apple disabled.

Use an explicitly chosen disposable staging connection in `APPLE_AUTH_SETUP_MONGO_URI`.
The script does not read the app's `MONGO_URI` or `.env`. First review the read-only plan:

```powershell
node scripts/setupAppleAuth.js --database=naijago_apple_staging
```

Only after separate approval of that plan, backups and database identity:

```powershell
node scripts/setupAppleAuth.js --database=naijago_apple_staging --apply --confirm-database=naijago_apple_staging --replace-phone-index
```

Production setup requires its own explicit approval. Do not point this task's test
commands at production. Set the backend `APPLE_CUSTOMER_CLIENT_ID` to the exact native
bundle ID **com.naijago.naijaGo** only after approved setup. Missing configuration or
unsafe/missing indexes fail closed; the normal login methods remain available.
Identity-token verification uses public Apple keys, so no `.p8` private key or Apple
client secret is required for the implemented native verification endpoint.

### Rollback

Unset `APPLE_CUSTOMER_CLIENT_ID` to disable new Apple authorizations. Preserve identity
records and the new User validation/index compatibility after customers have signed up.
Do not roll back to the old required-phone/name schema once Apple customers exist.
Recreating the old non-partial phone index can fail with multiple missing phones; it
requires a separately approved data/index plan. Never delete accounts or invent phone
numbers to force rollback. Existing populated phone uniqueness remains enforced.

## Apple Developer / Codemagic from Windows

1. Apple Developer → Certificates, Identifiers & Profiles → Identifiers: select the
   exact App ID **com.naijago.naijaGo**, enable **Sign in with Apple**, configure it as
   the primary App ID unless you intentionally use an existing grouped identity, and save.
2. Regenerate/download the App Store provisioning profile with that capability. In
   Codemagic's signing identities, upload/fetch the new profile and match the existing
   distribution certificate/private key. The existing `naijago_mainapp_key` App Store
   Connect integration is retained; do not substitute the rider integration/key.
3. The repository adds `com.apple.developer.applesignin = [Default]` to Runner.entitlements.
   Debug/Profile/Release already reference that file; bundle ID and iOS 15 deployment
   target are retained. Automatic `ios_signing` / `xcode-project use-profiles` remain.
4. Codemagic is pinned to **Flutter 3.47.6**, matching local checks. The prior 3.32.8
   setting was already below the existing lockfile's SDK requirements. Apple package
   **8.2.0** requires Dart 3.12 / Flutter 3.44+, reflected in pubspec/lockfile. Google
   package versions are unchanged. No dependency overrides or broad upgrade was performed.
5. Configure Apple's private email relay with the actual sending domain/address,
   including `noreply@naijagoapp.com`, and verify your Resend DNS/SPF setup. No guessed
   DNS records were added. Native iOS authorization does not require an Android/web
   Services ID, browser callback or an Apple secret embedded in the app.
6. After separate deployment/setup approval, deploy the backend and run the configured
   iOS Release workflow. Current CI publishing settings already upload to TestFlight;
   running that workflow is a publishing action and has not been done in this task.
7. Verify on both iPhone and iPad: first sign-in with Hide My Email; repeat sign-in
   without name; cancellation; signup/terms; explicit linking; logout/restore; wrong
   credentials; and existing Google/password paths. Also verify profile, delivery
   address/phone entry, checkout, wallet, notifications and account deletion with test data.
8. Confirm build 66 and the intended store version, update Review Notes and demo
   credentials in App Store Connect, select the verified build, then manually resubmit.
   No claim is made that Apple will approve it or that device sign-in has been tested.

## Guideline 2.1 demo access

Source inspection found both verified-email and new-device-email gates. The rejection
does not identify which failed, and no demo account email/ID or live account was provided.
The real review account is therefore **not verified as working**.

Optional exception, disabled unless BOTH backend variables are configured:

- `APP_REVIEW_CUSTOMER_ID`: one exact 24-character User ID, ordinary customer only.
- `APP_REVIEW_ACCESS_EXPIRES_AT`: UTC ISO timestamp within the next seven days.

Create/choose a dedicated non-admin/non-vendor customer through the normal process,
verify its email normally, set a strong unique password of at least 12 characters and
put those credentials only in App Store Connect. No password is committed or requested
in chat. Confirm its ID and authorize the bounded environment setting separately.

For that verified account, AFTER correct password validation, device-email verification
can be skipped during the window. The reviewer's device is not permanently trusted;
verification flags are unchanged. The resulting JWT expires within one hour (or sooner
at the configured expiry); normal protected routes recheck the setting so removing it
revokes this exception immediately. Other accounts and Google login are unaffected.
Wrong passwords, unverified email, privileged accounts and expired/missing configuration
do not qualify. There is no fixed OTP, hidden button or universal login credential.

Test these credentials from a fresh device before resubmitting. If the account's email
is unverified, complete normal verification; this exception does not bypass it. Remove
both variables after review. No settings/account records were changed in production.

## Primary references

- [Apple identity verification](https://developer.apple.com/documentation/signinwithapple/verifying-a-user)
- [Apple authentication and nonce guidance](https://developer.apple.com/documentation/signinwithapple/authenticating-users-with-sign-in-with-apple)
- [Apple private email relay setup](https://developer.apple.com/help/account/configure-app-capabilities/configure-private-email-relay-service/)
- [Sign in with Apple package and requirements](https://pub.dev/packages/sign_in_with_apple/versions/8.2.0)
- [App Review demo-account requirements](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/)

## Actual local checks — 14 October 2026

| Check | Observed result |
| --- | --- |
| Backend full suite, final source | 639 total: 631 passed, 8 skipped, 0 failed |
| Focused Apple/review/Google backend run | 75 passed, 0 failed |
| Customer Flutter full suite | 260 passed, 0 failed |
| Auth file analysis | No issues in the new/modified authentication files and Apple tests |
| Full `flutter analyze --no-pub` | Exit 1: 4 warnings and 31 informational notices, all in unchanged files; no errors |
| Android `flutter build apk --debug --no-pub` | Passed; debug APK metadata independently reads versionName 1.0.28 / versionCode 66 |
| JavaScript syntax / final diff whitespace | Passed |
| iOS archive, signing, real Apple sign-in, review account, relay email | Not verified locally |

All authentication tests use generated test RSA keys, mocked Apple keys and in-memory
fixtures/local HTTP servers. No real Apple identity, live account, provider charge or
database was used. Eight existing backend integration tests need a dedicated real
MongoDB: Deals, Google persistence, Image Studio integration/setup/API, inventory,
legacy settlement and planned-order lifecycle. Their absence leaves actual MongoDB
transactions, index compatibility and production concurrency unverified; stage these
before production approval. App tests retain the existing Google tests.

Initial failures were fixed: a missing-expiry test token was incorrectly constructed,
the new screen checks exposed existing footer-row overflow, and iOS platform overrides
in tests needed restoration before framework invariant checks. An automatic-index test
initially queued on a disconnected Mongoose collection; it was stopped and corrected
to use native collection metadata/method mocks. No database connection occurred. Final
runs pass; no existing tests or assertions were removed.

The full analyzer findings and Android Gradle/Kotlin/SDK metadata warnings remain.
No unrelated lint cleanup or Android dependency upgrade was performed. The changed-file
set was compared with analyzer paths: zero findings overlap changed files. Flutter's
automatic unrelated analyzer-config and Linux/Windows line-ending changes were restored.
No secrets, production connection settings, existing dependency versions or other app repositories
were changed. Only the Apple dependency trio was added; the generated macOS registration
for that plugin is kept consistent with the dependency.

## Complete changed-file inventory

Paths are relative to the named repository. These changes are local and uncommitted;
no GitHub push, Render deployment, Codemagic build or App Store submission was performed.

### `naijago_backend`

| File | Change |
| --- | --- |
| `models/User.js` | Additive Apple subject; optional Apple-customer names/phone; guarded manual unique-phone index; safe phone-save validation |
| `models/AppleIdentity.js` | New stable-subject mapping with native unique primary key; automatic setup disabled |
| `models/AppleAuthChallenge.js` | New one-time nonce state and TTL declaration; automatic setup disabled |
| `services/appleIdentityService.js` | Apple signature/claims verifier and bounded fixed-origin key cache |
| `services/appleAuthService.js` | Transactional creation/linking, nonce consumption and storage readiness |
| `routes/appleAuthRoutes.js` | New challenge/authentication endpoints and existing-format sessions |
| `routes/authRoutes.js` | Mount Apple endpoint, remove identity on account deletion, narrowly scoped demo-device exception |
| `services/appReviewAccessService.js` | Disabled-by-default one-account, expiring review-session policy |
| `middleware/authMiddleware.js` | Revalidate bounded demo-session authorization on protected requests |
| `scripts/setupAppleAuth.js` | Explicit dry-run-first setup/index-replacement plan; no startup import |
| `test/appleAuth.test.js` | Real RSA/claims checks and mocked account/nonce/index/migration regressions |
| `test/appReviewAccess.test.js` | Actual mocked login/protected-route and policy-window tests |

### `naijagomainapp`

| File | Change |
| --- | --- |
| `pubspec.yaml` | Build 66, Apple package 8.2.0 and compatible Dart minimum |
| `pubspec.lock` | Add Apple package/platform interface/web dependency; retain existing dependency versions |
| `codemagic.yaml` | Align Flutter pin with the tested SDK and required dependencies |
| `ios/Runner/Runner.entitlements` | Sign in with Apple entitlement; existing entitlements retained |
| `macos/Flutter/GeneratedPluginRegistrant.swift` | Generated registration for the new Apple dependency |
| `lib/services/apple_auth_service.dart` | Native iOS authorization and cancellation/error handling |
| `lib/services/apple_customer_session.dart` | Existing session storage, password clearing, privacy-conscious push identity and logout |
| `lib/auth/screens/apple_login_screen.dart` | Authoritative server challenge/authentication, optional profile/terms and explicit password linking |
| `lib/auth/screens/login_screen.dart` | Visible Apple button, session integration, registration callback and responsive footer |
| `lib/auth/screens/registration_screen.dart` | Visible Apple button/callback and responsive footer; existing form retained |
| `lib/main.dart` | Registration/session callback, Apple privacy handling and session logout |
| `test/apple_auth_test.dart` | Mocked auth/session/logout/nonce/UI/capability/CI tests |
| `docs/APPLE_SIGN_IN.md` | This report and operator/review/resubmission instructions |

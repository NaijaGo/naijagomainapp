# Customer Google sign-in setup

This repository includes the Google sign-in implementation. Public OAuth client IDs have been supplied; live console configuration and physical-device verification remain required.

1. Register Android OAuth clients for com.naijago.naija_go and the debug/release/Play app-signing SHA-1 certificates as applicable.
2. Create a Web OAuth client; configure the backend public GOOGLE_CUSTOMER_CLIENT_ID variable with its client ID.
3. For the visual Codemagic workflow editor, add GOOGLE_SERVER_CLIENT_ID in the workflow Environment variables and append --dart-define=GOOGLE_SERVER_CLIENT_ID=$GOOGLE_SERVER_CLIENT_ID to the Android/iOS build arguments. Preserve existing arguments. For YAML workflows, the checked-in public OAuth variables and existing build commands provide the IDs directly. No client secret is needed.
4. For iPhone, create an iOS OAuth client for com.naijago.naijaGo, and add its public ID as GOOGLE_IOS_CLIENT_ID in the same workflow Environment variables. The existing CI build invokes tool/configure_google_sign_in.dart to derive the callback scheme. Local Mac builds must run that tool and pass both public IDs via Dart defines.
5. Test existing-account linking (existing NaijaGo password required once), signup/onboarding, approval gates, new-device email verification, cancellation, retry and logout before release.

Google plugin versions support the existing CI Flutter pins. Flutter/Gradle/Kotlin/AGP were not upgraded in this app. The local Android debug APK builds successfully. CocoaPods/iOS runtime verification requires Mac/Xcode.

New vendors use the existing approval application. Riders must provide their existing registration/document requirements and await Admin approval. Email/password login remains available.

Before App Store submission, assess Apple's guideline 4.8 and provide an equivalent privacy-preserving login option where required. Sign in with Apple is outside this Google-only implementation.

Detailed API, index and security documentation: backend docs/GOOGLE_SIGN_IN.md.

## Visual workflow editor

Add --dart-define=GOOGLE_IOS_CLIENT_ID=$GOOGLE_IOS_CLIENT_ID to iOS build arguments. The optional same define on Android is harmless; Android uses the Web server ID.

Add dart run tool/configure_google_sign_in.dart to the Pre-build script, from the repository root ($CM_BUILD_DIR). Post-build and Pre-publish run too late. Preserve other setup commands.

The visual editor and codemagic.yaml are separate workflow configurations. A change to one is not evidence that the other was saved or used. YAML-triggered builds must use the checked-in YAML configuration.

The public OAuth IDs are in codemagic.yaml. They do not contain Google client secrets. Render configuration still uses the matching Web audience separately.

Before building a Play release, use the existing upload keystore and register the Play app-signing certificate SHA-1 for this package in Google Cloud. Test on Play internal testing before production rollout.

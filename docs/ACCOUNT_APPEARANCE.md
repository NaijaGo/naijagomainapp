# Account appearance

The customer Account page uses a white background, centred profile photo or initials, grouped flat rows and thin dividers inspired by the supplied reference. Existing titles, subtitles, contact details, balance wording and destinations are retained. The Account app-bar title is centred.

No coupons, balances or account settings are invented. The existing Dark Mode Toggle still displays its original coming-soon message. Optional tools still follow backend configuration. Logout and deletion keep their existing handlers and confirmation.

## Local checks

Run `flutter test test/account_appearance_test.dart`. The eleven tests use fictional profile data and local HTTP and platform mocks. They cover original wording, profile presentation, feature gates, wallet and edit-profile navigation, dark-mode messaging, logout, deletion cancellation and a 320-pixel screen at 1.6 text scale. No payment or account deletion is performed.

Optional environment variables `NAIJAGO_ACCOUNT_PREVIEW_DIR` and `NAIJAGO_ACCOUNT_FONT_DIR` render a local preview of the actual Account widget. The preview uses a simple test app-bar wrapper and fictional data; it is not a screenshot of a live customer session.

Device and store-build verification remains necessary after deployment.

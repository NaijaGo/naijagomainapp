# Pharmacy chat release

The chat redesign and message recovery changes require the updated naijago_backend before distributing this app build. See [backend release notes](https://github.com/NaijaGo/naijago_backend/blob/main/docs/PHARMACY_CHAT_RELEASE.md) for the full rollout and two-account device checks.

Local verification: 189 full-suite tests passed, including 24 chat tests. Targeted analysis of the changed chat code and tests reports no issues. No real messages were sent. Live deployment and device verification remain separate steps.

Run locally:

- flutter test --no-pub
- flutter test --no-pub test/pharmacy_chat_test.dart

Own messages appear on the right. Sent means stored by the backend. Retry retains the same message identity while the screen remains open.

# Customer app naira formatting audit

16 October 2026. Scope: `naijagomainapp` only.

## Implementation

The existing [`intl` NumberFormat](https://api.flutter.dev/flutter/package-intl_intl/NumberFormat-class.html)
dependency is reused. Currency implementations previously
scattered across screens now delegate to `formatNaira` in
[`lib/core/formatters/naira.dart`](../lib/core/formatters/naira.dart).
The existing public `formatDealPrice` helper delegates to it too.

- Explicit Nigerian locale, naira symbol and comma grouping.
- Whole amounts use `₦500`, `₦1,500`, `₦10,000`, `₦150,000` and `₦1,000,000`.
- Fractional amounts use two kobo places, e.g. `₦1,250.50`.
- Screens that previously showed two decimals keep them, including wallet,
  account, product cards/details, cart, checkout and order summaries.
- Restaurant cards and pharmacy plan/balance displays now retain fractional
  amounts if present, instead of rounding away kobo.
- Numeric strings and already grouped/naira-prefixed strings are normalized
  once. Invalid/nonfinite/missing values display `—`; existing explicit
  `?? 0` display fallbacks are retained.
- Negative amounts keep their sign. Formatting is applied only at display
  boundaries. Numeric prices, multiplication, financial API payloads, wallet/payment
  decisions, discounts and refund calculations are unchanged.

No dependency, backend, database or gateway configuration was changed. After
verification, the customer app build number was increased from `1.0.28+66` to
`1.0.28+67` in `pubspec.yaml` at the user's request for the GitHub submission.

## Files changed and screens covered

All paths below are relative to the customer app.

| Changed source | Monetary display covered |
|---|---|
| `lib/core/formatters/naira.dart` (new) | Shared formatter |
| `lib/screens/Main/home_screen.dart` | Shared `ProductCard`: home, featured/flash-sale/new-arrival sections, vendor listings and search results |
| `lib/screens/Main/category_products_screen.dart` | Category/subcategory product cards; all category routes use this screen |
| `lib/screens/Main/restaurant_food_screen.dart` | Food/vendor product cards |
| `lib/screens/Main/product_detail_screen.dart` | Product price and recommended product cards |
| `lib/screens/Main/saved_items_screen.dart` | Saved product prices |
| `lib/screens/Main/write_review_screen.dart` | Reviewed product price |
| `lib/widgets/deal_card.dart` | Original prices, final/sale prices and fixed-amount discount badges; percentage badges remain percentages |
| `lib/screens/Main/cart_screen.dart` | Cart items, total and recently viewed products |
| `lib/screens/Main/checkout_screen.dart` | Subtotals, delivery/pickup fees, base/distance fees, tax, totals, wallet balance and delivery savings |
| `lib/screens/Main/account_screen.dart` | Both wallet balance displays |
| `lib/screens/Main/my_wallet_screen.dart` | Wallet balance |
| `lib/screens/Main/withdrawal_screen.dart` | Maximum withdrawal amount in validation feedback |
| `lib/screens/Main/my_orders_screen.dart` | Order summary, delivery/tax/total, item unit and quantity-multiplied prices |
| `lib/screens/Main/pickup_orders_screen.dart` | Pickup item prices, including numeric string values |
| `lib/screens/Main/planned_orders_screen.dart` | Current quote total, product subtotal and delivery charge |
| `lib/screens/Main/referral_screen.dart` | Referral reward, total earned and reward activity |
| `lib/screens/Main/subscription_screen.dart` | Monthly price, minimum order, activation label and wallet summary |
| `lib/screens/Main/chat_screen.dart` | Pharmacy consultation plans and wallet balance |
| `lib/screens/Main/shopping_assistant_screen.dart` | Budget examples, maximum suggested price and shared product cards |
| `lib/screens/Main/create_dispute_screen.dart` | Order total in the selection label |

Tests and report:

- `test/naira_formatter_test.dart` (new): requested amounts, zero, kobo,
  display rounding, fixed decimal policy, numeric/formatted strings, negatives,
  invalid values, locale independence and unchanged calculation inputs.
- `test/account_appearance_test.dart`: expects comma-grouped wallet balances.
- `test/customer_ui_premium_test.dart`: product-card checks for `₦1,500.00`,
  `₦150,000.50` and `₦1,000,000.00`, including unchanged cart totals.
- `docs/NAIRA_FORMATTING_AUDIT.md` (this report).
- `pubspec.yaml`: subsequent release metadata change, build 67.

## Audit method and scope limits

Searched the entire customer Dart source for currency symbols/codes, monetary
field names, `NumberFormat`, local formatting helpers, direct interpolation,
`toStringAsFixed`, and numeric text displays. Reviewed the matches and traced
shared product/category/deal widgets to their callers. Native/tool Dart files
were also checked for currency displays. Reviewed the diffs for display-only
changes. This is a source audit plus automated tests, not a manual walkthrough
of every screen on a physical device.

No remaining **structured, read-only monetary display** bypassing the shared
formatter was found. Remaining raw numeric/text occurrences are:

- Editable top-up, withdrawal and minimum/maximum budget fields. These retain
  numeric input and their existing currency labels/prefixes so their existing
  parsing and submitted amounts stay intact. No grouping input formatter was
  added.
- Payment SDK amounts, query/API values and calculations. These must remain
  numbers or ungrouped machine-readable numeric strings.
- Quantities, percentages, ratings, dates, phone/order IDs, coordinates and
  distances, which are not currency.
- Developer diagnostics and the inactive, commented-out historical ProductCard
  implementation in `home_screen.dart`.
- Free-text notifications, chat messages, vendor descriptions, captions and
  text embedded in images. These are not structured monetary fields and are
  not rewritten, to avoid altering customer/vendor content or numeric IDs.

`MyWalletScreen` currently exposes transaction history through a **"coming
soon"** message; there is no implemented transaction/deposit/withdrawal history
list with amounts to format. The tracking widget itself displays status and
location, not monetary values; the surrounding order summary uses the shared
formatter. Explore/product-request links open the updated product detail page.

## Verification

The standalone formatter run passed all 13 tests. The final full-suite run
passed **276 tests**, including the account/wallet, checkout, category, deal,
shopping assistant, pharmacy, payment-state and product/cart checks.

The first full-suite attempt exposed a compile error in a newly added test
fixture (a const map with double keys). The fixture was corrected and the full
suite rerun successfully. This did not require an application logic change.

`flutter analyze --no-pub` completed with **0 errors, 4 warnings and 31
informational lints**. Comparing severity, diagnostic text, source path and lint
code against the baseline (ignoring shifted line numbers) found **no added or
resolved diagnostics**. The command exits 1 because these existing diagnostics
remain; this is not a clean-analysis claim.

`git diff --check` passed. The final source search found currency constructors
only in the shared helper; remaining active direct naira interpolation is
developer logging in checkout/order screens. No structured, read-only monetary
UI bypass was found. Editable inputs and free text have the exclusions above.

Logs are available locally under `.dart_tool/naira-formatter-tests.log`,
`.dart_tool/naira-all-tests-final.log`, `.dart_tool/naira-analysis-before.log`
and `.dart_tool/naira-analysis-after.log` (ignored build/tool artifacts).

Commands:

```powershell
flutter test --no-pub test/naira_formatter_test.dart --reporter expanded
flutter test --no-pub --concurrency=2 --reporter expanded
flutter analyze --no-pub
git diff --check
```

Baseline analysis before the screen changes reported 35 existing diagnostics:
4 warnings and 31 informational lints, with no errors. Unrelated lint cleanup
is outside this change.

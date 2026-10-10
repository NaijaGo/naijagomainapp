# Shopping Assistant and home branding

## Customer app changes

- The home title uses blue (#0000FE) for Naija and green (#008953) for Go, sampled from the existing assets/naijago-brand.jpg logo.
- Shopping Assistant appears directly below the home search area, before the service shortcuts.
- Its card has an explicit Shopping Assistant label, a shopping bag and sparkle mark, and an Open assistant action. The whole card opens the existing assistant screen.
- The assistant screen uses the same visual identity and a branded Find options button.
- Search, suggestions, product selection, cart, checkout and payment behavior were not changed in this design pass.

## Local verification

- Full customer app suite: 152 tests passed.
- Assistant and branding subset: 27 tests passed.
- Five new branding checks cover wordmark colours, assistant identity, card actions, narrow screens with larger text and a rendered component preview.
- Changed-file Dart analysis: no errors or warnings; seven existing informational notices remain in home_screen.dart.
- The preview shows the actual wordmark and assistant widgets in a sample layout, not the complete live home screen.

## Release

These changes are local. Commit and push the intended customer app changes, then create a new Codemagic customer app build. Review the installed iOS/Android screens before publishing. No store release or production deployment was performed for this design pass.

## Optional preview generation

Set NAIJAGO_BRAND_PREVIEW_DIR to a local output directory and NAIJAGO_BRAND_FONT_DIR to Flutter's bin/cache/artifacts/material_fonts directory, then run:

```powershell
flutter test --no-pub test/shopping_assistant_branding_test.dart
```

The test writes naijago-assistant-brand-preview.png. The optional font loading affects only the test preview.

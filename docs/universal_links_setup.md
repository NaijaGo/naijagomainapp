# NaijaGo Universal Link Setup

The app now shares referral links in this format:

`https://naijagoapp.com/signup?ref=REFERRALCODE`

## App-side identifiers

- Android package: `com.naijago.naija_go`
- iOS bundle ID: `com.naijago.naijaGo`

## Android

The app is configured to accept:

- `https://naijagoapp.com/signup?...`
- `https://www.naijagoapp.com/signup?...`

Host this file at:

- `https://naijagoapp.com/.well-known/assetlinks.json`
- `https://www.naijagoapp.com/.well-known/assetlinks.json`

Use this JSON:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.naijago.naija_go",
      "sha256_cert_fingerprints": [
        "82:0C:58:D6:BF:74:C1:F1:B1:C6:2C:F9:17:2F:1E:FF:D7:A5:83:2A:CE:AF:2D:96:94:B5:0B:4E:0F:5C:63:85"
      ]
    }
  }
]
```

Important:

- If you use Google Play App Signing, replace the fingerprint above with the Play signing certificate fingerprint from Play Console.
- The file must be served directly from the domain, not behind a redirect page.

## iPhone

The app is configured with the Associated Domains entitlement for:

- `applinks:naijagoapp.com`
- `applinks:www.naijagoapp.com`

Host this file at:

- `https://naijagoapp.com/.well-known/apple-app-site-association`
- `https://www.naijagoapp.com/.well-known/apple-app-site-association`

Use this JSON:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["9M78583J9Z.com.naijago.naijaGo"],
        "components": [
          {
            "/": "/signup*"
          }
        ]
      }
    ]
  }
}
```

Notes:

- Serve the file as `application/json`.
- Do not add a `.json` extension to `apple-app-site-association`.
- The file must be available over HTTPS.

## Namecheap note

Namecheap domain forwarding alone is not enough for universal links or Android App Links.

You need the domain to serve the `.well-known` files above from real hosting. That can be:

- Namecheap hosting
- Vercel
- Netlify
- Cloudflare Pages
- another HTTPS host

If `naijagoapp.com` only redirects somewhere else, browser taps will not reliably open the app.

## Test URLs

- `https://naijagoapp.com/signup?ref=TEST123`
- `https://www.naijagoapp.com/signup?ref=TEST123`

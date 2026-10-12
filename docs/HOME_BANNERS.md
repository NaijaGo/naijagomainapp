# Home promotion and entrance update

## Behaviour

- Entrance: soft blue/white gradient, centred original NaijaGo identity, original wording. Skip, Continue and the existing ten-second startup completion remain idempotent.
- Shared customer theme: muted blue (#365D9B) for primary actions, deep slate navy (#1D2D47), white cards and soft blue-grey accents. The original logo retains its exact blue/green identity. Existing colour-token aliases resolve to the muted palette across customer screens; semantic status colours are preserved.
- Main carousel: 2.6:1 wide artwork, complete slide width. Existing carousel destinations and Low Cost World entry remain.
- Low Cost World stays first in the main carousel. Both its main slide and separate store-entry banner have 16 px side margins and a 2.6:1 shape (358 x 137.7 logical pixels on a 390 px phone). The width was expanded in the Home revision; height was not increased. Shimmer and shadows are subdued in the calm-blue refinement.
- Restaurant photo banner: original image URLs from loaded public restaurant products; rotates every six seconds, respects reduced-motion settings, supports swiping and opening that restaurant menu. Inactive, sold-out, temporarily closed, duplicate and photo-less rows are excluded. Pull-to-refresh reloads the menu; this is not a real-time inventory subscription.
- AI: compact labelled side button opens the same Shopping Assistant. The large Home assistant card and floating side cart are removed. The existing Cart tab and product/cart operations remain.
- Deals: Home displays only the promotional banner. No Deals API request is made until the banner opens the existing paginated Deals screen. Existing deal eligibility, pricing, inventory and checkout logic remain.

## Replace Deals artwork in admin

After deploying the backend/admin updates and building the updated customer app:

1. Admin -> Carousel Slides -> Promo Carousel.
2. Add/upload your replacement image, preferably 1300 x 500 px (2.6:1).
3. Click Action: Open NaijaGo Deals. Leave Action Value empty.
4. Enable the slide and save. Lowest Sort Order active Deals promo slide supplies the dedicated banner.
5. Refresh the customer Home screen. Disable/delete all Deals promo slides to restore the built-in banner.

Deals slides are not duplicated in the ordinary lower promo carousel. Existing main/promo records and other click actions remain supported. Older app builds do not understand the new optional Deals action, so install the updated build to use it. No records were created in a database for this update.

## Assets

Built-in image_gen tool used, without modifying the original JPEG logo or any vendor photos:

- assets/naijago-deals-banner.png: illustrative marketing artwork, not a listing or inventory claim.
- assets/naijago-logo-transparent.png: separate transparent version of the original branding for the entrance.

### Initial banner prompt (superseded by blue edit below)

Use case: ads-marketing. Create a finished ultra-wide NaijaGo Deals promotional banner for a customer shopping app, composition approximately 2.6:1. Input image 1 is the exact NaijaGo brand logo reference: preserve the shopping-bag mark and NaijaGo spelling and its blue/green brand colours. Inputs 2, 3 and 4 are composition references only: glossy, polished retail campaign banner, left headline and right tasteful product arrangement, generous safe margins, wide horizontal framing. Do NOT copy their brands, foreign text, offers or designs. NaijaGo palette is deep forest green #103D25, green #215C36, cream #F7F8F2 with restrained warm gold highlights and original blue/green logo. Show an elegant small pedestal with generic unbranded smartphone, earbuds, fashion bag and skincare packaging to the right, as illustrative shopping categories. Place exact NaijaGo logo and large readable heading 'NaijaGo Deals' to the left, smaller copy 'Discover your next great find', and a clear 'Browse deals' button. No numeric discounts, prices, shipping claims, deadlines, authenticity claims, watermark or third-party brands. Clean premium photographic advertising lighting, subtle celebratory sparkle, minimal clutter. This is a marketing banner only, not a real product listing. Maintain legibility at 360px-wide mobile display and all important artwork within central safe bounds.

### Final logo prompt

Make a clean transparent logo cutout using image 1 as the authoritative exact original NaijaGo brand. Image 2 is a rejected cutout with ragged holes and speckles: fix these alpha artifacts. Preserve image 1's exact blue bag shape, white NGo lettering, exact NaijaGo wordmark, original proportions and colours. Blue areas and green letters must be fully solid and smoothly antialiased, with NO missing interior pixels, ragged outlines, dark outlines, noise, scratches, texture, distressed finish or shadows. Remove all exterior white background; do not remove the white NGo text inside the blue bag. Crisp flat logo, genuine transparency, tight horizontal composition with small transparent padding, not a mockup. Do not redesign or add any elements.

### Blue banner edit prompt (superseded by calm edit below)

Built-in image_gen edit; saved to `assets/naijago-deals-banner.png` as the requested replacement.

Use case: style-transfer. Edit target image 1 is the existing NaijaGo Deals mobile advertising banner. Change its green campaign palette to a polished NaijaGo royal-blue campaign palette (#0000FE primary, #101A58 midnight blue, #EAF0FF pale blue), with restrained warm gold details and clean studio lighting. Recolour green backdrop, green podium and green shopping bag into harmonious royal/midnight blue, remove leafy decorative foliage for a cleaner professional presentation. Recolour the phone screen into a blue gradient. Preserve the wide 2.6:1 composition, exact product arrangement, and all readable copy: 'NaijaGo Deals', 'Discover your next great find', 'Browse deals'. Preserve the exact original blue-and-green NaijaGo logo identity at top left; that logo is the only green brand element to keep. Keep ample margins, clear white/gold headline contrast and unbranded generic product illustrations. No prices, discounts, shipping claims, added text or watermark. Intended for small mobile displays.

### Calm-blue banner edit prompt (current artwork)

Built-in image_gen edit; saved to `assets/naijago-deals-banner.png` as the requested replacement.

Use case: style-transfer. Edit this NaijaGo Deals banner to feel calm, understated and professional. Keep the original NaijaGo blue/green logo, every product, exact copy 'NaijaGo Deals', 'Discover your next great find', 'Browse deals', and wide 2.6:1 layout. Replace intense electric royal blue with muted slate-blue #365D9B, deep navy #1D2D47 and soft blue-grey accents. Use a smooth uncluttered matte backdrop and softly lit podium. Reduce saturation of the blue phone screen. Remove floating confetti, sparkles, neon glowing rings, harsh reflections and bright gold light strips; keep restrained champagne-gold headline and product details. Soft diffused studio light, comfortable contrast, clean readable type and ample margins. Original logo must stay recognizable and retain its original colours. No added text, discounts, prices, shipping claims or watermark.


## Local validation

- Final full customer Flutter suite after the calm-blue refinement: 228 passed, 0 failed.
- Targeted backend carousel model/sanitizer/admin-guard tests: 3 passed.
- Targeted admin options/image-dimension/payload tests: 3 passed.
- Flutter analyzer: 0 errors, 4 existing warnings and 32 informational notices.
- Rendered entrance and Deals banner were inspected at phone widths. Narrow-screen/enlarged-text startup tests passed.
- Blue-theme checks cover primary actions, cards, form borders, navigation and the actual stored dark-mode preference/switch back to light mode. The focused final shared-UI suite passed all 9 tests. Targeted analysis of the final palette/dark-mode changes reported no issues.
- Calm-blue refinement: all 23 focused UI tests passed, including muted-blue button contrast, the original logo identity, the first Low Cost World slide and both banner rectangles. The new sizing assertion initially exposed a screen-width/layout-width mismatch in the separate Low Cost entry; using AspectRatio fixed it without changing the store destination.
- Targeted final calm-blue analysis: 0 errors, 0 warnings; 7 existing informational notices in Home. Final diff check passed.
- Local validation used no real database, payment, provider product analysis or deployment. Native Android/iOS store builds have not been run for this patch. GitHub publication is a separate, user-authorized step.
- Initial failures from an outdated Deals expectation and a stale test asset bundle were corrected; the final full suite passed.

## Release version and previews

- Customer app version: `1.0.27+64`, following the user's last build `1.0.26+63`.
- Home screenshots in `output/previews/` render the actual Home widget with an offline sample catalogue. They are review artifacts, not live vendor listings, and are not included in the Flutter asset bundle.

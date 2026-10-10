# Customer category navigation

Main category -> subcategories -> selected subcategory products.

- Tapping a main category selects its subcategory panel, clears any category search, and resets the panel to the top.
- Only the selected main category is shown in the normal right-hand panel.
- Main-category heading taps remain on subcategories. The parent-level See all product shortcut was removed.
- Tapping a subcategory opens the existing CategoryProductsScreen with parent > subcategory.
- Medicine retains the existing pharmacy consultation/store options.
- Back navigation retains the selected category.

Validation: five navigation widget tests passed; the full customer regression suite passed all 147 tests. The edited screen and navigation tests have no Dart analysis issues.

The change is local and not deployed. Rebuild and distribute the customer app through Codemagic for customers to receive this screen change. Backend deployment alone cannot update an already installed app.

## Content Creator Equipment

- Customer navigation: Photography -> Content Creator Equipment -> matching products.
- The category is also searchable using creator and is available in the vendor product selector and admin catalog taxonomy.
- The tile uses the existing phone-tripod image at assets/categories/tripod_supports.jpg.
- Vendors or administrators must assign products to Photography > Content Creator Equipment for them to appear here. Existing product assignments are retained.
- No backend category migration is required: the existing category hierarchy filter accepts this label.
- The new category requires updated customer and vendor builds and an admin panel deployment. These changes were implemented locally; no production catalog data or deployments were changed.
- Local checks cover category-first navigation, exact product requests, search, vendor selection and admin taxonomy consistency.
- The vendor test exposed an existing Flash Sale checkbox Material assertion. Its container now uses a Material surface with the same colour, border and radius so its ink effects render correctly.

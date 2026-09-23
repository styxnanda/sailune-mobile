# Sailune Android v0.9.5

Collections now have their own top-level tab. The bottom action stays dedicated
to adding a story or creating a collection, with matching Sailune button styling.

- Collection cards show up to five story-art slices (40/15/15/15/15 for five),
  the collection name, story count, and average personal rating. Unrated stories
  are excluded from the average. Empty collections remain available.
- Previews follow appearance settings: portrait covers, horizontal backgrounds,
  or clipped story titles when artwork is hidden.
- Open a collection to browse the same story cards, search, shelves, and filters
  as Library. Collection details and manual membership editing have separate pages.
- Hold a collection card to delete it with confirmation. Its stories remain in
  the library. Manual and automatic collection membership are still supported.
- Transparent Android status and navigation bars extend the canvas edge-to-edge,
  with theme-aware system icons and safe spacing for controls.
- The story-detail banner fills the screen width behind the toolbar, covering
  half the viewport before merging into the page around the portrait cover.
- Detail actions share the primary button's width, with consistent spacing and
  stacked controls on narrow screens or at large text sizes.
- The collection picker identifies existing membership, including automatic
  matches, and updates its indicator immediately after adding a story.
- Library and Collections now share the same Sailune header and Settings action.
  Story details use colored AO3 or FFN marks alongside the reading status, and
  Settings includes links to Sailune's GitHub, Instagram, and LinkedIn.

The app version is 0.9.5 (Android build 13). This is an Android interface release;
the shared core remains v0.9.0. Existing databases and ZIP backups remain compatible.
No cloud synchronization is included.

The APK supports ARM64 and x86_64 and remains development-signed. CI signing keys
can differ from previously installed builds. Export and verify a backup before
uninstalling or switching builds if Android rejects the signing key.

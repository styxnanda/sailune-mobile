# Sailune v0.9.0

Collections and personal artwork, shared across the CLI, Desktop, and Android.

- Create manual collections, assign stories in bulk, or save automatic rules using personal tags, website tags, fandom, site, and reading status.
- Give each story an independent 2:3 portrait cover and horizontal background. Uploads are optimized automatically; original files are untouched.
- Choose portrait cards, translucent background cards, or the familiar minimal cards. Story details use a fading banner with an overlapping portrait.
- Back up the complete library, including collections and artwork, as one ZIP. Legacy JSON imports remain supported.
- Merge backups without overwriting existing personal fields or artwork. Missing artwork and manual collection memberships are added.

## Upgrade

The library migrates transactionally from SQLite schema 1 to schema 2 on first access. Make a backup before upgrading. Older Sailune binaries cannot open the upgraded database; keep Desktop and its bundled CLI on matching versions. A ZIP backup is not compatible with v0.1.0. Legacy `.json` export contains story metadata only, excluding new collections and artwork.

All three applications identify this milestone as **0.9.0**. Cloud sync is not included. Libraries stay local; ZIP files are portable backups, not synchronization files. Sailune still bookmarks stories and metadata rather than downloading story text.

## Limits

Image input: JPEG/PNG, 25 MiB and 40 megapixels maximum. Transparent areas are flattened onto white. Optimized covers fit within 1000 × 1500 pixels and 750 KiB; backgrounds have a 2000-pixel long-edge limit and 1 MiB ceiling. Framing previews show the selected crop/focal point. Originals and EXIF/location metadata are not retained.

Backups are limited to 512 MiB compressed/expanded, 64 MiB of JSON records, and 10,000 distinct image assets. Images use content hashes and thumbnails are regenerated on import. Source tags are exact matches; automatic collections do not infer synonyms or emotional themes.

## CLI examples

```sh
sailune --version
sailune collection create --name 'trauma-inducing'
sailune collection add COLLECTION_ID 1 2 3
sailune list --collection COLLECTION_ID
sailune collection create --name 'Angst' --kind smart --rules '{"source":{"tags":["Angst","Tragedy"],"all":false}}'
sailune art set 1 cover.jpg --role cover
sailune art set 1 background.jpg --role background --x 0.5 --y 0.4
sailune export library.zip
sailune import library.zip --merge
```

Desktop releases target Windows AMD64 and Linux AMD64. The Wails macOS build remains a local test target. Android is ARM64/x86_64; the published APK is development-signed, not a Play Store production release. Desktop binaries are unsigned.

### Android signing

This APK is development-signed. CI signing keys are not a stable production key;
an update over another build may require a backup, uninstall, and reinstall.
Do not uninstall before exporting and verifying your backup. A managed production
signing process is not included in this release.

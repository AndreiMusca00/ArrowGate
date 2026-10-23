# Pictarrow icons

Two original concepts generated with the built-in ImageGen tool. Exact prompts are in `prompts.json`; original outputs are preserved alongside 1024×1024 opaque PNG exports.

- `pictarrow-arrows-1024.png`: abstract interlocking arrows; alternative thumbnail.
- `pictarrow-fox-1024.png`: forest fox built from arrows; active app icon through `PictarrowIcon.appiconset`.

The previous `AppIcon.appiconset` is preserved. To switch concepts, copy the selected opaque 1024×1024 export to `ArrowGate/Assets.xcassets/PictarrowIcon.appiconset/PictarrowIcon.png` and rebuild.

The Xcode project, app target and shared scheme are named Pictarrow. Source folders, persistence names and bundle identifier keep their existing identities. Open `Pictarrow.xcodeproj` and select scheme Pictarrow.

## Launch intro

The active intro is a static fox on an ivory background, matching `ArrowGate/LaunchScreen.storyboard` at 240 points. `LaunchIntroView` holds the logo briefly and crossfades to Home; no arrows move. It runs once per fresh launch. `-skip-launch-intro` bypasses it for development.

The MP4 files in this folder are archived experiments only, not the current app behavior. The icon and source artwork are unchanged.

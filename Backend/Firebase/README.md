# Pictarrow content backend

Firebase Storage contains published, immutable content files. The app stores
player progress only on the device; no personal player data is uploaded.

## One-time Firebase setup

1. Create the Firebase project and register the iOS app with bundle identifier
   `com.flytechnologyandinnovation.ArrowGate`.
2. Add `GoogleService-Info.plist` to the `ArrowGate` target in Xcode.
3. Enable Storage in a US region and switch the project to Blaze.
4. In App Check, register the iOS app with App Attest. Leave enforcement off
   until device and simulator requests have been verified.
5. From this directory, select the project and deploy the read-only rules:

   ```sh
   firebase login
   firebase use --add
   firebase deploy --only storage
   ```

6. Upload `catalog.starter.json` to the exact Storage path
   `catalog/catalog.json` only while no real content release exists.

Debug builds use Firebase's App Check debug provider on both simulator and
device. Copy the debug token printed in Xcode's console into Firebase Console
> App Check > Manage debug tokens before enabling enforcement. Release builds
use App Attest with the production entitlement.

## Runtime download policy

The iOS app contains no campaign/event JSON or content artwork. A fresh install
therefore needs a connection once; it shows a dedicated loading or retry screen
until the first package window has been downloaded and validated. Returning
players can use the validated cache while offline.

The small `catalog/catalog.json` is checked once per app launch. It contains a
schema version, a content version and the list of chapter/event packages. The
app downloads the current chapter and the following two chapters in full. This
window has no level threshold. Earlier completed chapters keep only their JSON
and final reward; intermediate reveal pieces are removed.

Events are independent packages. They download from `previewStartsAt`, remain
available through their active interval and are removed after `endsAt`. A
completed event may retain its JSON and final reward for Collection. Player
progress remains local and is never part of the remote catalog.

If a refresh fails, already validated cached content remains usable. The next
app launch retries automatically.

## Publishing layout

Never overwrite files that a released catalog already references. Publish a
new version directory first, then publish the new catalog last:

```text
catalog/catalog.json
chapters/chapter-1/v1/chapter.json
chapters/chapter-1/v1/artwork/EnchantedTreePiece01.png
chapters/chapter-1/v1/artwork/EnchantedTreeComplete.png
events/halloween-2027/v1/event.json
events/halloween-2027/v1/artwork/HalloweenManorComplete.png
```

Every catalog entry includes the exact byte count and SHA-256 hash. The app
downloads into a staging location, verifies both, and only then exposes the
file. Increment `contentVersion` whenever the catalog changes. Increment a
chapter or event `version` whenever one of its files changes.

Prepare the complete upload tree from the checked-in JSON sources in
`Backend/ContentSource/Levels` and artwork sources in
`Backend/ContentSource/Artwork`. Both locations are kept for authoring and
publishing, outside the iOS app source tree:

```sh
python3 prepare_content.py --output /tmp/PictarrowFirebaseUpload
```

The command resolves every referenced artwork asset, copies chapter/event JSON,
calculates exact sizes and SHA-256 hashes and creates the master catalog. It
fails on missing or duplicate assets.

With a current Firebase CLI login, publish every package and then the catalog:

```sh
python3 publish_content.py /tmp/PictarrowFirebaseUpload \
  --bucket pictarrow-32e84.firebasestorage.app
```

For an incremental chapter update, preserve every unchanged package version,
bump only the changed chapter, and compare against the last published catalog:

```sh
python3 prepare_content.py --output /tmp/PictarrowFirebaseUpload \
  --content-version 17 --chapter-version 1=2
python3 publish_content.py /tmp/PictarrowFirebaseUpload \
  --bucket pictarrow-32e84.firebasestorage.app \
  --previous-catalog catalog.json
```

The publisher skips byte-identical objects already referenced by the previous
catalog and refuses to overwrite an immutable path whose bytes changed.

If Google Workspace requires reauthentication, run `firebase login --reauth`
first. Never edit the generated hash or size fields manually.

`metadata` is the chapter/event JSON, `gameplay` is disposable artwork used
while progressing, and `reward` is the final collectible kept for Collection.
New chapter/event releases use a new immutable `vN` directory. The master
catalog is the only object intentionally replaced and is always uploaded last.

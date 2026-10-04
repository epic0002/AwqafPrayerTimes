#!/bin/bash
# Builds an unsigned-but-entitled IPA (ad-hoc pseudo-signed with ldid) for sideloading
# via Sideloadly / AltStore / SideStore / TrollStore, which re-sign it on install.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
rm -rf build
xcodebuild -project AwqafPrayerTimes.xcodeproj -scheme AwqafPrayerTimes \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build | grep -E "error:|BUILD" || true

APP=build/dd/Build/Products/Release-iphoneos/AwqafPrayerTimes.app
[ -d "$APP" ] || { echo "Build failed"; exit 1; }

# Embed the app-group entitlements so sideloading tools carry them over.
if command -v ldid >/dev/null; then
  ldid -SWidget/Widget.entitlements "$APP/PlugIns/PrayerWidget.appex"
  ldid -SApp/App.entitlements "$APP"
fi

mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry AwqafPrayerTimes.ipa Payload)
mkdir -p dist && mv build/AwqafPrayerTimes.ipa dist/
echo "IPA: dist/AwqafPrayerTimes.ipa"

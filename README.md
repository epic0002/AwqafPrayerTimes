# Prayer Times (Jordan / Awqaf)

A small iOS app with a lock screen widget and notifications for prayer times, using the
official Jordanian Ministry of Awqaf timings as a CSV file.

**Requires iOS 16.0+** (lock screen widgets were added in iOS 16).

## Features

- **Widgets**: four styles, each listed separately in the widget gallery
  - **Classic**: previous and next timing with their times, plus the counter
    (lock screen rectangular / circular / inline, home screen small)
  - **Countdown**: a big `+`/`−` counter (rectangular, a circular ring gauge, home screen small)
  - **Progress**: a bar running from the previous timing to the next (rectangular, circular, home screen medium)
  - **Day**: the next three timings on the lock screen, or all six on the home screen (medium, large)
  - For the first 30 min after a timing the counter shows time elapsed: `+ 0:12`.
    After that it shows time remaining until the next one: `− 1:05`. Sunrise counts as a timing.
    You can change the 30 min window in Settings.
  - Home screen widgets use a background colour that follows the time of day (dawn, noon, sunset, night…)
- **Data source**: a CSV from a URL (default `https://awqaf-prayer.netlify.app/times.csv`) or a file you import
  - The default URL is set in `config.json` inside the app bundle (a plain file, not compiled into the binary)
  - Updates automatically when the loaded data is about to run out (around the end of the year),
    or by hand with **Settings → Update now** (or pull to refresh on the Times tab)
  - A copy of the 2026 CSV is bundled, so the app works offline from the first launch
- **Notifications**, set separately for each of the six timings:
  - on or off
  - sound or silent
  - offset from −120 to +120 min (negative means before the timing)
  - sound choice: system default, 4 bundled tones, or **import your own** (mp3/m4a/wav/…,
    converted and trimmed to 29 s, because iOS won't play longer notification sounds)
- English or Arabic names, 12 or 24 hour time

## CSV format

```
date,dawn,sunrise,duhr,asr,sunset,isha
01/01/2026,06:09,07:30,12:40,15:25,17:50,19:10
```
Column order doesn't matter. Common other header spellings (fajr, dhuhr, maghrib…) also work.
Dates can be `dd/MM/yyyy` or `yyyy-MM-dd`. Times are read in the time zone from `config.json` (`Asia/Amman`).

## config.json

```json
{
  "defaultURL": "https://awqaf-prayer.netlify.app/times.csv",
  "timeZone": "Asia/Amman",
  "autoUpdateDaysBeforeEnd": 7
}
```
**Editing in the app:** go to Settings → About → Configuration. You can change the default URL, and
pick the time zone and auto-update timing from drop-down menus. iOS doesn't let an app change files in
its own bundle, so your changes are saved in the app's data and used instead of the bundled file.
**Reset to defaults** goes back to the bundled file. If you change the time zone, the loaded timings
are re-read in the new zone.

**Changing the bundled default:** it's at `Payload/AwqafPrayerTimes.app/config.json` inside the IPA.
Unzip the IPA, edit the file, zip `Payload` again, then sideload. (Your sideloading tool re-signs it.)

## Installing the IPA

`dist/AwqafPrayerTimes.ipa` is not signed with a real certificate. Install it with **Sideloadly**,
**AltStore/SideStore**, or **TrollStore**.
The app and the widget share data through the app group `group.app.prayertimesjo`. Sideloading
tools must keep app groups, or the widget will only show the bundled data (AltStore rewrites
the group automatically, and the app supports that).
With a free Apple ID, sideloaded apps expire after 7 days.

After installing: open the app once and allow notifications. Then long-press the lock screen →
Customize → add the **Prayer Times** widget.

## Building from source

Requirements: Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
`ldid` is optional; it embeds entitlements in the unsigned IPA.

```bash
xcodegen generate          # creates AwqafPrayerTimes.xcodeproj
open AwqafPrayerTimes.xcodeproj
```
To run it on your own device from Xcode: choose your team for both targets. If the IDs are taken,
change the bundle IDs / app group in `project.yml` and the two `.entitlements` files
(and `Shared.defaultAppGroup` in `Shared/Shared.swift`).

To build an IPA: `./scripts/build_ipa.sh` writes `dist/AwqafPrayerTimes.ipa`.

`scripts/make_assets.py` creates the bundled tones and the app icon again.

## Layout

```
Shared/   used by the app and the widget: CSV parser, models, storage, settings, config
App/      SwiftUI app: times, notification settings, data source settings
Widget/   WidgetKit extension
```

## Limitations

- iOS allows at most 64 pending local notifications, which is about 10 days with 6 per day. The app
  schedules them again every time it opens and on background refresh. If neither happens in time,
  a final notification reminds you to open the app.
- Background refresh is decided by iOS. The widget also checks for new data when its timeline reloads.
- The widget updates once a minute through timeline entries, so iOS may show a change a few seconds late.

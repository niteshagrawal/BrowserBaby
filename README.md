# BrowserBaby

BrowserBaby is a macOS-first browser shell prototype aimed at Arc-like tab organization with a WebKit core and future hybrid engine toggle support.

## Included in this repo

- Native SwiftUI + WebKit macOS app scaffold.
- Vertical sidebar tabs with sections for favorites, pinned tabs, folders, and all tabs.
- Folder pin behavior: closing a folder-pinned tab resets it to its base URL instead of removing it.
- Per-tab engine picker with WebKit active and Chromium placeholder fallback.
- Build scripts for generating an installable `.app` and a shareable `.zip`.
- GitHub Actions workflow that builds and uploads a macOS artifact on tags.

## Prerequisites (macOS)

- Xcode 15+
- Homebrew
- XcodeGen

## Quick start

```bash
cd macos/BrowserBaby
./Scripts/bootstrap_macos.sh
open BrowserBaby.xcodeproj
```

Run in Xcode with the `BrowserBaby` scheme.

## Build installable/shareable output

```bash
cd macos/BrowserBaby
./Scripts/build_shareable.sh
```

Output:

- App bundle: `macos/BrowserBaby/build/export/BrowserBaby.app`
- Zip for sharing: `macos/BrowserBaby/build/BrowserBaby-macOS.zip`

## Notes

- Chromium engine integration is currently a placeholder; selecting Chromium reverts to WebKit until a Chromium backend is added.
- For public distribution outside your machine, you will need Apple code signing + notarization.

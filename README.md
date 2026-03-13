# BrowserBaby

BrowserBaby is a macOS-first browser shell prototype aimed at Arc-like tab organization with a WebKit core and future hybrid engine toggle support.

## Production-readiness improvements in this version

- Shared `WKProcessPool` to reduce per-tab process churn and improve resource reuse.
- Bounded `WKWebView` pool (LRU-style trimming) to keep memory stable under heavy tab usage.
- Lazy tab activation so only active/recent tabs keep live web views.
- Tab lifecycle tuning to avoid unnecessary loads and to reset pinned/folder-pinned tabs to base URL on close.
- Navigation delegate synchronization so URL/title updates are captured from real browsing state.

## Is it production-ready as a daily driver?

Not yet. This repository is currently a prototype and pre-production foundation.

For a concrete gap analysis and milestone plan, see `docs/daily-driver-readiness.md`.

## Recently implemented next steps

- Session persistence + restore: tabs, folders, selected tab, and default engine are now saved and reloaded on launch.
- Basic crash resilience: if a web content process is terminated, the tab automatically reloads.
- Productivity shortcuts: Command+T (new tab), Shift+Command+T (new private tab), Command+W (close selected tab), Shift+Command+D (toggle favorite), Shift+Command+P (toggle pin).
- Privacy baseline: private tabs now use non-persistent website data storage, with default private-mode toggle and a command to clear regular browsing data.
- Debounced session persistence to reduce disk write churn during heavy tab/navigation activity.
- Introduced unit-test targets for tab close semantics and session/model backward compatibility.
- Browser controls baseline: address bar navigation, back/forward/reload actions, and in-page find.
- Download manager baseline: WebKit download capture, destination handling, recent download list, and open/clear actions.
- URL safety guardrail: direct navigation now blocks unsafe schemes (e.g., `javascript:` and `file:`).
- Permission center baseline: persisted Ask/Allow/Deny states for camera, microphone, location, and notifications.
- Stabilization improvements: reopen closed tab support and repeated renderer-crash recovery fallback.
- Compatibility harness baseline: one-click top-sites suite to open a QA folder of critical web apps.

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

## Distribution checklist (for public sharing)

1. Set your Apple Developer Team in Xcode build settings.
2. Sign with Developer ID Application certificate.
3. Notarize the app using `notarytool`.
4. Staple notarization ticket before distribution.

## Notes

- Chromium engine integration is currently a placeholder; selecting Chromium reverts to WebKit until a Chromium backend is added.

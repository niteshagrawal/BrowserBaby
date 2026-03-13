# Daily Driver Readiness (Current State)

## Short answer

No — BrowserBaby is not yet production-ready as a daily-driver browser.

The current codebase is a solid prototype for Arc-style UX exploration, but it still lacks several reliability, security, compatibility, and operational capabilities required for safe primary-browser usage.

## Progress update

The following foundational items have now been started in code:

- Session persistence and launch-time session restore.
- Automatic reload when `WKWebView` web content process terminates.
- Keyboard shortcuts for frequent tab actions.
- Private-tab baseline via non-persistent `WKWebsiteDataStore`, plus manual clear-data control for regular browsing data.

These improve baseline usability but do not yet close the production-readiness gaps listed below.

## What is already in place

- macOS app shell with SwiftUI + WebKit.
- Sidebar model for favorites, pinned tabs, folders, and general tabs.
- Reset-on-close behavior for pinned and folder-pinned tabs.
- Initial memory optimization via shared `WKProcessPool` and bounded `WKWebView` pooling.
- Basic packaging workflow to produce a `.app` and `.zip`.

## What is still needed for true production readiness

### 1) Browser correctness and crash resilience

- Full session restore (tabs, windows, history position, scroll state) after crash/restart.
- Robust process crash handling and automatic tab/web-content recovery.
- Navigation correctness tests for redirects, popups, file downloads, auth flows, and media playback.

### 2) Security and privacy baseline

- Sandboxed storage strategy and explicit data boundaries (cookies, cache, local storage, credentials).
- Permission model and prompts (camera, mic, location, notifications) with persistent user controls.
- Private browsing mode with strict non-persistence guarantees.
- Security hardening review (e.g., URL handling, custom schemes, unsafe file access boundaries).

### 3) Web compatibility and extension strategy

- Resolve the Chromium engine plan: either remove the toggle for now or ship an actual supported backend.
- Compatibility validation for major sites (Google Workspace, Slack, GitHub, banking/video sites).
- Extension story (Safari Web Extensions support and lifecycle UX) before claiming Arc-like parity.

### 4) Performance and heavy-usage engineering

- Add telemetry (local diagnostics) for memory growth, CPU spikes, tab load latency, and process restarts.
- Adaptive background tab suspension/throttling policy.
- Stress testing at scale (100–300 tabs), including long-running soak tests.
- Benchmark and regression gates in CI for memory/CPU/perf budgets.

### 5) Data durability and sync expectations

- Stable persistence migrations for tab/folder/workspace data.
- Safe write-ahead or transactional persistence to prevent data loss.
- Optional account/sync design (if multi-device behavior is expected).

### 6) Product polish expected from a daily driver

- Keyboard shortcuts and command palette parity for tab/workspace operations.
- Reliable downloads manager.
- Find in page, reader mode, print behavior, and polished context menus.
- Accessibility audit (VoiceOver, focus order, keyboard navigation, contrast).

### 7) Release and operational readiness

- Automated test pyramid (unit, integration, UI, smoke).
- Signed + notarized release pipeline with provenance.
- Crash reporting and symbolication workflow.
- Versioned release notes and rollback strategy.

## Recommended next milestones

1. **Stabilization milestone**: crash recovery, session restore, download manager, private mode.
2. **Compatibility milestone**: top-site QA matrix + extension baseline.
3. **Performance milestone**: telemetry + stress/perf CI budgets.
4. **Release milestone**: notarized auto-updatable builds with crash reporting.

After those are complete and validated over sustained use, BrowserBaby can credibly move toward daily-driver status.

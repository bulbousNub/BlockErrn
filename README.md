# BlockErrn

BlockErrn is a SwiftUI + SwiftData earnings tracker built for gig delivery drivers. It tracks blocks of work, mileage, expenses, and profit across iPhone, Apple Watch, and CarPlay — giving you a complete financial picture from pickup to tip.

## Features

### iPhone

- **Block management** — Create, schedule, and track blocks with start/end times, base pay, tips, mileage deduction, and net profit. Blocks open to a detail view with expenses, audit history, and glassy summary cards.
- **Live GPS mileage tracking** — Background location tracking records route points while you drive. Mileage is converted to an IRS standard deduction automatically using whole-mile rounding.
- **Expense tracking** — Log expenses per block with categories, amounts, notes, timestamps, and optional profit exclusion. Categories are fully customizable in Settings.
- **Receipt capture** — Scan receipts using VisionKit's document scanner (or camera fallback). Images are compressed and stored locally with inline thumbnails and full-screen inspection.
- **Trends & analytics** — Weekly and monthly earnings charts, live metric cards for current period gross/mileage, interactive chart overlays, and drill-down views for historical data.
- **Live Activities** — Lock Screen and Dynamic Island widget showing real-time mileage, scheduled block times, and tracking status. Updates every 5 seconds during active blocks.
- **Notifications** — Configurable reminders before block start, before block end, at block end, and a tip reminder (default 24 hours post-block). Non-tip reminders are automatically cancelled when a block is marked complete.
- **Backup & restore** — Export all blocks, expenses, audits, settings, and receipt images as a ZIP archive. Import from ZIP or legacy JSON. Receipts are restored atomically alongside structured data.
- **iCloud backup** — Automatic cloud backup of all data with download/restore capability. Auto-backup on app background when enabled. Includes option to permanently delete your iCloud backup.
- **CSV export** — Configurable column selection for spreadsheet exports. Includes ISO timestamps, decimals, and JSON-wrapped arrays for nested data like expenses and audit entries.
- **Appearance** — System, light, and dark themes. Gradient backgrounds, ultra-thin materials, and capsule buttons throughout.
- **Contact** — In-app contact options for general inquiries, support requests, and bug reports. Bug reports link to GitHub Issues with an email fallback.
- **Privacy policy** — Full privacy policy viewable in-app under Settings > About.

### Apple Watch

- **Block list** — View active and upcoming blocks with sync status and iPhone reachability indicator.
- **Create blocks** — Step-by-step flow for date, start time, end time, and base pay. Start time auto-rounds to the next 15-minute interval. Handles overnight blocks.
- **Work mode** — Three-page vertical layout with live stats (gross, miles, deduction, profit), controls (package/stop counters, GPS toggle, end block), and a route map with tap-to-expand.
- **Base pay adjustment** — Quick +/- $5 buttons with Digital Crown for $0.25 fine-tuning.
- **Block completion summary** — After ending a block, a snapshot summary shows final stats before returning to the home screen.
- **Two-way sync** — All changes sync between Watch and iPhone via WatchConnectivity. Post-command sync ensures blocks created on Watch appear immediately on iPhone.

### CarPlay

- **Dashboard** — Active and upcoming blocks with auto-refresh.
- **In-car controls** — Start/stop GPS tracking, end blocks, and view real-time mileage and profit directly from the CarPlay interface.
- **Route map** — Live route overlay while tracking.

## Architecture

- **SwiftUI + SwiftData** — Views use `@Query` and `@Environment(\.modelContext)` for reactivity. Models (`Block`, `Expense`, `AuditEntry`, `AppSettings`) live in `DomainModels.swift`.
- **Local storage** — Receipt images saved in Application Support via `ReceiptStorage`. Backup archives include actual JPEGs alongside JSON data.
- **Theming** — `BlockErrnTheme` defines gradients, shadows, and card styles. The `.blockErrnCardStyle()` modifier provides consistent card presentation.
- **Navigation** — `NavigationStack` with sheets and detents. `WorkModeCoordinator` manages transitions between calculator, work mode, and block log.
- **Watch connectivity** — `PhoneWatchSessionManager` (iPhone) and `WatchSessionManager` (Watch) handle bidirectional command/sync messaging.

## Getting Started

1. Open `BlockErrn.xcodeproj` in Xcode 15+ (requires iOS 17+, watchOS 10+).
2. Select the `BlockErrn` scheme and run on a device (recommended for VisionKit, GPS, and Live Activities).
3. Grant notification and location permissions during onboarding.
4. Create a block, start tracking, and log expenses as you go.

## Third-Party Software

- **ZIPFoundation** — MIT License. Used for backup/restore ZIP archive creation. See Settings > About > Licenses for the full notice.

## License

Copyright 2025 TeJay Guilliams. Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

## Disclaimer

BlockErrn is an independent project and is not affiliated with, endorsed by, or sponsored by Amazon.com, Inc. or any of its subsidiaries, including Amazon Flex.

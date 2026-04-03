# Flex Earnings Tracker (BlockErrn)

BlockErrn is a SwiftUI + SwiftData assistant app for gig workers who need to track each block of work, log time, mileage, expenses, and keep profit/loss data well organized. The interface is built with gradients, ultra-thin materials, and capsule buttons to evoke a liquid-glass dashboard while minimizing distraction from capturing real receipts, numbers, and notes.

## Primary Functionality

- **Blocks as the core unit** – Each block stores scheduling metadata (date, duration, route points, start/end times) and financial snapshots (base pay, tips, mileage deduction, total profit). Blocks open to a detail view that shows expenses, audit entries, and totals with shiny glassy cards. `BlockDetailView.swift`, `TrendView.swift`, and `CalculatorView.swift` orchestrate how these items update and stay in sync with SwiftData.
- **Expense tracking** – Expenses belong to blocks and support categories, amounts, notes, timestamps, optional profit exclusion, and receipt images. The categories list is editable in `SettingsView`, and each expense is editable from the block detail flow. Expense persistence is provided by `Expense` entries in `DomainModels.swift`.
- **Receipt capture & storage** – The app embeds `ReceiptScanner.swift`, which attempts to use VisionKit’s document scanner or falls back to the camera picker. Images are compressed to JPEG and saved locally through `ReceiptStorage.swift`, allowing inline thumbs and full-screen inspection without duplicating the file. Receipt file names are referenced in the Expense model and included in exports.
- **Backup/Import** – `DataView.swift` packages all blocks, expenses, audits, and settings into a JSON payload (`BackupPayload`). For exports, the JSON plus receipts are zipped via the embedded ZIPFoundation sources (see `Flex Earnings Tracker/ZIPFoundation`). Importers accept either the new `.zip` format or legacy JSON, restoring structured data and receipt files atomically.
- **Data exports** – CSV exports let you pick which columns to include (IDs, durations, profit, audit entries, etc.). The UI exposes checkboxes, and the export runs through SwiftData blocks that form rows with ISO-formatted timestamps, decimals, and JSON-wrapped arrays for nested data.
- **Appearance & About** – Settings let you choose system/light/dark, edit expense categories through a dedicated sheet, tweak the IRS mileage rate, erase data, and review an About/Licenses section that cites ZIPFoundation’s MIT license. Theme helpers in `BlockErrnTheme.swift` keep every card and tile consistent.
- **Notifications & location** – `NotificationManager.swift` schedules local alerts 15 minutes before and at each block’s completion time. Onboarding prompts (in `OnboardingView.swift`) orchestrate notification, location, and background access so the `MileageTracker.swift` can keep collecting route points.
- **Work mode** – `WorkModeCoordinator.swift` centralizes how the app transitions between calculator, work mode, and the block log, ensuring the correct sheet/presentation is active when blocks are accepted or retrieved.

## Architecture Highlights

1. **SwiftUI + SwiftData** – Views rely on `@Query`/`@Environment(\.modelContext)` to stay reactive. Models (`Block`, `Expense`, `AuditEntry`, `AppSettings`) live in `DomainModels.swift`. Computed properties in these models supply totals, durations, formatted timestamps, and audit-induced state.
2. **Local storage & receipt management** – Receipt data is saved in Application Support via `ReceiptStorage`. Backup functions reference the file names so the archive can copy the actual JPEGs when creating the zipped backup. Import restores them under the same names.
3. **Theming** – `BlockErrnTheme` defines gradients, hero gradients, and shadow colors used across cards, nav bars, and hero tiles. The `.flexErrnCardStyle()` modifier keeps card trains ready for any section, and new hero tiles queue under that design.
4. **Navigation & sheets** – `NavigationStack` structures each tab, modals, and edit sheets. The block detail, expense editor, license list, and onboarding flows all rely on stacks and detents for a consistent navigation vocabulary.

## Getting Started

1. Open `Flex Earnings Tracker.xcodeproj` (requires Xcode 15 and iOS 17+).
2. Select the `BlockErrn` scheme and run on a device (preferred for VisionKit/receipt scanning). The simulator uses the fallback camera picker.
3. Grant notification/location permissions during onboarding. Without these, the app only functions in manual calculator/log mode.
4. Create a block via the calculator or new block sheet, accept it, then afford yourself to add expenses, toggle inclusion from profit, capture receipts, and review totals.

## Working with Data

- **Backing up** – Navigate to the Data tab and tap “Backup BlockErrn Data.” This writes `BlockErrnBackup.json` plus any referenced receipt JPEGs into a ZIP archive using ZIPFoundation’s `Archive`.
- **Importing** – Use the file importer to select either a ZIP backup (preferred) or legacy JSON. The importer decodes `BackupPayload` and writes the receipt files via `ReceiptStorage`. After import, SwiftData context is saved and reflections appear in the Logs/Blocks automatically.
- **Streaming CSV exports** – Toggle columns and tap “Export to CSV” to generate spreadsheets via the native file exporter. CSV rows are assembled by `makeCSVText()` and include nested JSON for collections like expenses and audit entries.

## Testing & Validation

- `BlockErrnTests.swift` / `BlockErrnUITests.swift` exist but are currently placeholders; manual validation is strongly recommended.  
- Run `xcodebuild -scheme BlockErrn -destination 'platform=iOS Simulator,name=iPhone 15' build` to ensure the project compiles after changes.  
- For quick checks, use `PreviewProvider` definitions (e.g., in `DataView.swift`) to inspect backups or cards without running the full scheme.

## Third-Party Software

- **ZIPFoundation** – MIT License (see `ZIPFoundation/Resources/PrivacyInfo.xcprivacy` and the bundled license text). Credit is surfaced through Settings → About → Licenses. The MIT notice must remain packaged with any redistribution of the app to comply with the license.


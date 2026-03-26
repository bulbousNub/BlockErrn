# FlexErrn

FlexErrn is a SwiftUI + SwiftData iOS app built to help gig-workers track earnings, expenses, and mileage per delivery or ride-sharing block. It combines the calculator, log, trend insights, and settings into one tab-based experience and uses location/GPS tracking plus local notifications to keep mileage estimates accurate.

## Key features
- Structured block entry with date/time scheduling, gross pay, optional tips, mileage input, and expense tracking.  
- Persistent SwiftData models for `Block`, `Expense`, `AuditEntry`, and `AppSettings`, with helpful computed properties (hours, total profit, etc.).  
- Local notifications remind drivers 15 minutes before a block is scheduled to end and again exactly at the end time so they remember to stop GPS logging.  
- A multi-step onboarding flow that requests reminders and background location access, plus an appearance picker (system/light/dark) with persistent preference syncing.
- Mileage tracking powered by `CLLocationManager` with background updates on device and requests for Always authorization.

## Architecture
- SwiftUI views (Calculator, Log, Trend, Settings, Block detail/onboarding) rely on `@Query` to observe SwiftData models and share `MileageTracker.shared` via `@EnvironmentObject`.  
- `NotificationManager` wraps `UNUserNotificationCenter` for scheduling/cancelling reminders tied to block end times.  
- Onboarding ensures users grant notifications first, then location always permission to keep trackers running even after the app backgrounds.

## Development
1. Open `Flex Earnings Tracker.xcodeproj` (iOS 17+/Swift 5.9).  
2. Run `FlexErrn` target; the app uses SwiftData model containers defined in `FlexErrnApp`.  
3. Grant notification/location permissions on first launch via onboarding.  
4. Create blocks either through the calculator or the manual “New Block” sheet to see logging, notifications, and tracking in action.

## Testing & Cleanup
- Build with the provided simulator/device targets; there are no automated tests yet (`FlexErrnTests`/`FlexErrnUITests` are placeholders).  
- Resetting the simulator’s permissions (or reinstalling the app) is necessary if you need to re-trigger the onboarding dialog for notifications/location.

## Notes
- The app stores reminders locally; no backend is required for notifications.  
- Appearance preference is saved inside `AppSettings` and immediately applied through `ContentView`.  
- Background location and data cleanup options are found in `SettingsView`.

import SwiftUI
import SwiftData
import CoreLocation
import CoreMotion
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var mileageTracker: MileageTracker
    @Environment(\.modelContext) private var context

    let appSettings: AppSettings
    let onComplete: () -> Void

    @State private var notificationPermissionGranted = false
    @State private var currentStep: Int = 0
    @State private var motionPermissionGranted = CMMotionActivityManager.authorizationStatus() == .authorized

    private let steps = 5

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient
                .ignoresSafeArea()
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                stepContent(for: currentStep)
            stepIndicator

                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                    }

                Button(currentStep == steps - 1 ? "Let’s go" : "Next") {
                    if currentStep == steps - 1 {
                        completeOnboarding()
                    } else {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 10)
            .padding()
        }
        .onChange(of: notificationPermissionGranted) { granted in
            if granted && currentStep == 1 {
                currentStep = 2
            }
        }
        .onChange(of: motionPermissionGranted) { granted in
            if granted && currentStep == steps - 1 {
                currentStep = steps - 1
            }
        }
        .onReceive(mileageTracker.$motionAuthorizationStatus) { status in
            motionPermissionGranted = (status == .authorized)
        }
        .onReceive(mileageTracker.$authorizationStatus) { status in
            if status == .authorizedAlways && currentStep == 3 {
                currentStep = 4
            }
        }
    }

    private var introStep: some View {
        VStack(spacing: 14) {
            iconBadge("sparkles")
            Text("Welcome aboard, BlockErrn Drivers!")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .lineLimit(1)
            ForEach(introBullets, id: \.self) { bullet in
                BulletRow(text: bullet)
            }
        }
    }

    private var brandingStep: some View {
        VStack(spacing: 18) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 6)
            Text("BlockErrn")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.primary)
            Text("Your Earnings. Your Miles. Your Data.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notificationStep: some View {
        VStack(spacing: 12) {
            iconBadge("bell.fill")
            Text("Enable reminders")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            Text("We’ll remind you before every block ends, so you don’t forget to stop GPS tracking or wrap up expenses.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button(action: requestNotifications) {
                Label(notificationPermissionGranted ? "Notifications enabled" : "Turn on reminders", systemImage: notificationPermissionGranted ? "checkmark.bell" : "bell.badge")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(notificationPermissionGranted ? Color(.systemGreen) : Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(notificationPermissionGranted)
            Text(notificationPermissionGranted ? "Notifications processed on device and can be turned off at any time - we can't spam you even if we wanted to." : "iOS will ask permission to deliver helpful reminders tied to each block.")
                .font(.caption2)
                .foregroundStyle(notificationPermissionGranted ? .green : .secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var locationStep: some View {
        VStack(spacing: 10) {
            iconBadge("location.north.fill")
            Text("Why we need location")
                .font(.headline)
                .foregroundColor(.primary)
            Text("We use GPS to measure the miles you drive for each block and keep your earnings estimates accurate, even while BlockErrn runs in the background.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Button(action: requestAlways) {
                    Label(isAuthorizedAlways ? "Always allowed" : "Allow Always", systemImage: isAuthorizedAlways ? "checkmark.shield" : "location.north")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAuthorizedAlways ? Color(.systemGreen) : Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(isAuthorizedAlways)
                Text(locationStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(isAuthorizedAlways ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var motionStep: some View {
        VStack(spacing: 12) {
            iconBadge("car.fill")
            Text("Drive-only mileage")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            Text("Give BlockErrn access to motion data so it can tell when you’re actually in a vehicle, keeping the IRS mileage clean.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: requestMotionAuthorization) {
                Label(motionPermissionGranted ? "Motion enabled" : "Allow motion tracking", systemImage: motionPermissionGranted ? "checkmark.car" : "car")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(motionPermissionGranted ? Color(.systemGreen) : Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(motionPermissionGranted || !CMMotionActivityManager.isActivityAvailable())
            Text(motionStatusMessage)
                .font(.caption2)
                .foregroundStyle(motionPermissionGranted ? .green : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }

    @ViewBuilder private func stepContent(for step: Int) -> some View {
        switch step {
        case 0:
            brandingStep
        case 1:
            introStep
        case 2:
            notificationStep
        case 3:
            locationStep
        case 4:
            motionStep
        default:
            motionStep
        }
    }

    private func iconBadge(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 72, weight: .semibold))
            .frame(width: 96, height: 96)
            .background(Circle().fill(Color.accentColor))
            .clipShape(Circle())
            .foregroundStyle(.white)
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 20, height: 6)
            }
        }
    }

    private func requestNotifications() {
        NotificationManager.shared.requestAuthorization { granted in
            notificationPermissionGranted = granted
        }
    }

    private func requestAlways() {
        mileageTracker.requestAuthorization()
    }

    private func requestMotionAuthorization() {
        mileageTracker.requestMotionAuthorization()
    }

    private func completeOnboarding() {
        appSettings.hasCompletedOnboarding = true
        try? context.save()
        onComplete()
    }

    private var isAuthorizedAlways: Bool {
        mileageTracker.authorizationStatus == .authorizedAlways
    }

    private var locationStatusMessage: String {
        if isAuthorizedAlways {
            return "Background GPS is ready, so BlockErrn can keep counting miles even when the app leaves the foreground."
        } else {
            return "We might not track mileage properly unless location is allowed always. Tap the button above to enable full tracking."
        }
    }

    private var motionStatusMessage: String {
        switch mileageTracker.motionAuthorizationStatus {
        case .authorized:
            return "Motion updates are enabled, so we only count the time you are actually driving."
        case .denied, .restricted:
            return "Motion tracking is blocked. Open Settings → BlockErrn to allow vehicle detection."
        case .notDetermined:
            return "Grant access on the next screen so we can ignore walking when measuring mileage."
        @unknown default:
            return "Motion data access is not available on this device."
        }
    }

    private let introBullets = [
        "Track your Dollars - base pay, tips, mileage and other expenses.",
        "Track your Miles - processed on device using GPS or through manual entry.",
        "Local Notifications - On-Device reminders to finish tracking your miles and expenses near the end of your blocks.",
        "Trend Data - visualizations and insights into your earnings and expenses, processed locally. Export your data to use for whatever you'd like, it's your data.",
        "Everything happens on-device - no account, no back-end, no middlemen. Your data is YOUR data."
    ]

    private struct BulletRow: View {
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(.accentColor)
                    .padding(.top, 6)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

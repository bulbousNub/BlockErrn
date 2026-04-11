import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Privacy Policy")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Effective Date: April 6, 2026")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("BlockErrn is designed to help you track gig work earnings, mileage, expenses, and related information while keeping you in control of your data. Our goal is simple: most of your information stays on your device unless you choose to export it or back it up.")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    policySection(
                        title: "Information We Collect",
                        body: """
                        When you use BlockErrn, the app may store the following information on your device:

                        • Work session or block details, including dates, times, earnings, tips, notes, and related records
                        • Expense information you enter
                        • Mileage and trip information if you use mileage tracking
                        • Receipt images or other media you choose to scan or attach
                        • Reminder and Live Activity data needed to show progress and alerts on your device
                        • Purchase status and entitlement information related to in-app purchases
                        """
                    )

                    policySection(
                        title: "How We Use Information",
                        body: """
                        We use your information only to provide the app's features, including:

                        • Tracking earnings, expenses, and mileage
                        • Generating summaries and insights
                        • Supporting reminders, notifications, and Live Activities
                        • Creating exports you request
                        • Backing up and restoring your data if you enable iCloud backup
                        • Managing premium access through Apple's in-app purchase system

                        We do not sell your personal information.

                        We do not use your information for third-party advertising.
                        """
                    )

                    policySection(
                        title: "Location and Motion Permissions",
                        body: """
                        If you enable mileage tracking, BlockErrn may request access to location and motion data. This is used only to track mileage, detect travel activity, and support related trip records and summaries inside the app.

                        You can disable these permissions at any time in your device settings.
                        """
                    )

                    policySection(
                        title: "Receipts and Images",
                        body: "If you scan or attach receipts, those files are stored locally on your device as part of your app data unless you choose to back them up or export them."
                    )

                    policySection(
                        title: "How Information Is Shared",
                        body: """
                        Your data is not sent to BlockErrn-operated servers.

                        Information only leaves your device in the following situations:

                        • CSV Export: when you choose to export and share your data
                        • iCloud Backup: when you choose to enable backup to your personal iCloud account
                        • Apple Services: when needed for features such as in-app purchases, notifications, Live Activities, or iCloud functionality
                        """
                    )

                    policySection(
                        title: "iCloud Backup",
                        body: """
                        If you enable iCloud backup, a copy of your app data may be stored in your personal iCloud account. This can include your work records, expenses, settings, receipts, and related app data.

                        Disabling iCloud backup stops future backups, but copies already stored in your iCloud account may remain until you delete them.
                        """
                    )

                    policySection(
                        title: "Data Retention",
                        body: """
                        Your data remains available until you remove it. You may delete your data by:

                        • deleting items inside the app
                        • using the app's erase/reset option, if available
                        • uninstalling the app from your device
                        • deleting exported or backed-up copies yourself
                        """
                    )

                    policySection(
                        title: "Data Security",
                        body: """
                        We rely on Apple platform security features to help protect your information, including device-level protections and Apple services such as iCloud where applicable.

                        However, no method of electronic storage or transmission is guaranteed to be completely secure.
                        """
                    )

                    policySection(
                        title: "Your Choices",
                        body: """
                        You can control your data by:

                        • choosing whether to enter or store information in the app
                        • enabling or disabling location, motion, notifications, and Live Activities permissions
                        • choosing whether to export your data
                        • choosing whether to enable iCloud backup
                        • deleting your data from the app or uninstalling the app
                        """
                    )

                    policySection(
                        title: "Children's Privacy",
                        body: "BlockErrn is not directed to children under 13, and we do not knowingly collect personal information from children."
                    )

                    policySection(
                        title: "Changes to This Privacy Policy",
                        body: "We may update this Privacy Policy from time to time. If we make changes, we will update the effective date above and post the revised version through the app, website, or App Store listing as appropriate."
                    )

                    policySection(
                        title: "Contact",
                        body: "If you have questions about this Privacy Policy, please use the support link provided on the BlockErrn App Store listing or the in-app help or contact option."
                    )
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Privacy Policy")
    }

    private func policySection(title: String, body: String) -> some View {
        SectionCard(title: title) {
            Text(body)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

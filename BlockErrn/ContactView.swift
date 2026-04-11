import SwiftUI
import SafariServices

struct ContactView: View {
    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    SectionCard(title: "Get in Touch") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Have a question, need help, or found a bug? Choose the best option below and we'll get back to you.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            // General Inquiry
                            Button {
                                openMail(
                                    to: "general@blockerrn.com",
                                    subject: nil,
                                    body: nil
                                )
                            } label: {
                                HStack {
                                    Image(systemName: "envelope")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("General Inquiry")
                                            .fontWeight(.semibold)
                                        Text("general@blockerrn.com")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)

                            // Support Inquiry
                            Button {
                                openMail(
                                    to: "support@blockerrn.com",
                                    subject: "Support Inquiry",
                                    body: nil
                                )
                            } label: {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Support Inquiry")
                                            .fontWeight(.semibold)
                                        Text("support@blockerrn.com")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)

                            // Bug Report
                            NavigationLink {
                                BugReportView()
                            } label: {
                                HStack {
                                    Image(systemName: "ladybug")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Bug Report")
                                            .fontWeight(.semibold)
                                        Text("Report an issue")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Contact")
    }

    private func openMail(to address: String, subject: String?, body: String?) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var queryItems: [URLQueryItem] = []
        if let subject {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        if let body {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Bug Report

struct BugReportView: View {
    @State private var showGitHubIssues = false

    var body: some View {
        ZStack {
            BlockErrnTheme.backgroundGradient.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    SectionCard(title: "Report a Bug") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Found something that isn't working right? The best way to report a bug is through GitHub Issues. This helps us track, prioritize, and resolve problems efficiently — and lets you follow along as we work on a fix.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                showGitHubIssues = true
                            } label: {
                                HStack {
                                    Image(systemName: "cat.fill")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GitHub Issues")
                                            .fontWeight(.semibold)
                                        Text("Recommended — track your report")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SectionCard(title: "Prefer Email?") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("If you'd rather send an email, please include as much detail as possible — what you were doing, what you expected to happen, and what happened instead. Screenshots and device info help too!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                openBugReportMail()
                            } label: {
                                HStack {
                                    Image(systemName: "envelope")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Email Bug Report")
                                            .fontWeight(.semibold)
                                        Text("support@blockerrn.com")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Bug Report")
        .sheet(isPresented: $showGitHubIssues) {
            SafariBrowserView(url: URL(string: "https://github.com/bulbousNub/BlockErrn/issues")!)
                .ignoresSafeArea()
        }
    }

    private func openBugReportMail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@blockerrn.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Bug Report")
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

private struct SafariBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

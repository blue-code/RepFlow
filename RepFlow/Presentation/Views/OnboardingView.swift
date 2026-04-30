import SwiftUI
import UserNotifications
import CoreMotion

struct OnboardingView: View {

    @AppStorage("hasFinishedOnboarding") private var done = false
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.51, blue: 0.16),
                         Color(red: 0.71, green: 0.10, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            TabView(selection: $page) {
                introPage.tag(0)
                differentiatorPage.tag(1)
                permissionsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Page 1: Welcome

    private var introPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(.white)

            Text(LocalizedStringResource("onb.welcome"))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(LocalizedStringResource("onb.welcomeBody"))
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
            HStack {
                Spacer()
                Button {
                    withAnimation { page = 1 }
                } label: {
                    HStack {
                        Text(LocalizedStringResource("onb.continueButton"))
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.71, green: 0.10, blue: 0.24))
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(.white, in: Capsule())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Page 2: Differentiators

    private var differentiatorPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("RepFlow")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(symbol: "applewatch.side.right", titleKey: "onb.differentiator1")
                FeatureRow(symbol: "bolt.heart.fill", titleKey: "onb.differentiator2")
                FeatureRow(symbol: "timer", titleKey: "onb.differentiator3")
            }
            .padding(.horizontal, 32)

            Spacer()
            HStack {
                Spacer()
                Button {
                    withAnimation { page = 2 }
                } label: {
                    HStack {
                        Text(LocalizedStringResource("onb.continueButton"))
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.71, green: 0.10, blue: 0.24))
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(.white, in: Capsule())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    // MARK: - Page 3: Permissions

    @State private var motionRequested = false
    @State private var notifGranted = false

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 40)

            Text(LocalizedStringResource("onb.permissions"))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 32)

            Text(LocalizedStringResource("onb.permissionsBody"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 32)

            Spacer().frame(height: 12)

            VStack(spacing: 10) {
                PermissionTile(
                    symbol: "bell.fill",
                    titleKey: "onb.permNotifications",
                    descKey: "onb.permNotificationsDesc",
                    granted: notifGranted
                ) {
                    Task { await requestNotifications() }
                }
                PermissionTile(
                    symbol: "figure.walk.motion",
                    titleKey: "onb.permMotion",
                    descKey: "onb.permMotionDesc",
                    granted: motionRequested
                ) {
                    requestMotion()
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            HStack {
                Button {
                    done = true
                } label: {
                    Text(LocalizedStringResource("onb.skip"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Button {
                    done = true
                } label: {
                    Text(LocalizedStringResource("onb.startButton"))
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.71, green: 0.10, blue: 0.24))
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }

    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { notifGranted = granted }
        } catch {
            await MainActor.run { notifGranted = false }
        }
    }

    private func requestMotion() {
        // CoreMotion은 iOS에서 별도 권한 트리거 필요
        let manager = CMMotionActivityManager()
        let queue = OperationQueue.main
        manager.queryActivityStarting(from: .now.addingTimeInterval(-60), to: .now, to: queue) { _, _ in
            DispatchQueue.main.async { motionRequested = true }
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let titleKey: String.LocalizationValue
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            Text(String(localized: titleKey))
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
}

private struct PermissionTile: View {
    let symbol: String
    let titleKey: String.LocalizationValue
    let descKey: String.LocalizationValue
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: titleKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(String(localized: descKey))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: granted ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import UserNotifications
import CoreMotion

struct OnboardingView: View {

    @AppStorage("hasFinishedOnboarding") private var done = false
    @State private var page = 0
    @State private var motionRequested = false
    @State private var notifGranted = false

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()

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

    // MARK: - Page 1

    private var introPage: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: RFSpace.lg) {
                Spacer()

                Text("REPFLOW")
                    .rfSectionHeader()

                Text("워치가\n너의 코치다.")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(RFColor.fg)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("푸시업·풀업을 자동으로 카운트하고, 하루 종일 가볍게 분산해서 운동하는 GTG 훈련법으로 빠르게 늘어보자.")
                    .font(.rfBody)
                    .foregroundStyle(RFColor.fgMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { page = 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("다음")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(RFPrimaryButton())
                .padding(.bottom, RFSpace.xxxl)
            }
            .frame(width: geo.size.width - RFSpace.xl * 2, alignment: .leading)
            .padding(.horizontal, RFSpace.xl)
        }
    }

    // MARK: - Page 2

    private var differentiatorPage: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: RFSpace.lg) {
                Spacer()

                Text("DIFFERENTIATORS")
                    .rfSectionHeader()

                Text("다른 앱에 없는 것")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(RFColor.fg)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 1) {
                    FeatureRow(symbol: "applewatch.side.right", title: "워치 모션 자동 카운트", desc: "가속도 + 자이로 디텍션")
                    FeatureRow(symbol: "bolt.heart.fill", title: "GTG 훈련법", desc: "하루 종일 분산 알림")
                    FeatureRow(symbol: "timer", title: "EMOM · 타바타 · AMRAP", desc: "햅틱 인터벌 트레이너")
                }
                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
                .padding(.top, RFSpace.md)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { page = 2 }
                } label: {
                    HStack(spacing: 6) {
                        Text("다음")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(RFPrimaryButton())
                .padding(.bottom, RFSpace.xxxl)
            }
            .frame(width: geo.size.width - RFSpace.xl * 2, alignment: .leading)
            .padding(.horizontal, RFSpace.xl)
        }
    }

    // MARK: - Page 3 (permissions)

    private var permissionsPage: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: RFSpace.lg) {
                Spacer().frame(height: RFSpace.xl)

                Text("PERMISSIONS").rfSectionHeader()

                Text("권한 허용")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(RFColor.fg)
                    .fixedSize(horizontal: false, vertical: true)

                Text("RepFlow는 외부 서버로 어떠한 데이터도 보내지 않습니다.")
                    .font(.rfCaption)
                    .foregroundStyle(RFColor.fgMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 1) {
                    PermissionTile(symbol: "bell.fill", title: "알림", desc: "GTG 알림 발송", granted: notifGranted) {
                        Task { await requestNotifications() }
                    }
                    PermissionTile(symbol: "figure.walk.motion", title: "모션 & 피트니스", desc: "워치 자동 카운트", granted: motionRequested) {
                        requestMotion()
                    }
                }
                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))

                Spacer()

                Button {
                    done = true
                } label: {
                    Text("시작하기")
                }
                .buttonStyle(RFPrimaryButton())

                Button {
                    done = true
                } label: {
                    Text("건너뛰기")
                        .font(.rfCaption)
                        .foregroundStyle(RFColor.fgMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, RFSpace.xxl)
            }
            .frame(width: geo.size.width - RFSpace.xl * 2, alignment: .leading)
            .padding(.horizontal, RFSpace.xl)
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
        let manager = CMMotionActivityManager()
        let queue = OperationQueue.main
        manager.queryActivityStarting(from: .now.addingTimeInterval(-60), to: .now, to: queue) { _, _ in
            DispatchQueue.main.async { motionRequested = true }
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let desc: String
    var body: some View {
        HStack(spacing: RFSpace.md) {
            Image(systemName: symbol)
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.accent)
                .frame(width: 32, height: 32)
                .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.rfTitleMd).foregroundStyle(RFColor.fg)
                Text(desc).font(.rfCaptionSm).foregroundStyle(RFColor.fgSubtle)
            }
            Spacer()
        }
        .padding(RFSpace.md)
    }
}

private struct PermissionTile: View {
    let symbol: String
    let title: String
    let desc: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RFSpace.md) {
                Image(systemName: symbol)
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.accent)
                    .frame(width: 32, height: 32)
                    .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.rfTitleMd).foregroundStyle(RFColor.fg)
                    Text(desc).font(.rfCaptionSm).foregroundStyle(RFColor.fgSubtle)
                }
                Spacer()
                Image(systemName: granted ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(granted ? RFColor.success : RFColor.fgSubtle)
            }
            .padding(RFSpace.md)
        }
        .buttonStyle(.plain)
    }
}

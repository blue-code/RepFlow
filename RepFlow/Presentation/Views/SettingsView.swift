import SwiftUI
import SwiftData

struct SettingsView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context
    @State private var pro = ProManager.shared
    @State private var showPaywall = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                RFColor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: RFSpace.xl) {
                        proStatusCard

                        section(title: "PROFILE") {
                            if let profile {
                                VStack(spacing: 1) {
                                    profileRow(label: "이름", value: profile.displayName)
                                    stepperRow(label: "한 세트 최고", value: profile.pushUpBest, range: 0...500) {
                                        profile.pushUpBest = $0
                                        try? context.save()
                                    }
                                }
                                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
                            }
                        }

                        section(title: "TRAINING") {
                            VStack(spacing: 1) {
                                NavigationLink { GTGSettingsView() } label: {
                                    settingRow(symbol: "bolt.heart.fill", title: "GTG 모드", chip: pro.isPro ? nil : "Pro")
                                }
                                .buttonStyle(.plain)

                                NavigationLink { CalibrationGuideView() } label: {
                                    settingRow(symbol: "wand.and.stars", title: "자동 카운트", chip: "Beta")
                                }
                                .buttonStyle(.plain)
                            }
                            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
                        }

                        if let profile {
                            section(title: "PREFERENCES") {
                                VStack(spacing: 1) {
                                    toggleRow(label: "햅틱", isOn: Binding(
                                        get: { profile.hapticEnabled },
                                        set: { profile.hapticEnabled = $0; try? context.save() }
                                    ))
                                    toggleRow(label: "알림 사운드", isOn: Binding(
                                        get: { profile.notificationSoundEnabled },
                                        set: { profile.notificationSoundEnabled = $0; try? context.save() }
                                    ))
                                }
                                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                                .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
                            }
                        }

                        section(title: "ABOUT") {
                            VStack(spacing: 1) {
                                linkRow(label: "개인정보처리방침", url: "https://blue-code.github.io/legal/repflow/privacy.html")
                                linkRow(label: "이용약관", url: "https://blue-code.github.io/legal/repflow/terms.html")
                                linkRow(label: "지원/문의", url: "https://blue-code.github.io/legal/repflow/support.html")
                                linkRow(label: "피드백 보내기", url: FeedbackLink.url.absoluteString)
                            }
                            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
                        }

                        Text("RepFlow v1.0.2 — 워치가 하루 종일 너의 코치")
                            .font(.rfCaptionSm)
                            .foregroundStyle(RFColor.fgSubtle)
                            .frame(maxWidth: .infinity)
                            .padding(.top, RFSpace.lg)
                    }
                    .padding(.horizontal, RFSpace.lg)
                    .padding(.top, RFSpace.sm)
                    .padding(.bottom, RFSpace.xxl)
                }
            }
            .navigationTitle("설정")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await pro.loadProducts()
            }
        }
    }

    @ViewBuilder
    private var proStatusCard: some View {
        if pro.isPro {
            HStack(spacing: RFSpace.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(RFColor.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("RepFlow Pro").font(.rfTitleMd).foregroundStyle(RFColor.fg)
                    Text("모든 기능 활성화됨").font(.rfCaptionSm).foregroundStyle(RFColor.fgMuted)
                }
                Spacer()
            }
            .rfCard()
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: RFSpace.md) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.title2)
                        .foregroundStyle(RFColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro 시작").font(.rfTitleMd).foregroundStyle(RFColor.fg)
                        Text("GTG 모드 + 인텔리전트 인터벌").font(.rfCaptionSm).foregroundStyle(RFColor.fgMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(RFColor.fgSubtle)
                }
                .rfCard()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text(title).rfSectionHeader()
            content()
        }
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.rfBody).foregroundStyle(RFColor.fg)
            Spacer()
            Text(value).font(.rfCaption).foregroundStyle(RFColor.fgMuted)
        }
        .padding(RFSpace.md)
    }

    private func stepperRow(label: String, value: Int, range: ClosedRange<Int>, onChange: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: onChange), in: range) {
            HStack {
                Text(label).font(.rfBody).foregroundStyle(RFColor.fg)
                Spacer()
                Text("\(value)").font(.rfMonoBody).foregroundStyle(RFColor.fgMuted)
            }
        }
        .padding(RFSpace.md)
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(.rfBody).foregroundStyle(RFColor.fg)
        }
        .tint(RFColor.accent)
        .padding(RFSpace.md)
    }

    private func settingRow(symbol: String, title: String, chip: String?) -> some View {
        HStack(spacing: RFSpace.md) {
            Image(systemName: symbol)
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.accent)
                .frame(width: 28)
            Text(title).font(.rfBody).foregroundStyle(RFColor.fg)
            Spacer()
            if let chip {
                Text(chip).rfChip()
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(RFColor.fgSubtle)
        }
        .padding(RFSpace.md)
    }

    private func linkRow(label: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(label).font(.rfBody).foregroundStyle(RFColor.fg)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(RFColor.fgSubtle)
            }
            .padding(RFSpace.md)
        }
    }
}

/// The "피드백 보내기" destination — the blue-code feedback form, shared across every app and
/// filtered by the `app` field (AppCommonSkill `06-legal-privacy-review.md`).
///
/// The form is *opened*, never posted to: the user fills it in Safari, a separate app, so this app
/// still collects nothing and its `DATA_NOT_COLLECTED` privacy label stays honest. An in-app POST
/// would break that — don't add one.
///
/// Version and locale are prefilled so a report arrives already saying which build and language it
/// came from; both are visible in the form before the user submits.
private enum FeedbackLink {
    private static let appSlug = "repflow"

    static var url: URL {
        var components = URLComponents(
            string: "https://docs.google.com/forms/d/e/"
                + "1FAIpQLSekD7Uyg8Oa5WVWX0zV15PEyWS2y9A5sIGxA_pSeAcvWVtf6Q/viewform")!
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        components.queryItems = [
            URLQueryItem(name: "usp", value: "pp_url"),
            URLQueryItem(name: "entry.1556462282", value: appSlug),
            URLQueryItem(name: "entry.88571063", value: "\(short) (\(build))"),
            URLQueryItem(name: "entry.1277534382", value: Locale.current.identifier),
        ]
        // Safe: the base is a string literal and URLComponents percent-encodes every value.
        return components.url!
    }
}

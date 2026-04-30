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
                                    stepperRow(label: "푸시업 최고", value: profile.pushUpBest, range: 0...500) {
                                        profile.pushUpBest = $0
                                        try? context.save()
                                    }
                                    stepperRow(label: "풀업 최고", value: profile.pullUpBest, range: 0...100) {
                                        profile.pullUpBest = $0
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

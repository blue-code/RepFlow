import SwiftUI
import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var manager = ProManager.shared
    @State private var selectedID: String?

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()

            // Accent glow background
            VStack {
                Circle()
                    .fill(RFColor.accent.opacity(0.20))
                    .frame(width: 500, height: 500)
                    .blur(radius: 120)
                    .offset(y: -200)
                Spacer()
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RFSpace.xl) {
                    closeButton
                    header
                    featureList
                    productsList
                    purchaseButton
                    legalLinks
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.bottom, RFSpace.xl)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await manager.loadProducts()
            selectedID = ProManager.yearlyID
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RFColor.fgMuted)
                    .padding(8)
                    .background(RFColor.bgElevated, in: Circle())
                    .overlay(Circle().stroke(RFColor.border, lineWidth: 1))
            }
        }
        .padding(.top, RFSpace.lg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text("REPFLOW PRO").rfSectionHeader()
            Text("워치가 하루 종일\n너의 코치가 된다.")
                .font(.system(size: 36, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(RFColor.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureList: some View {
        VStack(spacing: 1) {
            ProFeatureRow(symbol: "bolt.heart.fill", title: "GTG 모드", desc: "검증된 진보 훈련법 — 하루 종일 분산 알림")
            ProFeatureRow(symbol: "metronome", title: "인텔리전트 인터벌", desc: "EMOM · 타바타 · AMRAP")
            ProFeatureRow(symbol: "chart.line.uptrend.xyaxis", title: "고급 분석", desc: "Tempo · RIR · 적응형 프로그램")
            ProFeatureRow(symbol: "applewatch.side.right", title: "워치 자동 카운트", desc: "백그라운드 + 심박수")
        }
        .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
    }

    private var productsList: some View {
        VStack(spacing: RFSpace.sm) {
            if manager.products.isEmpty && manager.isLoading {
                ProgressView().tint(RFColor.accent).padding()
            } else if manager.products.isEmpty {
                Text("상품을 불러올 수 없습니다.")
                    .font(.rfCaption)
                    .foregroundStyle(RFColor.fgMuted)
                    .padding()
            } else {
                ForEach(manager.products, id: \.id) { product in
                    ProductTile(
                        product: product,
                        selected: selectedID == product.id,
                        recommended: product.id == ProManager.yearlyID
                    ) {
                        selectedID = product.id
                    }
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task {
                guard let p = manager.products.first(where: { $0.id == selectedID }) else { return }
                await manager.purchase(p)
                if manager.isPro { dismiss() }
            }
        } label: {
            Group {
                if manager.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonTitle)
                }
            }
        }
        .buttonStyle(RFPrimaryButton())
        .disabled(selectedID == nil || manager.isLoading)
    }

    private var legalLinks: some View {
        HStack(spacing: RFSpace.lg) {
            Button("복원") { Task { await manager.restore() } }
            Link("이용약관", destination: URL(string: "https://blue-code.github.io/legal/repflow/terms.html")!)
            Link("개인정보", destination: URL(string: "https://blue-code.github.io/legal/repflow/privacy.html")!)
        }
        .font(.rfCaptionSm)
        .foregroundStyle(RFColor.fgMuted)
    }

    private var buttonTitle: String {
        guard let id = selectedID,
              let p = manager.products.first(where: { $0.id == id }) else {
            return "Pro 시작"
        }
        if id == ProManager.monthlyID, p.subscription?.introductoryOffer?.paymentMode == .freeTrial {
            return "1주일 무료, 그 후 \(p.displayPrice)/월"
        }
        return "Pro 시작 — \(p.displayPrice)"
    }
}

private struct ProFeatureRow: View {
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

private struct ProductTile: View {
    let product: Product
    let selected: Bool
    let recommended: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: RFSpace.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? RFColor.accent : RFColor.fgSubtle)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label).font(.rfTitleMd).foregroundStyle(RFColor.fg)
                        if recommended { Text("BEST").rfChip() }
                    }
                    if let suffix = priceSuffix {
                        Text(suffix).font(.rfCaptionSm).foregroundStyle(RFColor.fgSubtle)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.rfMonoBody.bold())
                    .foregroundStyle(RFColor.fg)
            }
            .padding(RFSpace.md)
            .background(
                RoundedRectangle(cornerRadius: RFRadius.md)
                    .fill(selected ? RFColor.accentSoft : RFColor.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RFRadius.md)
                    .stroke(selected ? RFColor.accent.opacity(0.6) : RFColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    private var label: String {
        switch product.id {
        case ProManager.monthlyID: return "월간"
        case ProManager.yearlyID: return "연간"
        case ProManager.lifetimeID: return "평생"
        default: return product.displayName
        }
    }

    private var priceSuffix: String? {
        switch product.id {
        case ProManager.monthlyID: return product.subscription?.introductoryOffer?.paymentMode == .freeTrial ? "1주일 무료 후 자동 갱신" : "월 자동 갱신"
        case ProManager.yearlyID: return "연 자동 갱신 (~45% 할인)"
        case ProManager.lifetimeID: return "1회 결제, 평생 사용"
        default: return nil
        }
    }
}

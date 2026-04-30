import SwiftUI

struct CalibrationGuideView: View {

    @AppStorage("repflow.sensitivity") private var sensitivity: Double = 1.0
    @State private var session = PhoneSessionService.shared

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpace.xl) {
                    introCard
                    stepsCard
                    sensitivityCard
                    statusCard
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.vertical, RFSpace.lg)
            }
        }
        .navigationTitle("디텍션 정확도")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            HStack {
                Image(systemName: "scope").foregroundStyle(RFColor.accent)
                Text("개인화 캘리브레이션").font(.rfTitleMd).foregroundStyle(RFColor.fg)
            }
            Text("워치는 평균 임계값으로 카운트하지만, 손목 두께/시계 위치/운동 속도가 사람마다 다릅니다. 캘리브레이션은 본인의 동작 진폭을 측정해서 정확도를 크게 올립니다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rfCard()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("STEPS").rfSectionHeader()
            VStack(alignment: .leading, spacing: RFSpace.sm) {
                stepRow(num: "1", text: "워치 RepFlow 앱을 열고 메뉴 하단 \"캘리브레이션\"을 탭")
                stepRow(num: "2", text: "운동 종목 선택 (푸시업/풀업/딥스 등)")
                stepRow(num: "3", text: "평소 속도로 5회 정상 동작")
                stepRow(num: "4", text: "체크 표시 뜨면 자동 저장 — 끝")
            }
            .padding(RFSpace.md)
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
        }
    }

    private var sensitivityCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("SENSITIVITY").rfSectionHeader()
            VStack(alignment: .leading, spacing: RFSpace.sm) {
                HStack {
                    Text(label(for: sensitivity))
                        .font(.rfTitleMd)
                        .foregroundStyle(RFColor.fg)
                    Spacer()
                    Text(String(format: "%.2f×", sensitivity))
                        .font(.rfMonoBody)
                        .foregroundStyle(RFColor.fgMuted)
                }
                Slider(value: $sensitivity, in: 0.7...1.3, step: 0.05) {
                    EmptyView()
                } minimumValueLabel: {
                    Text("민감↑").font(.rfCaptionSm).foregroundStyle(RFColor.fgSubtle)
                } maximumValueLabel: {
                    Text("엄격").font(.rfCaptionSm).foregroundStyle(RFColor.fgSubtle)
                }
                .tint(RFColor.accent)
                .onChange(of: sensitivity) { _, newValue in
                    syncToWatch(sensitivity: newValue)
                }
                Text("카운트가 너무 자주 잡히면 → 슬라이더를 오른쪽으로\n동작이 인식 안되면 → 왼쪽으로")
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            }
            .padding(RFSpace.md)
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text("STATUS").rfSectionHeader()
            HStack {
                Circle()
                    .fill(session.isWatchReachable ? RFColor.success : RFColor.fgSubtle)
                    .frame(width: 8, height: 8)
                Text(session.isWatchReachable ? "워치 연결됨" : "워치 연결 안됨")
                    .font(.rfBody)
                    .foregroundStyle(RFColor.fg)
                Spacer()
            }
            .padding(RFSpace.md)
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
        }
    }

    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: RFSpace.md) {
            Text(num)
                .font(.rfMonoBody.bold())
                .foregroundStyle(RFColor.accent)
                .frame(width: 22, alignment: .leading)
            Text(text)
                .font(.rfBody)
                .foregroundStyle(RFColor.fg)
        }
    }

    private func label(for value: Double) -> String {
        switch value {
        case ..<0.85: return "매우 민감"
        case 0.85..<0.95: return "민감"
        case 0.95...1.05: return "표준"
        case 1.05...1.15: return "약간 엄격"
        default: return "엄격"
        }
    }

    private func syncToWatch(sensitivity: Double) {
        session.sendSensitivityUpdate(sensitivity)
    }
}

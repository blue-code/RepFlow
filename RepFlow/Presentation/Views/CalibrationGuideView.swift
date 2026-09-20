import SwiftUI

/// 자동 카운트 (실험적). 기본은 OFF — 사용자가 명시적으로 켜야 워치가 모션 디텍션을 시도.
/// 푸시업/풀업 손목 가속도는 본질적 노이즈가 커서 기본 입력은 탭/크라운 카운트.
struct CalibrationGuideView: View {

    @AppStorage("repflow.autoDetect.enabled") private var autoDetectEnabled: Bool = false
    @AppStorage("repflow.sensitivity") private var sensitivity: Double = 1.0
    @State private var session = PhoneSessionService.shared

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpace.xl) {
                    introCard
                    masterToggleCard
                    if autoDetectEnabled {
                        stepsCard
                        sensitivityCard
                    }
                    statusCard
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.vertical, RFSpace.lg)
            }
        }
        .navigationTitle("자동 카운트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(RFColor.accent)
                Text("자동 카운트 (실험적)").font(.rfTitleMd).foregroundStyle(RFColor.fg)
                Text("Beta").rfChip()
            }
            Text("워치 손목 모션으로 자동 카운트를 시도합니다. 손목 두께·시계 위치·자세에 따라 인식률 편차가 큽니다. 기본 카운트는 워치 탭/크라운이고, 자동 감지는 보조 기능입니다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rfCard()
    }

    private var masterToggleCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text("MODE").rfSectionHeader()
            HStack {
                Text("자동 카운트 활성화")
                    .font(.rfBody)
                    .foregroundStyle(RFColor.fg)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { autoDetectEnabled },
                    set: { newValue in
                        autoDetectEnabled = newValue
                        session.sendAutoDetectEnabled(newValue)
                    }
                ))
                .labelsHidden()
                .tint(RFColor.accent)
            }
            .padding(RFSpace.md)
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))

            Text("OFF: 워치에서 탭/크라운으로 카운트 (기본·안정)\nON: 모션 자동 감지 시도 (실험적·인식률 편차 있음)")
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgSubtle)
                .padding(.horizontal, RFSpace.sm)
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("CALIBRATION STEPS").rfSectionHeader()
            VStack(alignment: .leading, spacing: RFSpace.sm) {
                stepRow(num: "1", text: "워치 앱 메뉴 → \"고급\" → 운동 종목 캘리브레이션 탭")
                stepRow(num: "2", text: "정지 자세로 1.5초 (잡음 측정)")
                stepRow(num: "3", text: "평소 속도로 5회 정상 동작")
                stepRow(num: "4", text: "체크 표시 뜨면 자동 저장")
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
                    session.sendSensitivityUpdate(newValue)
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
}

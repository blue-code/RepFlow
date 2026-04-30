import SwiftUI

struct QuickStartDetailView: View {
    let exercise: ExerciseKind

    var body: some View {
        ZStack {
            RFColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpace.xl) {
                    heroBlock
                    instructionBlock
                    modesBlock
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.top, RFSpace.lg)
                .padding(.bottom, RFSpace.xxl)
            }
        }
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var heroBlock: some View {
        VStack(spacing: RFSpace.md) {
            Image(systemName: exercise.symbol)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(RFColor.accent)
                .frame(width: 96, height: 96)
                .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.lg))

            Text(exercise.displayName)
                .font(.rfDisplayMd)
                .foregroundStyle(RFColor.fg)
        }
        .frame(maxWidth: .infinity)
    }

    private var instructionBlock: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            HStack(spacing: RFSpace.sm) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundStyle(RFColor.accent)
                Text("워치에서 시작하세요")
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.fg)
            }
            Text("Apple Watch RepFlow 앱에서 \(exercise.displayName)을 선택하면 모션 센서가 자동으로 카운트합니다. 햅틱으로 매 횟수를 확인하세요.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rfCard()
    }

    private var modesBlock: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("MODES").rfSectionHeader()

            VStack(spacing: 1) {
                ForEach([WorkoutMode.freeCount, .emom, .tabata, .amrap], id: \.self) { mode in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.rfTitleMd)
                                .foregroundStyle(RFColor.fg)
                            Text(modeBlurb(mode))
                                .font(.rfCaptionSm)
                                .foregroundStyle(RFColor.fgSubtle)
                        }
                        Spacer()
                    }
                    .padding(RFSpace.md)
                }
            }
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: RFRadius.md).stroke(RFColor.border, lineWidth: 1))
        }
    }

    private func modeBlurb(_ mode: WorkoutMode) -> String {
        switch mode {
        case .freeCount: return "최대 횟수 자유 카운트"
        case .emom: return "매 분 정해진 개수"
        case .tabata: return "20s/10s × 8라운드"
        case .amrap: return "정해진 시간 안에 최대로"
        case .sets: return "정해진 세트 × 횟수"
        case .gtgQuick: return "GTG 즉석 알림"
        }
    }
}

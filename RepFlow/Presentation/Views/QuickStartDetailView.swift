import SwiftUI

struct QuickStartDetailView: View {
    let exercise: ExerciseKind

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 140)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 30))
                    .padding(.top, 20)

                Text(exercise.displayName)
                    .font(.title.bold())

                instructionCard

                modesGrid

                Spacer(minLength: 30)
            }
            .padding()
        }
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("워치에서 시작하세요", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.headline)
            Text("애플워치 RepFlow 앱에서 \(exercise.displayName)을 선택하면 모션 센서가 자동으로 카운트합니다. 햅틱으로 매 횟수를 확인하세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var modesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("운동 모드")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach([WorkoutMode.freeCount, .emom, .tabata, .amrap], id: \.self) { mode in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(modeBlurb(mode))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
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

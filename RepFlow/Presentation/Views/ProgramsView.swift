import SwiftUI

struct ProgramsView: View {

    private let programs: [IntervalProgram] = [
        .tabata(.pushUp),
        .tabata(.pullUp),
        .emom(.pushUp, reps: 10, rounds: 10),
        .emom(.pullUp, reps: 5, rounds: 8),
        .amrap(.pushUp, minutes: 5),
        .amrap(.pullUp, minutes: 3)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                RFColor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: RFSpace.md) {
                        Text("PRESETS")
                            .rfSectionHeader()
                            .padding(.top, RFSpace.sm)

                        VStack(spacing: 1) {
                            ForEach(programs) { p in
                                ProgramRow(program: p)
                                    .padding(RFSpace.md)
                            }
                        }
                        .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: RFRadius.md)
                                .stroke(RFColor.border, lineWidth: 1)
                        )

                        Text("프로그램은 워치에서 선택해 시작하세요. 인터벌은 워치 햅틱으로 안내됩니다.")
                            .font(.rfCaption)
                            .foregroundStyle(RFColor.fgMuted)
                            .padding(.top, RFSpace.sm)
                    }
                    .padding(.horizontal, RFSpace.lg)
                    .padding(.bottom, RFSpace.xxl)
                }
            }
            .navigationTitle("프로그램")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct ProgramRow: View {
    let program: IntervalProgram

    var body: some View {
        HStack(spacing: RFSpace.md) {
            Image(systemName: program.exercise.symbol)
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.accent)
                .frame(width: 32, height: 32)
                .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.fg)
                Text(detail)
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            }
            Spacer()
            Text(program.mode.displayName.uppercased())
                .rfChip()
        }
    }

    private var detail: String {
        switch program.mode {
        case .tabata: return "\(program.workSeconds)s on / \(program.restSeconds)s off · \(program.rounds) rounds"
        case .emom:   return "\(program.targetRepsPerRound ?? 0) reps × \(program.rounds) min"
        case .amrap:  return "\(program.workSeconds / 60) min · max reps"
        default:      return program.exercise.displayName
        }
    }
}

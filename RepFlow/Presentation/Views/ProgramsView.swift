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
            List {
                Section {
                    ForEach(programs) { program in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: program.exercise.symbol)
                                    .foregroundStyle(Color.accentColor)
                                Text(program.name)
                                    .font(.headline)
                            }
                            Text(detail(program))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("프리셋")
                } footer: {
                    Text("프로그램은 워치에서 선택해 시작하세요. 인터벌은 워치 햅틱으로 안내됩니다.")
                }
            }
            .navigationTitle("프로그램")
        }
    }

    private func detail(_ p: IntervalProgram) -> String {
        switch p.mode {
        case .tabata: return "운동 \(p.workSeconds)초 / 휴식 \(p.restSeconds)초 × \(p.rounds)"
        case .emom:   return "매 \(p.workSeconds)초 \(p.targetRepsPerRound ?? 0)개 × \(p.rounds)라운드"
        case .amrap:  return "\(p.workSeconds / 60)분 동안 최대 횟수"
        default:      return p.exercise.displayName
        }
    }
}

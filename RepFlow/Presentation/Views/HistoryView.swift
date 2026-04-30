import SwiftUI
import SwiftData

struct HistoryView: View {

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "기록이 없습니다",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("워치에서 운동을 시작하면 여기에 기록이 쌓입니다.")
                    )
                } else {
                    List {
                        ForEach(sessions) { s in
                            HistoryRow(session: s)
                        }
                    }
                }
            }
            .navigationTitle("기록")
        }
    }
}

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.exercise.symbol)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.exercise.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalReps) reps")
                    .font(.headline.monospacedDigit())
                if session.avgTempoSeconds > 0 {
                    Text(String(format: "%.1fs/rep", session.avgTempoSeconds))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

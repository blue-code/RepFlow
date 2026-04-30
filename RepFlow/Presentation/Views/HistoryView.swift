import SwiftUI
import SwiftData

struct HistoryView: View {

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ZStack {
                RFColor.bg.ignoresSafeArea()

                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("기록이 없습니다", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("워치에서 운동을 시작하면 여기에 쌓입니다.")
                            .foregroundStyle(RFColor.fgMuted)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(sessions) { s in
                                HistoryRow(session: s)
                                    .padding(.horizontal, RFSpace.lg)
                                    .padding(.vertical, RFSpace.md)
                            }
                        }
                        .background(RFColor.bgElevated)
                        .padding(.horizontal, RFSpace.lg)
                    }
                    .padding(.top, RFSpace.sm)
                }
            }
            .navigationTitle("기록")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: RFSpace.md) {
            Image(systemName: session.exercise.symbol)
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.accent)
                .frame(width: 32, height: 32)
                .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.exercise.displayName)
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.fg)
                Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalReps)")
                    .font(.rfMonoBody.bold())
                    .foregroundStyle(RFColor.fg)
                if session.avgTempoSeconds > 0 {
                    Text(String(format: "%.1fs/rep", session.avgTempoSeconds))
                        .font(.rfCaptionSm.monospacedDigit())
                        .foregroundStyle(RFColor.fgSubtle)
                }
            }
        }
    }
}

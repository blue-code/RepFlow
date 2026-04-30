import SwiftUI
import SwiftData

struct DashboardView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.displayName) private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \GTGDay.date, order: .reverse) private var gtgDays: [GTGDay]

    private var profile: UserProfile? { profiles.first }

    private var todayGTG: GTGDay? {
        let today = Date.now.startOfDay
        return gtgDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    gtgCard
                    quickStartGrid
                    recentSection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationTitle("RepFlow")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 흐름")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text("\(todayTotalReps)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("reps")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(sessions.count) 세션", systemImage: "flame.fill")
                if let profile {
                    Label("최고 푸시업 \(profile.pushUpBest)", systemImage: "trophy.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private var todayTotalReps: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return sessions
            .filter { $0.startedAt >= today }
            .reduce(0) { $0 + $1.totalReps }
            + (todayGTG?.completedReps ?? 0)
    }

    // MARK: - GTG

    private var gtgCard: some View {
        NavigationLink {
            GTGSettingsView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bolt.heart.fill")
                        .foregroundStyle(.orange)
                    Text("GTG 모드")
                        .font(.headline)
                    Spacer()
                    if profile?.gtgEnabled == true {
                        Text("ON")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    } else {
                        Text("OFF")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.gray.opacity(0.2), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Text("워치가 하루 종일 가벼운 푸시업/풀업을 알려줍니다.\n검증된 GTG 훈련법으로 진짜 진보가 시작됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                if let gtg = todayGTG {
                    ProgressView(value: gtg.progressRatio)
                        .tint(.orange)
                    Text("\(gtg.completedReps) / \(gtg.targetReps)개 완료")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick start

    private var quickStartGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("바로 시작")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ExerciseKind.allCases) { kind in
                    NavigationLink {
                        QuickStartDetailView(exercise: kind)
                    } label: {
                        QuickStartTile(kind: kind)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentSection: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("최근 세션")
                    .font(.headline)
                ForEach(sessions.prefix(3)) { s in
                    HistoryRow(session: s)
                }
            }
        }
    }
}

private struct QuickStartTile: View {
    let kind: ExerciseKind
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10))
            Text(kind.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("워치에서 시작")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

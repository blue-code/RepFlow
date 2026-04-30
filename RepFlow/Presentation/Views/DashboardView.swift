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
                VStack(alignment: .leading, spacing: RFSpace.xl) {
                    heroBlock
                    gtgBlock
                    quickStartBlock
                    recentBlock
                }
                .padding(.horizontal, RFSpace.lg)
                .padding(.bottom, RFSpace.xxl)
            }
            .background(RFColor.bg.ignoresSafeArea())
            .navigationTitle("RepFlow")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Hero (영웅 카운터)

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: RFSpace.sm) {
            Text("TODAY'S FLOW")
                .rfSectionHeader()

            HStack(alignment: .firstTextBaseline, spacing: RFSpace.sm) {
                Text("\(todayTotalReps)")
                    .font(.system(size: 64, weight: .heavy, design: .default))
                    .foregroundStyle(RFColor.fg)
                    .contentTransition(.numericText())
                Text("reps")
                    .font(.rfTitleLg)
                    .foregroundStyle(RFColor.fgMuted)
            }

            HStack(spacing: RFSpace.lg) {
                StatChip(value: "\(sessions.count)", label: "세션")
                if let profile {
                    StatChip(value: "\(profile.pushUpBest)", label: "푸시업 최고")
                    StatChip(value: "\(profile.pullUpBest)", label: "풀업 최고")
                }
            }
        }
        .padding(.top, RFSpace.lg)
    }

    private var todayTotalReps: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return sessions
            .filter { $0.startedAt >= today }
            .reduce(0) { $0 + $1.totalReps }
            + (todayGTG?.completedReps ?? 0)
    }

    // MARK: - GTG

    @ViewBuilder
    private var gtgBlock: some View {
        NavigationLink {
            GTGSettingsView()
        } label: {
            VStack(alignment: .leading, spacing: RFSpace.md) {
                HStack(spacing: RFSpace.sm) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.rfTitleMd)
                        .foregroundStyle(RFColor.accent)
                    Text("GTG MODE")
                        .rfSectionHeader()
                    Spacer()
                    Text(profile?.gtgEnabled == true ? "ON" : "OFF")
                        .rfChip(profile?.gtgEnabled == true ? RFColor.success : RFColor.fgMuted)
                }

                Text("워치가 하루 종일 가벼운 푸시업/풀업을 알려줍니다. 검증된 GTG 훈련법으로 진짜 진보가 시작됩니다.")
                    .font(.rfCaption)
                    .foregroundStyle(RFColor.fgMuted)
                    .multilineTextAlignment(.leading)

                if let gtg = todayGTG {
                    VStack(alignment: .leading, spacing: RFSpace.xs) {
                        ProgressView(value: gtg.progressRatio)
                            .tint(RFColor.accent)
                        HStack {
                            Text("\(gtg.completedReps) / \(gtg.targetReps)")
                                .font(.rfMonoBody)
                                .foregroundStyle(RFColor.fg)
                            Spacer()
                            Text("오늘")
                                .font(.rfCaptionSm)
                                .foregroundStyle(RFColor.fgSubtle)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rfCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick start

    private var quickStartBlock: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("QUICK START")
                .rfSectionHeader()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: RFSpace.md), GridItem(.flexible())], spacing: RFSpace.md) {
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
    private var recentBlock: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: RFSpace.md) {
                Text("RECENT")
                    .rfSectionHeader()

                VStack(spacing: 1) {
                    ForEach(sessions.prefix(4)) { s in
                        HistoryRow(session: s)
                            .padding(.vertical, RFSpace.sm)
                            .padding(.horizontal, RFSpace.md)
                    }
                }
                .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: RFRadius.md)
                        .stroke(RFColor.border, lineWidth: 1)
                )
            }
        }
    }
}

private struct StatChip: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.rfMonoBody)
                .foregroundStyle(RFColor.fg)
            Text(label)
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgSubtle)
        }
    }
}

private struct QuickStartTile: View {
    let kind: ExerciseKind

    var body: some View {
        HStack(spacing: RFSpace.md) {
            Image(systemName: kind.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RFColor.accent)
                .frame(width: 36, height: 36)
                .background(RFColor.accentSoft, in: RoundedRectangle(cornerRadius: RFRadius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.fg)
                Text("워치에서 시작")
                    .font(.rfCaptionSm)
                    .foregroundStyle(RFColor.fgSubtle)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RFColor.fgSubtle)
        }
        .padding(RFSpace.md)
        .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: RFRadius.md)
                .stroke(RFColor.border, lineWidth: 1)
        )
    }
}

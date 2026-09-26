import SwiftUI
import SwiftData

/// 「푸시업 100」 허브. 앱의 히어로 화면이다.
///
/// 인터벌 프리셋은 여기 있었지만 아래로 내렸다 — 매니아용 도구이지 사용자가 매일 여는 목적이 아니다.
struct ProgramsView: View {

    @Query private var enrollments: [ProgramEnrollment]

    private var enrollment: ProgramEnrollment? { enrollments.first }

    /// 종목은 `ExerciseKind.visibleCases` 하나로 통제한다 — 배열을 직접 지우지 않는다.
    private var intervals: [IntervalProgram] {
        [
            .tabata(.pushUp),
            .emom(.pushUp, reps: 10, rounds: 10),
            .amrap(.pushUp, minutes: 5),
            .tabata(.pullUp),
            .emom(.pullUp, reps: 5, rounds: 8),
            .amrap(.pullUp, minutes: 3)
        ].filter { ExerciseKind.visibleCases.contains($0.exercise) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RFColor.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: RFSpace.xl) {
                        if let enrollment {
                            ProgramProgressCard(enrollment: enrollment)
                        } else {
                            startCard
                        }
                        intervalSection
                    }
                    .padding(.horizontal, RFSpace.lg)
                    .padding(.top, RFSpace.sm)
                    .padding(.bottom, RFSpace.xxxl + RFSpace.xl)
                }
            }
            .navigationTitle("푸시업 100")
            .toolbarColorScheme(.dark, for: .navigationBar)
            // 워치가 폰 없이 완주할 수 있어야 하므로, 다음 세션을 미리 밀어둔다.
            // applicationContext 라서 워치가 꺼져 있었어도 다음 활성화 때 받는다.
            .onAppear { pushSessionToWatch() }
            .onChange(of: enrollment?.currentWeek) { _, _ in pushSessionToWatch() }
            .onChange(of: enrollment?.sessionIndexInWeek) { _, _ in pushSessionToWatch() }
            .onChange(of: enrollment?.trainingMax) { _, _ in pushSessionToWatch() }
        }
    }

    private func pushSessionToWatch() {
        guard let enrollment else { return }
        PhoneSessionService.shared.sendProgramSession(
            enrollment.nextSession,
            restBonusSeconds: enrollment.restBonusSeconds
        )
    }

    // MARK: - 시작 전

    private var startCard: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("한 세트 100개까지")
                .font(.rfDisplayMd)
                .foregroundStyle(RFColor.fg)
            Text("먼저 지금 몇 개를 할 수 있는지 잰다. 그 숫자에서 모든 세트 목표가 나오고, 주 3회씩 올라간다.")
                .font(.rfBody)
                .foregroundStyle(RFColor.fgMuted)

            NavigationLink {
                MaxTestView()
            } label: {
                Text("최대 측정하기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RFPrimaryButton())
            .padding(.top, RFSpace.xs)
        }
        .rfCard()
    }

    // MARK: - 인터벌 (강등)

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            Text("인터벌 트레이너")
                .rfSectionHeader()

            VStack(spacing: 1) {
                ForEach(intervals) { program in
                    IntervalRow(program: program)
                        .padding(RFSpace.md)
                }
            }
            .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: RFRadius.md)
                    .stroke(RFColor.border, lineWidth: 1)
            )

            Text("인터벌은 워치에서 선택해 시작하세요. 라운드 전환은 워치 햅틱으로 안내됩니다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
    }
}

// MARK: - 진행 카드

private struct ProgramProgressCard: View {

    @Bindable var enrollment: ProgramEnrollment
    /// 스크린샷 자동화에서 세션 화면을 바로 열기 위한 딥링크.
    @State private var autoOpenSession = MockDataLoader.route == .session

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpace.lg) {
            header

            if enrollment.hasGraduated {
                graduated
            } else if let session = enrollment.nextSession {
                nextSessionCard(session)
            } else {
                weekDone
            }

            stats
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(enrollment.trainingMax)")
                    .font(.rfDisplayLg)
                    .monospacedDigit()
                    .foregroundStyle(RFColor.accent)
                Text("현재 훈련최대")
                    .font(.rfCaption)
                    .foregroundStyle(RFColor.fgMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: RFSpace.xs) {
                Text("\(enrollment.currentWeek)주차")
                    .rfChip()
                if enrollment.isRetestWeek {
                    Text("재측정").rfChip(RFColor.warning)
                } else if enrollment.isDeloadWeek {
                    Text("디로드").rfChip(RFColor.success)
                }
            }
        }
    }

    private func nextSessionCard(_ session: ProgramSession) -> some View {
        VStack(alignment: .leading, spacing: RFSpace.md) {
            HStack {
                Text(session.isRetest ? "재측정 — 한 세트 최대" : "\(session.kind.displayName) 세션")
                    .font(.rfTitleMd)
                    .foregroundStyle(RFColor.fg)
                Spacer()
                Text("\(enrollment.sessionIndexInWeek + 1) / \(enrollment.sessionsThisWeek)")
                    .font(.rfMonoBody)
                    .foregroundStyle(RFColor.fgSubtle)
            }

            HStack(spacing: RFSpace.sm) {
                ForEach(session.sets) { set in
                    VStack(spacing: 2) {
                        Text("\(set.reps)")
                            .font(.rfMonoBody)
                            .foregroundStyle(set.isAMRAP ? RFColor.accent : RFColor.fg)
                        if set.isAMRAP {
                            Text("+")
                                .font(.rfCaptionSm)
                                .foregroundStyle(RFColor.accent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RFSpace.sm)
                    .background(RFColor.bgSubtle, in: RoundedRectangle(cornerRadius: RFRadius.sm))
                }
            }

            Text(session.isRetest
                 ? "이 결과가 새 훈련최대가 됩니다."
                 : "세트 간 휴식 \(session.restSeconds + enrollment.restBonusSeconds)초 · 마지막은 가능한 만큼")
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgSubtle)

            NavigationLink {
                if session.isRetest {
                    MaxTestView(isRetest: true)
                } else {
                    ProgramSessionView(enrollment: enrollment, session: session)
                }
            } label: {
                Text(session.isRetest ? "재측정 시작" : "세션 시작")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(RFPrimaryButton())
            .navigationDestination(isPresented: $autoOpenSession) {
                ProgramSessionView(enrollment: enrollment, session: session)
            }
        }
        .rfCard()
    }

    private var weekDone: some View {
        VStack(spacing: RFSpace.sm) {
            Text("이번 주 완료")
                .font(.rfTitleMd)
                .foregroundStyle(RFColor.success)
            Text("하루 이상 쉬고 다음 주를 시작하세요.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity)
        .rfCard()
    }

    private var graduated: some View {
        VStack(spacing: RFSpace.sm) {
            Text("100개 달성")
                .font(.rfDisplayMd)
                .foregroundStyle(RFColor.accent)
            Text("한 세트 \(enrollment.bestSingleSet)개. 목표를 넘겼습니다.")
                .font(.rfCaption)
                .foregroundStyle(RFColor.fgMuted)
        }
        .frame(maxWidth: .infinity)
        .rfCard()
    }

    private var stats: some View {
        HStack(spacing: RFSpace.sm) {
            statChip(value: "\(enrollment.bestSingleSet)", label: "한 세트 최고")
            statChip(value: "\(enrollment.weeklyTargetVolume)", label: "이번 주 목표")
            statChip(
                value: enrollment.estimatedWeeksTo100.map { "\($0)주" } ?? "—",
                label: "100까지"
            )
        }
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.rfMonoLg)
                .foregroundStyle(RFColor.fg)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.rfCaptionSm)
                .foregroundStyle(RFColor.fgSubtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RFSpace.md)
        .background(RFColor.bgElevated, in: RoundedRectangle(cornerRadius: RFRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: RFRadius.md)
                .stroke(RFColor.border, lineWidth: 1)
        )
    }
}

// MARK: - 인터벌 행

private struct IntervalRow: View {
    let program: IntervalProgram

    var body: some View {
        HStack(spacing: RFSpace.md) {
            program.exercise.pictogram
                .resizable()
                .scaledToFit()
                .padding(3)
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

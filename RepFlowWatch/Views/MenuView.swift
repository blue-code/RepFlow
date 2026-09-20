import SwiftUI

struct MenuView: View {
    @Environment(WatchCoordinator.self) private var coord
    @State private var showAdvanced = false

    private var autoDetectEnabled: Bool { AutoDetectSettings.isEnabled() }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("RepFlow")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(ExerciseKind.allCases) { kind in
                    NavigationGroup(kind: kind)
                }

                Divider().padding(.vertical, 4)

                Button {
                    coord.haptic(.click)
                    coord.startInterval(program: .tabata(.pushUp))
                } label: {
                    Label("타바타 푸시업", systemImage: "timer")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    coord.haptic(.click)
                    coord.startInterval(program: .emom(.pullUp, reps: 5, rounds: 8))
                } label: {
                    Label("EMOM 풀업 5×8", systemImage: "metronome")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().padding(.vertical, 4)

                Button {
                    coord.haptic(.click)
                    showAdvanced.toggle()
                } label: {
                    HStack {
                        Text("고급")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    if autoDetectEnabled {
                        Text("자동 감지 캘리브레이션")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(ExerciseKind.allCases) { kind in
                            Button {
                                coord.haptic(.click)
                                coord.openCalibration(exercise: kind)
                            } label: {
                                Label(kind.displayName, systemImage: "scope")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        Text("자동 감지는 폰 설정에서 켤 수 있어요 (실험적)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct NavigationGroup: View {
    let kind: ExerciseKind
    @Environment(WatchCoordinator.self) private var coord

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 4) {
            Button {
                coord.haptic(.click)
                expanded.toggle()
            } label: {
                HStack {
                    kind.pictogram
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(kind.displayName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

            if expanded {
                Button("프리 카운트") {
                    coord.haptic(.start)
                    coord.start(exercise: kind, mode: .freeCount)
                }
                .font(.caption)
                Button("AMRAP 5분") {
                    coord.haptic(.start)
                    coord.startInterval(program: .amrap(kind, minutes: 5))
                }
                .font(.caption)
            }
        }
    }
}

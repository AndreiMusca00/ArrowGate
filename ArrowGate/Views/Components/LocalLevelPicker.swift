import SwiftUI

/// A local-only launcher for reviewing candidate levels before they are published.
struct LocalLevelPicker: View {
    let levels: [LevelDefinition]
    let select: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 4
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(levels.sorted { $0.id < $1.id }) { level in
                        levelButton(level)
                    }
                }
                .padding(18)
            }
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Test Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(GameStyle.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
    }

    private func levelButton(_ level: LevelDefinition) -> some View {
        Button {
            select(level.id)
        } label: {
            VStack(spacing: 3) {
                Text("\(level.id)")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(GameStyle.ink)

                Text("\(level.arrows.count) arrows")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(GameStyle.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(difficultyColor(level.difficulty).opacity(0.72), lineWidth: 1.5)
            }
            .shadow(color: difficultyColor(level.difficulty).opacity(0.09), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level \(level.id), \(level.arrows.count) arrows, \((level.difficulty ?? .normal).title)")
        .accessibilityIdentifier("previewLevel\(level.id)")
    }

    private func difficultyColor(_ difficulty: LevelDifficulty?) -> Color {
        switch difficulty {
        case .hard:
            return Color.orange
        case .veryHard:
            return Color(red: 0.76, green: 0.035, blue: 0.10)
        case .nightmare:
            return Color(red: 0.48, green: 0.07, blue: 0.61)
        default:
            return GameStyle.accent
        }
    }
}

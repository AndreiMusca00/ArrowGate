import SwiftUI

/// Renders a catalog-defined collectible without knowing the chapter or artwork.
/// Every completed level reveals its matching transparent object; missing objects
/// remain visible as real gaps in the assembled figure.
struct ChapterAssemblyFigure: View {
    let assembly: ChapterAssemblyDefinition
    let revealedPieces: Set<Int>
    let revealsFinalArtwork: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                if revealsFinalArtwork, let finalArtwork = assembly.finalArtwork {
                    ContentAssetRegistry.image(named: finalArtwork)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: width, height: height)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    ForEach(Array(assembly.placements.enumerated()), id: \.offset) { index, placement in
                        if revealedPieces.contains(index) {
                            ContentAssetRegistry.image(named: pieceAssetName(index))
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: width * placement.scale,
                                       height: height * placement.scale)
                                .position(x: width * placement.x,
                                          y: height * placement.y)
                                .transition(.scale(scale: 0.25).combined(with: .opacity))
                                .zIndex(Double(index))
                        }
                    }
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(assembly.aspectRatio, contentMode: .fit)
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: revealedPieces.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assembled figure, \(revealedPieces.count) of \(assembly.pieceCount) pieces")
    }

    private func pieceAssetName(_ index: Int) -> String {
        assembly.assetPrefix + String(format: "%02d", index + 1)
    }

}


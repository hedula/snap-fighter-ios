import MapKit
import SwiftUI

struct BattleArenaBackdropView: View {
    let coordinate: CLLocationCoordinate2D?
    let lookAroundSnapshot: UIImage?
    let isUsingLiveArena: Bool

    var body: some View {
        ZStack {
            if let lookAroundSnapshot, isUsingLiveArena {
                lookAroundBackdrop(image: lookAroundSnapshot)
            } else if isUsingLiveArena, let coordinate {
                Map(
                    position: .constant(
                        .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                            )
                        )
                    ),
                    interactionModes: []
                )
                .mapStyle(.imagery(elevation: .realistic))
                .mapControlVisibility(.hidden)
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .saturation(0.95)
            } else {
                fallbackBackdrop
            }

            atmosphericOverlay
            tacticalGrid
        }
    }

    private var fallbackBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.16, green: 0.08, blue: 0.10),
                    Color(red: 0.04, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    .orange.opacity(0.32),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    .cyan.opacity(0.24),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }

    private func lookAroundBackdrop(image: UIImage) -> some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.08),
                            .black.opacity(0.18),
                            .black.opacity(0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
        .saturation(0.88)
        .contrast(1.04)
    }

    private var atmosphericOverlay: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.12),
                .black.opacity(0.45),
                .black.opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var tacticalGrid: some View {
        GeometryReader { proxy in
            Path { path in
                let spacing: CGFloat = 38
                let width = proxy.size.width
                let height = proxy.size.height

                stride(from: 0, through: width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                stride(from: 0, through: height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(.white.opacity(0.05), lineWidth: 0.6)
        }
        .ignoresSafeArea()
    }
}

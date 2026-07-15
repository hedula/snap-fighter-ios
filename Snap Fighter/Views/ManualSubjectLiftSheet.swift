import SwiftUI
import VisionKit

struct ManualSubjectLiftSheet: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var status: Status = .analyzing

    private enum Status {
        case analyzing
        case ready
        case selecting
        case noSubject
        case failed

        var title: String {
            switch self {
            case .analyzing: return "正在準備主體選取"
            case .ready: return "點一下要保留的物件"
            case .selecting: return "正在提取透明主體"
            case .noSubject: return "這個位置沒有可用主體"
            case .failed: return "目前無法使用手動去背"
            }
        }

        var detail: String {
            switch self {
            case .analyzing: return "VisionKit 正在分析照片內容。"
            case .ready: return "點擊物件中央；系統會顯示辨識到的完整輪廓。"
            case .selecting: return "請稍候，不需要再次點擊。"
            case .noSubject: return "請改點物件中央，或返回後重新拍攝。"
            case .failed: return "此裝置或照片暫時無法建立主體遮罩。"
            }
        }

        var symbol: String {
            switch self {
            case .analyzing, .selecting: return "wand.and.rays"
            case .ready: return "hand.tap.fill"
            case .noSubject: return "scope"
            case .failed: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            Image("ArcaneArena")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            RPGTheme.midnight.opacity(0.9)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 20
                let contentWidth = max(0, proxy.size.width - (horizontalPadding * 2))
                let compactHeight = proxy.size.height < 700
                let imageHeight = min(
                    compactHeight ? 270 : 330,
                    max(240, proxy.size.height - 360)
                )

                VStack(spacing: compactHeight ? 10 : 12) {
                    VStack(spacing: 6) {
                        Text("SUBJECT LIFT")
                            .font(.caption.weight(.black))
                            .tracking(2)
                            .foregroundStyle(RPGTheme.gold)
                        Text("手動選取主體")
                            .font(.system(size: compactHeight ? 24 : 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("使用 iPhone 內建的照片主體提取能力")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RPGTheme.mist)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    VisionKitSubjectPicker(
                        image: image,
                        onReady: { hasSubjects in
                            status = hasSubjects ? .ready : .noSubject
                        },
                        onSelecting: {
                            status = .selecting
                        },
                        onNoSubject: {
                            status = .noSubject
                        },
                        onComplete: onComplete,
                        onFailure: {
                            status = .failed
                        }
                    )
                    .frame(
                        width: contentWidth,
                        height: imageHeight
                    )
                    .background(RPGTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(RPGTheme.goldDark, lineWidth: 1.5)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: status.symbol)
                            .font(.title3.weight(.black))
                            .foregroundStyle(RPGTheme.gold)
                            .frame(width: 42, height: 42)
                            .background(RPGTheme.panelRaised)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(status.title)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(.white)
                            Text(status.detail)
                                .font(.caption)
                                .foregroundStyle(RPGTheme.mist)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(RPGTheme.panel.opacity(0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(RPGTheme.goldDark, lineWidth: 1)
                    }

                    Button(action: onCancel) {
                        Text("稍後處理")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(RPGTheme.parchment)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(RPGTheme.panelRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
                .frame(width: contentWidth, alignment: .top)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, compactHeight ? 12 : 18)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct VisionKitSubjectPicker: UIViewRepresentable {
    let image: UIImage
    let onReady: (Bool) -> Void
    let onSelecting: () -> Void
    let onNoSubject: () -> Void
    let onComplete: (UIImage) -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor(RPGTheme.panel)
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        let interaction = context.coordinator.interaction
        interaction.preferredInteractionTypes = [.imageSubject]
        imageView.addInteraction(interaction)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTap(_:))
        )
        imageView.addGestureRecognizer(tap)

        context.coordinator.imageView = imageView
        context.coordinator.startAnalysis(image: image)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: VisionKitSubjectPicker
        let interaction = ImageAnalysisInteraction()
        weak var imageView: UIImageView?
        private var isReady = false

        init(parent: VisionKitSubjectPicker) {
            self.parent = parent
        }

        func startAnalysis(image: UIImage) {
            guard ImageAnalyzer.isSupported else {
                parent.onFailure()
                return
            }

            Task { @MainActor in
                do {
                    let analyzer = ImageAnalyzer()
                    let configuration = ImageAnalyzer.Configuration([.visualLookUp])
                    interaction.analysis = try await analyzer.analyze(
                        image,
                        orientation: image.imageOrientation,
                        configuration: configuration
                    )
                    let subjects = await interaction.subjects
                    isReady = true
                    parent.onReady(!subjects.isEmpty)
                } catch {
                    parent.onFailure()
                }
            }
        }

        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard isReady, let imageView else {
                parent.onFailure()
                return
            }

            let point = gesture.location(in: imageView)
            parent.onSelecting()

            Task { @MainActor in
                guard let subject = await interaction.subject(at: point) else {
                    parent.onNoSubject()
                    return
                }

                interaction.highlightedSubjects = [subject]
                do {
                    parent.onComplete(try await subject.image)
                } catch {
                    parent.onFailure()
                }
            }
        }
    }
}

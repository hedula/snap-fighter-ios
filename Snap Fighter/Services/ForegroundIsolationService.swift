import UIKit
import Vision
import CoreImage
import ImageIO

actor ForegroundIsolationService {
    static let shared = ForegroundIsolationService()

    private let ciContext = CIContext()

    func isolateSubject(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)

        do {
            try requestHandler.perform([request])
            guard
                let observation = request.results?.first,
                !observation.allInstances.isEmpty
            else {
                return nil
            }

            let maskedPixelBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: requestHandler,
                croppedToInstancesExtent: false
            )

            let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            guard let resultCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }

            return UIImage(cgImage: resultCGImage, scale: image.scale, orientation: image.imageOrientation)
        } catch {
            return nil
        }
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

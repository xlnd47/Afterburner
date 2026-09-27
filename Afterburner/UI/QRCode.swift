import CoreImage
import UIKit

enum QRCode {
    /// Callers should render once and keep the result — CoreImage
    /// rasterization is far too expensive to repeat on each SwiftUI update.
    static func make(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        // Medium error correction — enough tolerance for a photo taken of a
        // TV screen at an angle without inflating the module count.
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        // CIQRCodeGenerator emits roughly one pixel per module (~25x25pt), so
        // it has to be scaled up here. Scaling at render time instead would
        // resample and blur the modules; callers should pair the result with
        // .interpolation(.none) to keep the enlarged result crisp.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

import Foundation
import UIKit

/// A photo ready for `POST /media`.
struct EncodedPhoto {
    let data: Data
    let mimeType: String
    let fileName: String
}

/// Project's upload limit is 2 MiB, JPEG or PNG. A JPEG or PNG within the limit is sent as it is; anything
/// else (larger, HEIC, WebP...) is scaled to 2048 px and re-encoded as JPEG at falling quality until it fits
/// (same steps as Android `AndroidPhotoEncoder`).
enum PhotoEncoder {
    static let maxBytes = 2 * 1024 * 1024
    private static let maxSide: CGFloat = 2048
    private static let qualities: [CGFloat] = [0.85, 0.70, 0.55, 0.40]

    static func encode(_ data: Data) throws -> EncodedPhoto {
        let isJPEG = data.starts(with: [0xFF, 0xD8, 0xFF])
        let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
        if (isJPEG || isPNG) && data.count <= maxBytes {
            return EncodedPhoto(data: data, mimeType: isPNG ? "image/png" : "image/jpeg", fileName: isPNG ? "photo.png" : "photo.jpg")
        }
        guard let image = UIImage(data: data) else {
            throw APIError(message: "The app couldn't read this photo. Choose another one.")
        }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in qualities {
            if let jpeg = scaled.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return EncodedPhoto(data: jpeg, mimeType: "image/jpeg", fileName: "photo.jpg")
            }
        }
        throw APIError(message: "This photo is too large. Choose a smaller one.")
    }
}

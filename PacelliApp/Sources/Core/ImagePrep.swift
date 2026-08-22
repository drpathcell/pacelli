import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turning whatever the camera or the library hands over into the one shape
/// Pacelli stores.
///
/// Three things happen here and all three matter:
///
///  1. **Location data comes off.** A photo of your own kitchen carries your
///     home's coordinates in EXIF. Going through `CGImageSourceCreateThumbnail…`
///     produces a bare `CGImage` with no metadata attached at all, so the strip
///     is a property of the pipeline rather than a list of tags to remember.
///  2. **HEIC becomes JPEG.** Everything downstream — the thumbnail, the
///     assistant's `imageBase64`, the export — assumes one format.
///  3. **It gets smaller.** 2048px on the long edge at q0.8 is roughly 400 KB.
///     For a photo of a stopcock that is far more than enough, and it keeps
///     encryption, upload and the household's storage bill small.
enum ImagePrep {

    /// What the app keeps and uploads.
    static let originalMaxPixels = 2048
    static let originalQuality: CGFloat = 0.8

    /// What rides inside the Firestore document. Small enough that a page of
    /// fifty is under half a megabyte, big enough to recognise a thing in.
    static let thumbnailMaxPixels = 128
    static let thumbnailQuality: CGFloat = 0.6

    struct Prepared: Sendable {
        let jpeg: Data
        let thumbnailJPEG: Data
        let width: Int
        let height: Int
    }

    enum PrepError: Error, LocalizedError {
        case notAnImage
        case couldNotEncode

        var errorDescription: String? {
            switch self {
            case .notAnImage:
                return String(localized: "That file isn't an image Pacelli can read.")
            case .couldNotEncode:
                return String(localized: "Couldn't prepare that photo.")
            }
        }
    }

    /// Downscale, strip, re-encode, and make the thumbnail in the same pass.
    static func prepare(_ data: Data) throws -> Prepared {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { throw PrepError.notAnImage }

        let full = try scaled(source, maxPixels: originalMaxPixels)
        let thumb = try scaled(source, maxPixels: thumbnailMaxPixels)

        return Prepared(
            jpeg: try jpegData(full, quality: originalQuality),
            thumbnailJPEG: try jpegData(thumb, quality: thumbnailQuality),
            width: full.width,
            height: full.height)
    }

    private static func scaled(_ source: CGImageSource, maxPixels: Int) throws -> CGImage {
        // `…FromImageAlways` because an embedded thumbnail, where one exists,
        // is whatever size the camera felt like and is not always the right
        // orientation. `…TransformAlways` applies the EXIF orientation to the
        // pixels, which is the only way a stripped image still looks right.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary)
        else { throw PrepError.couldNotEncode }
        return image
    }

    private static func jpegData(_ image: CGImage, quality: CGFloat) throws -> Data {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw PrepError.couldNotEncode }

        // Only the compression setting is passed. Nothing carries over from the
        // source, which is the point: no GPS, no timestamp, no device name.
        CGImageDestinationAddImage(
            dest, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)

        guard CGImageDestinationFinalize(dest) else { throw PrepError.couldNotEncode }
        return out as Data
    }
}

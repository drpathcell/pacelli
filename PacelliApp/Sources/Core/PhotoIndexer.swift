import Foundation
import Vision

/// Reading a photo so it can be found again by typing.
///
/// Runs entirely on the device, which is not a performance choice — it is the
/// only arrangement compatible with the rest of Pacelli. The words in a picture
/// of a boiler plate are as private as the picture, so they are extracted here,
/// encrypted with the household key, and stored as ciphertext like every other
/// piece of text in the app. Nothing is uploaded to be read.
///
/// What it is good at: printed text, labels, serial numbers, receipts, the
/// front of a coffee bag. What it is not: handwriting, and anything at an
/// angle in bad light. The UI never promises otherwise — photos simply appear
/// in the search results that already exist, and a result that matched on
/// recognised text shows that text, so people learn what it can read by
/// watching it work.
enum PhotoIndexer {

    struct Index: Sendable {
        let text: String
        /// `[{"label":"coffee","confidence":0.82}, …]`, ready to encrypt.
        let labelsJSON: String?

        var isEmpty: Bool { text.isEmpty && labelsJSON == nil }
    }

    /// Labels below this are noise — Vision will confidently offer a dozen
    /// near-zero guesses for a photo of a wall.
    private static let minimumConfidence: Float = 0.25
    private static let maximumLabels = 10

    /// Best-effort by design. A photo that cannot be read is still a photo,
    /// so every failure here returns an empty index rather than throwing.
    static func index(jpeg: Data) async -> Index {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return Index(text: "", labelsJSON: nil) }

        async let text = recogniseText(image)
        async let labels = classify(image)
        return Index(text: await text, labelsJSON: await labels)
    }

    private static func recogniseText(_ image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: " "))
            }
            // `.accurate` because this runs once, at import, on one photo —
            // there is no live camera feed to keep up with, and the whole value
            // is in reading a serial number correctly the first time.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private static func classify(_ image: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let picked = (request.results as? [VNClassificationObservation] ?? [])
                    .filter { $0.confidence >= minimumConfidence }
                    .prefix(maximumLabels)
                    .map { ["label": $0.identifier, "confidence": Double($0.confidence)] }

                guard !picked.isEmpty,
                      let data = try? JSONSerialization.data(withJSONObject: Array(picked)),
                      let json = String(data: data, encoding: .utf8)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: json)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

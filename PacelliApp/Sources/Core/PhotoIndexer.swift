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

    // Vision is not either/or: when a request fails, `perform` calls that
    // request's completion handler with the error AND rethrows. Both halves of
    // a do/catch therefore run, and a `CheckedContinuation` resumed from both
    // traps the process — EXC_BREAKPOINT in `CheckedContinuation.resume`, with
    // nothing in the log naming Vision. It cost the 1.8.0 screenshot capture on
    // 2026-08-23, and the photo E2E could not have caught it: `flow_photo_01`
    // ends the moment the thumbnail appears, while indexing is still running,
    // and `flow_photo_02` opens with `stopApp`.
    //
    // There is no continuation here any more. `perform` is synchronous and
    // leaves its output on the request, so the results are simply read after it
    // returns and a throw means an empty index. A shape that cannot be resumed
    // twice is worth more than a guard against resuming twice.

    private static func recogniseText(_ image: CGImage) async -> String {
        let request = VNRecognizeTextRequest()
        // `.accurate` because this runs once, at import, on one photo —
        // there is no live camera feed to keep up with, and the whole value
        // is in reading a serial number correctly the first time.
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }

    private static func classify(_ image: CGImage) async -> String? {
        let request = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let picked = (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .prefix(maximumLabels)
            .map { ["label": $0.identifier, "confidence": Double($0.confidence)] }

        guard !picked.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: Array(picked)),
              let json = String(data: data, encoding: .utf8)
        else { return nil }

        return json
    }
}

import Foundation
import ImageIO
import Vision

struct ImageOCRService {
  static let maxInputBytes = 8 * 1024 * 1024

  func recognizeText(in data: Data) async -> String? {
    guard data.count <= Self.maxInputBytes else {
      return nil
    }

    return await Task.detached(priority: .utility) {
      guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        return nil
      }

      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true

      do {
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
      } catch {
        return nil
      }

      let text = request.results?
        .compactMap { $0.topCandidates(1).first?.string }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      guard let text, !text.isEmpty else {
        return nil
      }
      return text
    }.value
  }
}

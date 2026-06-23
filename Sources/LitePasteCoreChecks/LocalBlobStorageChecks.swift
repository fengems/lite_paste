import Foundation
import LitePasteCore

func checkLocalBlobStorage() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteBlobChecks") { directory in
      let storage = LocalBlobStorage(directory: directory)
      let snapshot = try storage.snapshot(
        data: Data("blob".utf8),
        pasteboardType: "public.data",
        preferredExtension: "bin",
        displayOrder: 0
      )

      guard let path = snapshot.externalFilePath else {
        fatalError("Blob snapshot should include external file path")
      }

      expect(
        FileManager.default.fileExists(atPath: path), "Blob storage should write external file")
      storage.removeExternalFiles(in: [snapshot])
      expect(
        !FileManager.default.fileExists(atPath: path), "Blob storage should remove external file")
    }
  } catch {
    fatalError("Local blob storage check failed: \(error)")
  }
}

import Combine
import Foundation

@MainActor
public final class AppSettingsStore: ObservableObject {
  public static let shared = AppSettingsStore()

  @Published public private(set) var settings: AppSettings {
    didSet {
      save()
    }
  }

  private let url: URL

  public init(url: URL = AppPaths.settingsURL) {
    self.url = url
    self.settings = Self.load(from: url)
  }

  public func update(_ mutate: (inout AppSettings) -> Void) {
    var nextSettings = settings
    mutate(&nextSettings)
    nextSettings.normalize()
    settings = nextSettings
  }

  public func reload() {
    settings = Self.load(from: url)
  }

  public var settingsPublisher: Published<AppSettings>.Publisher {
    $settings
  }

  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try JSONEncoder.litePaste.encode(settings)
      try data.write(to: url, options: .atomic)
    } catch {
      assertionFailure("Unable to save settings: \(error)")
    }
  }

  private static func load(from url: URL) -> AppSettings {
    guard let data = try? Data(contentsOf: url),
          let settings = try? JSONDecoder.litePaste.decode(AppSettings.self, from: data) else {
      return AppSettings()
    }

    return settings
  }
}

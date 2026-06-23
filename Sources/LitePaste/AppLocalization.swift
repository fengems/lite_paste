import Foundation
import LitePasteCore

enum AppText {
  private nonisolated(unsafe) static var languageSetting: AppLanguage = .system

  static func updateInterfaceLanguage(_ language: AppLanguage) {
    languageSetting = language
  }

  static var currentLanguage: AppLanguage {
    guard languageSetting == .system else {
      return languageSetting
    }

    let preferredLanguage = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
    if preferredLanguage.hasPrefix("zh-hant") ||
      preferredLanguage.hasPrefix("zh-tw") ||
      preferredLanguage.hasPrefix("zh-hk") ||
      preferredLanguage.hasPrefix("zh-mo") {
      return .zhHant
    }
    if preferredLanguage.hasPrefix("zh") {
      return .zhHans
    }
    if preferredLanguage.hasPrefix("ja") {
      return .ja
    }
    if preferredLanguage.hasPrefix("ko") {
      return .ko
    }
    return .en
  }

  static func value(_ chinese: String, _ english: String) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      chinese
    case .zhHant:
      translated(chinese, for: .zhHant) ?? chinese
    case .ja:
      translated(chinese, for: .ja) ?? english
    case .ko:
      translated(chinese, for: .ko) ?? english
    case .en:
      english
    }
  }

  static func itemCount(_ count: Int) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      "\(count) 条"
    case .zhHant:
      "\(count) 筆"
    case .ja:
      "\(count) 件"
    case .ko:
      "\(count)개"
    case .en:
      "\(count) items"
    }
  }

  static func localized(
    zhHans: String,
    zhHant: String,
    ja: String,
    ko: String,
    en: String
  ) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      zhHans
    case .zhHant:
      zhHant
    case .ja:
      ja
    case .ko:
      ko
    case .en:
      en
    }
  }
}

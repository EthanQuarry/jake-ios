#if canImport(SwiftUI)
  import Foundation
  import SwiftUI

  #if canImport(UIKit)
    import UIKit
  #elseif canImport(AppKit)
    import AppKit
  #endif

  /// The four brand colors used by the native support conversation.
  ///
  /// These values intentionally mirror Jake's hosted widget presentation contract so an app can
  /// render the same customer theme in either implementation.
  public struct SupportConversationTheme {
    public let accent: Color
    public let accentForeground: Color
    public let background: Color
    public let surface: Color
    public let text: Color

    public init(
      accent: Color,
      accentForeground: Color = .white,
      background: Color,
      surface: Color,
      text: Color
    ) {
      self.accent = accent
      self.accentForeground = accentForeground
      self.background = background
      self.surface = surface
      self.text = text
    }

    /// A system-aware theme for applications that have not supplied customer branding.
    public static var automatic: SupportConversationTheme {
      SupportConversationTheme(
        accent: .accentColor,
        background: SupportSystemColors.background,
        surface: SupportSystemColors.surface,
        text: .primary
      )
    }

    var secondaryText: Color { text.opacity(0.62) }
    var tertiaryText: Color { text.opacity(0.44) }
    var line: Color { text.opacity(0.14) }
    var strongLine: Color { text.opacity(0.22) }
    var mutedSurface: Color { text.opacity(0.07) }
  }

  /// Optional identity overrides for the native Messenger header.
  ///
  /// Leave these values unset to use the selected channel's display name and standard icon.
  public struct SupportConversationBranding: Equatable, Sendable {
    public let assistantName: String?
    public let assistantAvatarURL: URL?

    public init(assistantName: String? = nil, assistantAvatarURL: URL? = nil) {
      let normalizedName = assistantName?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.assistantName = normalizedName?.isEmpty == false ? normalizedName : nil
      self.assistantAvatarURL = assistantAvatarURL
    }

    public static let channel = SupportConversationBranding()
  }

  private enum SupportSystemColors {
    static var background: Color {
      #if canImport(UIKit)
        Color(uiColor: .systemBackground)
      #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
      #else
        Color.white
      #endif
    }

    static var surface: Color {
      #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
      #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
      #else
        Color.gray.opacity(0.1)
      #endif
    }
  }
#endif

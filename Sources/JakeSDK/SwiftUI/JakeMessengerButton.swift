#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI

  @available(iOS 15.0, *)
  public struct JakeMessengerButton<Label: View>: View {
    private let label: () -> Label

    public init(@ViewBuilder label: @escaping () -> Label) {
      self.label = label
    }

    public var body: some View {
      Button(action: { Jake.present() }, label: label)
    }
  }

  @available(iOS 15.0, *)
  extension JakeMessengerButton where Label == Text {
    public init(_ title: String = "Contact support") {
      self.init { Text(title) }
    }
  }
#endif

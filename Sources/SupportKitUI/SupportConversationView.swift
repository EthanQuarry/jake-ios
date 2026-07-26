#if canImport(SwiftUI)
  import SupportKitCore
  import SwiftUI

  #if canImport(UIKit)
    import UIKit
  #elseif canImport(AppKit)
    import AppKit
  #endif

  @MainActor
  public final class SupportConversationModel: ObservableObject, SupportChannelAdapterDelegate {
    @Published public private(set) var messages: [SupportMessage] = []
    @Published public private(set) var citations: [SupportCitation] = []
    @Published public private(set) var requestedActions: [SupportActionRequest] = []
    @Published public var draft = ""
    @Published public private(set) var isSending = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var failedDraft: String?
    public let channelName: String
    public let aiDisclosure: String?

    private let channel: any SupportChannelAdapter

    public init(channel: any SupportChannelAdapter) {
      self.channel = channel
      channelName = channel.displayName
      aiDisclosure = channel.aiDisclosure
      channel.delegate = self
    }

    public var canSend: Bool {
      !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func send() {
      let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !body.isEmpty, !isSending else { return }
      beginSend(body, clearingDraft: true)
    }

    public func retryFailedMessage() {
      guard let failedDraft, !isSending else { return }
      beginSend(failedDraft, clearingDraft: false)
    }

    public func dismissError() {
      errorMessage = nil
      failedDraft = nil
    }

    private func beginSend(_ body: String, clearingDraft: Bool) {
      let outgoing = OutgoingSupportMessage(body: body)
      if clearingDraft { draft = "" }
      errorMessage = nil
      failedDraft = nil
      isSending = true
      messages.append(
        SupportMessage(
          id: outgoing.clientMessageID,
          conversationID: "pending",
          role: .customer,
          body: body,
          createdAt: Date()
        )
      )

      Task {
        defer { isSending = false }
        do {
          try await channel.send(outgoing, in: nil)
        } catch {
          messages.removeAll { $0.id == outgoing.clientMessageID }
          if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = body
          } else {
            failedDraft = body
          }
          errorMessage = error.localizedDescription
        }
      }
    }

    public func supportChannel(
      _: any SupportChannelAdapter,
      didEmit event: SupportChannelEvent
    ) {
      switch event {
      case .messageReceived(let message):
        messages.removeAll { $0.id == message.id }
        messages.append(message)
      case .messageUpdated(let message):
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
          messages[index] = message
        } else {
          messages.append(message)
        }
      case .citation(let citation):
        citations.removeAll { $0.id == citation.id }
        citations.append(citation)
      case .actionRequested(let action):
        requestedActions.removeAll { $0.id == action.id }
        requestedActions.append(action)
      case .clarificationRequested(let question, _):
        messages.append(
          SupportMessage(
            id: UUID().uuidString,
            conversationID: "active",
            role: .agent,
            body: question,
            createdAt: Date()
          )
        )
      case .handoffRequested(let reason, _):
        errorMessage = reason
      case .failure(_, let message):
        errorMessage = message
      default:
        break
      }
    }
  }

  public struct SupportConversationView: View {
    @ObservedObject private var model: SupportConversationModel

    public init(model: SupportConversationModel) {
      self.model = model
    }

    public var body: some View {
      VStack(spacing: 0) {
        header
        conversation
        citations
        actionRequest
        sendError
        composer
      }
      .background(SupportPalette.background)
    }

    private var header: some View {
      HStack(spacing: 10) {
        ZStack(alignment: .bottomTrailing) {
          Circle()
            .fill(SupportPalette.subtleSurface)
            .frame(width: 34, height: 34)
            .overlay {
              Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            }
          Circle()
            .fill(Color.green)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(SupportPalette.background, lineWidth: 2))
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(model.channelName)
            .font(.system(size: 15, weight: .semibold))
          if let disclosure = model.aiDisclosure {
            Text(disclosure)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityElement(children: .combine)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(.regularMaterial)
      .overlay(alignment: .bottom) { Divider() }
    }

    private var conversation: some View {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(model.messages) { message in
              HStack {
                if message.role == .customer { Spacer(minLength: 44) }
                Text(message.body)
                  .font(.system(size: 15))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 11)
                  .background(
                    message.role == .customer
                      ? SupportPalette.customerBubble
                      : SupportPalette.subtleSurface
                  )
                  .foregroundStyle(
                    message.role == .customer
                      ? SupportPalette.customerText
                      : Color.primary
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                if message.role != .customer { Spacer(minLength: 44) }
              }
              .id(message.id)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 18)
        }
        .background(SupportPalette.background)
        .supportKeyboardDismissal()
        .onChange(of: model.messages.count) { _ in
          if let id = model.messages.last?.id {
            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
          }
        }
      }
    }

    @ViewBuilder
    private var citations: some View {
      if !model.citations.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(model.citations) { citation in
              if let url = citation.url {
                Link(citation.title, destination: url)
              } else {
                Text(citation.title)
              }
            }
          }
          .font(.caption)
          .padding(.horizontal)
        }
      }
    }

    @ViewBuilder
    private var actionRequest: some View {
      if let action = model.requestedActions.last, action.approvalRequired {
        Text("Approval required: \(action.name)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal)
      }
    }

    @ViewBuilder
    private var sendError: some View {
      if let errorMessage = model.errorMessage {
        HStack(spacing: 12) {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
          if model.failedDraft != nil {
            Button("Retry", action: model.retryFailedMessage)
              .font(.caption.weight(.semibold))
              .disabled(model.isSending)
          }
          Button(action: model.dismissError) {
            Image(systemName: "xmark")
              .font(.caption.weight(.semibold))
          }
          .accessibilityLabel("Dismiss send error")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
      }
    }

    private var composer: some View {
      HStack(alignment: .bottom, spacing: 8) {
        SupportComposerInput(text: $model.draft)
        Button(action: model.send) {
          Group {
            if model.isSending {
              ProgressView()
            } else {
              Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
            }
          }
          .frame(width: 44, height: 44)
          .background(Color.accentColor)
          .foregroundStyle(Color.white)
          .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canSend)
        .opacity(model.canSend || model.isSending ? 1 : 0.45)
        .accessibilityLabel(model.isSending ? "Sending message" : "Send message")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.regularMaterial)
    }
  }

  private enum SupportPalette {
    static let subtleSurface = Color.primary.opacity(0.08)
    static let customerBubble = Color.primary

    static var background: Color {
      #if canImport(UIKit)
        Color(uiColor: .systemBackground)
      #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
      #else
        Color.white
      #endif
    }

    static var customerText: Color {
      background
    }
  }

  private struct SupportComposerInput: View {
    @Binding var text: String

    var body: some View {
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text("Message support")
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .accessibilityHidden(true)
        }
        #if canImport(UIKit)
          GrowingTextView(text: $text)
            .frame(minHeight: 44, maxHeight: 132)
        #else
          TextField("Message support", text: $text, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        #endif
      }
      .background(SupportPalette.subtleSurface)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
      )
      .accessibilityLabel("Message support")
    }
  }

  private extension View {
    @ViewBuilder
    func supportKeyboardDismissal() -> some View {
      #if os(iOS)
        if #available(iOS 16.0, *) {
          scrollDismissesKeyboard(.interactively)
        } else {
          self
        }
      #else
        self
      #endif
    }
  }

  #if canImport(UIKit)
    private struct GrowingTextView: UIViewRepresentable {
      @Binding var text: String

      func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
      }

      func makeUIView(context: Context) -> IntrinsicTextView {
        let textView = IntrinsicTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.returnKeyType = .default
        textView.accessibilityLabel = "Message support"
        textView.accessibilityHint = "Enter a message for support"
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        return textView
      }

      func updateUIView(_ textView: IntrinsicTextView, context: Context) {
        context.coordinator.text = $text
        if textView.text != text {
          textView.text = text
          textView.invalidateIntrinsicContentSize()
        }
      }

      @MainActor
      final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
          self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
          text.wrappedValue = textView.text
        }
      }
    }

    @MainActor
    private final class IntrinsicTextView: UITextView {
      private let minimumHeight: CGFloat = 44
      private let maximumHeight: CGFloat = 132
      private var isUpdatingScrollState = false

      override var contentSize: CGSize {
        didSet {
          updateScrollState()
          invalidateIntrinsicContentSize()
        }
      }

      override var intrinsicContentSize: CGSize {
        let height = min(max(contentSize.height, minimumHeight), maximumHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
      }

      private func updateScrollState() {
        guard !isUpdatingScrollState else { return }
        let shouldScroll = contentSize.height > maximumHeight
        guard shouldScroll != isScrollEnabled else { return }
        isUpdatingScrollState = true
        isScrollEnabled = shouldScroll
        isUpdatingScrollState = false
      }
    }
  #endif
#endif

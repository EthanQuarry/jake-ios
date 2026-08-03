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
    @Published public private(set) var isHandedOff = false
    @Published public private(set) var isAgentTyping = false
    public let channelName: String
    public let aiDisclosure: String?

    private let channel: any SupportChannelAdapter
    private var activeConversationID: String?

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

    public func approveAction(_ action: SupportActionRequest) {
      guard action.decision == nil else { return }
      updateActionDecision(action, decision: .approved)
      Task {
        do {
          try await channel.approveAction(action.id, in: activeConversationID)
        } catch {
          revertActionDecision(action)
          errorMessage = error.localizedDescription
        }
      }
    }

    public func denyAction(_ action: SupportActionRequest) {
      guard action.decision == nil else { return }
      updateActionDecision(action, decision: .denied)
      Task {
        do {
          try await channel.denyAction(action.id, in: activeConversationID)
        } catch {
          revertActionDecision(action)
          errorMessage = error.localizedDescription
        }
      }
    }

    private func updateActionDecision(_ action: SupportActionRequest, decision: ActionDecision) {
      if let index = requestedActions.firstIndex(where: { $0.id == action.id }) {
        requestedActions[index] = action.withDecision(decision)
      }
    }

    private func revertActionDecision(_ action: SupportActionRequest) {
      if let index = requestedActions.firstIndex(where: { $0.id == action.id }) {
        requestedActions[index] = action
      }
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
      case .conversationStarted(let id):
        activeConversationID = id
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
      case .handoffRequested:
        isHandedOff = true
      case .agentTypingChanged(let typing):
        isAgentTyping = typing
      case .failure(_, let message):
        errorMessage = message
      default:
        break
      }
    }
  }

  public struct SupportConversationView: View {
    @ObservedObject private var model: SupportConversationModel
    private let branding: SupportConversationBranding
    private let theme: SupportConversationTheme

    public init(
      model: SupportConversationModel,
      branding: SupportConversationBranding = .channel,
      theme: SupportConversationTheme = .automatic
    ) {
      self.model = model
      self.branding = branding
      self.theme = theme
    }

    public var body: some View {
      VStack(spacing: 0) {
        header
        conversation
        citations
        actionRequest
        handedOffBanner
        sendError
        composer
      }
      .background(theme.background)
      .foregroundStyle(theme.text)
      .tint(theme.accent)
    }

    private var header: some View {
      HStack(spacing: 10) {
        ZStack(alignment: .bottomTrailing) {
          SupportAvatarView(
            name: branding.assistantName ?? model.channelName,
            avatarURL: branding.assistantAvatarURL,
            theme: theme
          )
          .frame(width: 36, height: 36)
          Circle()
            .fill(Color.green)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.surface, lineWidth: 2))
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(branding.assistantName ?? model.channelName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(theme.text)
          if let disclosure = model.aiDisclosure {
            Text(disclosure)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(theme.secondaryText)
          }
        }
        .accessibilityElement(children: .combine)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(theme.surface)
      .overlay(alignment: .bottom) {
        Rectangle().fill(theme.line).frame(height: 1)
      }
    }

    private var conversation: some View {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(model.messages) { message in
              MessageRow(message: message, theme: theme)
                .id(message.id)
            }
            if model.isAgentTyping {
              TypingIndicatorRow(theme: theme)
                .id("typing-indicator")
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 18)
        }
        .background(theme.background)
        .supportKeyboardDismissal()
        .onChangeCompat(of: model.messages.count) {
          if let id = model.messages.last?.id {
            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
          }
        }
        .onChangeCompat(of: model.isAgentTyping) {
          if model.isAgentTyping {
            withAnimation { proxy.scrollTo("typing-indicator", anchor: .bottom) }
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
                Link(destination: url) {
                  CitationLabel(title: citation.title, theme: theme)
                }
              } else {
                CitationLabel(title: citation.title, theme: theme)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
        }
      }
    }

    @ViewBuilder
    private var actionRequest: some View {
      if let action = model.requestedActions.last, action.approvalRequired {
        VStack(spacing: 6) {
          Text("Approval required: \(action.name)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
          if let decision = action.decision {
            HStack(spacing: 6) {
              Image(systemName: decision == .approved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(decision == .approved ? theme.accent : theme.secondaryText)
              Text(decision == .approved ? "Approved" : "Denied")
                .font(.caption.weight(.semibold))
                .foregroundStyle(decision == .approved ? theme.accent : theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            HStack(spacing: 8) {
              Button {
                model.approveAction(action)
              } label: {
                Text("Approve")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 7)
                  .background(theme.accent)
                  .foregroundStyle(theme.accentForeground)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
              Button {
                model.denyAction(action)
              } label: {
                Text("Deny")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 7)
                  .background(.clear)
                  .foregroundStyle(theme.secondaryText)
                  .overlay(Capsule().stroke(theme.strongLine, lineWidth: 1))
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(theme.line, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
      }
    }

    @ViewBuilder
    private var handedOffBanner: some View {
      if model.isHandedOff {
        HStack(spacing: 8) {
          Image(systemName: "person.circle.fill")
            .foregroundStyle(theme.secondaryText)
          Text("You've been connected with our support team.")
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.surface)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
      }
    }

    private var composer: some View {
      VStack(spacing: 6) {
        SupportComposerInput(text: $model.draft, theme: theme)
        HStack(spacing: 4) {
          if model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
            } label: {
              Image(systemName: "paperclip")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.secondaryText)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add attachment")
            Button {
            } label: {
              Image(systemName: "face.smiling")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.secondaryText)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add emoji")
          }
          Spacer(minLength: 8)
          if !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(action: model.send) {
              Group {
                if model.isSending {
                  ProgressView()
                    .tint(theme.accentForeground)
                } else {
                  Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                }
              }
              .frame(width: 36, height: 36)
              .background(theme.accent)
              .foregroundStyle(theme.accentForeground)
              .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canSend)
            .opacity(model.canSend || model.isSending ? 1 : 0.45)
            .accessibilityLabel(model.isSending ? "Sending message" : "Send message")
          }
        }
      }
      .padding(.top, 9)
      .padding(.leading, 13)
      .padding(.trailing, 9)
      .padding(.bottom, 8)
      .frame(minHeight: 84)
      .background(theme.surface)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(theme.strongLine, lineWidth: 1)
      )
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 12)
      .background(theme.background)
    }
  }

  private struct MessageRow: View {
    let message: SupportMessage
    let theme: SupportConversationTheme
    @State private var showFullTimestamp = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var relativeTimestamp: String {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .abbreviated
      return formatter.localizedString(for: message.createdAt, relativeTo: now)
    }

    private var fullTimestamp: String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      return formatter.string(from: message.createdAt)
    }

    var body: some View {
      VStack(alignment: message.role == .customer ? .trailing : .leading, spacing: 3) {
        HStack {
          if message.role == .customer { Spacer(minLength: 44) }
          Text(message.body)
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
              message.role == .customer
                ? theme.accent
                : theme.surface
            )
            .foregroundStyle(
              message.role == .customer
                ? theme.accentForeground
                : theme.text
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(message.role == .customer ? Color.clear : theme.line, lineWidth: 1)
            )
            .onLongPressGesture {
              withAnimation { showFullTimestamp.toggle() }
            }
          if message.role != .customer { Spacer(minLength: 44) }
        }
        Text(showFullTimestamp ? fullTimestamp : relativeTimestamp)
          .font(.system(size: 11))
          .foregroundStyle(theme.tertiaryText)
          .padding(.horizontal, 4)
          .animation(.easeInOut(duration: 0.2), value: showFullTimestamp)
      }
      .onReceive(timer) { _ in now = Date() }
    }
  }

  private struct TypingIndicatorRow: View {
    let theme: SupportConversationTheme
    @State private var phase: Double = 0

    var body: some View {
      HStack(alignment: .bottom, spacing: 0) {
        HStack(spacing: 5) {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .fill(theme.secondaryText)
              .frame(width: 7, height: 7)
              .scaleEffect(dotScale(for: index))
              .animation(
                .easeInOut(duration: 0.5)
                  .repeatForever(autoreverses: true)
                  .delay(Double(index) * 0.2),
                value: phase
              )
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(theme.line, lineWidth: 1)
        )
        Spacer(minLength: 44)
      }
      .onAppear { phase = 1 }
    }

    private func dotScale(for index: Int) -> CGFloat {
      phase == 0 ? 1.0 : (index == 0 ? 0.5 : (index == 1 ? 0.65 : 0.5))
    }
  }

  private struct SupportComposerInput: View {
    @Binding var text: String
    let theme: SupportConversationTheme

    var body: some View {
      ZStack(alignment: .topLeading) {
        if text.isEmpty {
          Text("Message support")
            .foregroundStyle(theme.tertiaryText)
            .padding(.horizontal, 1)
            .padding(.vertical, 3)
            .accessibilityHidden(true)
        }
        #if canImport(UIKit)
          GrowingTextView(text: $text, foregroundColor: theme.text)
            .frame(minHeight: 28, maxHeight: 132)
        #else
          TextField("Message support", text: $text, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .foregroundStyle(theme.text)
            .padding(.vertical, 2)
        #endif
      }
      .accessibilityLabel("Message support")
    }
  }

  private struct CitationLabel: View {
    let title: String
    let theme: SupportConversationTheme

    var body: some View {
      HStack(spacing: 6) {
        Image(systemName: "doc.text")
        Text(title).lineLimit(1)
      }
      .font(.caption)
      .foregroundStyle(theme.text)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(theme.surface)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(theme.line, lineWidth: 1))
    }
  }

  private struct SupportAvatarView: View {
    let name: String
    let avatarURL: URL?
    let theme: SupportConversationTheme

    private var initials: String {
      name.split(separator: " ")
        .prefix(2)
        .compactMap(\.first)
        .map(String.init)
        .joined()
        .uppercased()
    }

    var body: some View {
      ZStack {
        Circle().fill(theme.accent)
        if let avatarURL {
          AsyncImage(url: avatarURL) { phase in
            switch phase {
            case .success(let image):
              image.resizable().scaledToFill()
            default:
              fallback
            }
          }
        } else {
          fallback
        }
      }
      .clipShape(Circle())
      .overlay(Circle().stroke(theme.strongLine, lineWidth: 1))
      .accessibilityLabel(name)
    }

    private var fallback: some View {
      Text(initials.isEmpty ? "?" : initials)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(theme.accentForeground)
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

    /// Two-argument onChange is only available on iOS 17+ / macOS 14+.
    /// This helper normalises the call site without the old single-argument form.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping () -> Void)
      -> some View
    {
      if #available(iOS 17.0, macOS 14.0, *) {
        onChange(of: value) { _, _ in action() }
      } else {
        onChange(of: value) { _ in action() }
      }
    }
  }

  #if canImport(UIKit)
    private struct GrowingTextView: UIViewRepresentable {
      @Binding var text: String
      let foregroundColor: Color

      func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
      }

      func makeUIView(context: Context) -> IntrinsicTextView {
        let textView = IntrinsicTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textColor = UIColor(foregroundColor)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
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
        textView.textColor = UIColor(foregroundColor)
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
      private let minimumHeight: CGFloat = 28
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

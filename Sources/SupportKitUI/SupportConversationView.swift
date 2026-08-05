#if canImport(SwiftUI)
  #if canImport(SupportKitCore)
    import SupportKitCore
  #endif
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
          if model.messages.isEmpty {
            WelcomeView(
              branding: branding,
              model: model,
              theme: theme
            )
            .padding(.horizontal, 16)
            .padding(.top, 40)
          } else {
            LazyVStack(spacing: 12) {
              ForEach(model.messages) { message in
                MessageRow(message: message, theme: theme)
                  .id(message.id)
                  .transition(
                    .asymmetric(
                      insertion: .opacity
                        .combined(with: .move(edge: .bottom))
                        .combined(with: .scale(scale: 0.95)),
                      removal: .opacity
                    )
                  )
              }
              if model.isAgentTyping {
                TypingIndicatorRow(theme: theme)
                  .id("typing-indicator")
                  .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                  ))
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.messages.count)
          }
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
          HStack(spacing: 8) {
            ForEach(model.citations) { citation in
              if let url = citation.url {
                Link(destination: url) {
                  CitationLabel(title: citation.title, theme: theme, isTappable: true)
                }
              } else {
                CitationLabel(title: citation.title, theme: theme, isTappable: false)
              }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
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
      let draftIsEmpty = model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      return VStack(spacing: 6) {
        SupportComposerInput(text: $model.draft, theme: theme)
        HStack(spacing: 4) {
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
          Spacer(minLength: 8)
          if !draftIsEmpty {
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
            .transition(.scale.combined(with: .opacity))
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
      .padding(.leading, 14)
      .padding(.trailing, 10)
      .padding(.bottom, 10)
      .background(theme.surface)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(theme.line, lineWidth: 1)
      )
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .background(theme.background)
    }
  }

  private struct MessageRow: View {
    let message: SupportMessage
    let theme: SupportConversationTheme
    @State private var showTimestamp = false

    private var isCustomer: Bool { message.role == .customer }

    private var timestamp: String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      return formatter.string(from: message.createdAt)
    }

    @ViewBuilder
    private var messageText: some View {
      if !isCustomer, #available(iOS 15.0, macOS 12.0, *) {
        let attributed = (try? AttributedString(
          markdown: message.body,
          options: AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
          )
        )) ?? AttributedString(message.body)
        Text(attributed)
          .font(.system(size: 15))
      } else {
        Text(message.body)
          .font(.system(size: 15))
      }
    }

    var body: some View {
      VStack(alignment: isCustomer ? .trailing : .leading, spacing: 4) {
        HStack {
          if isCustomer { Spacer(minLength: 60) }
          messageText
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isCustomer ? .white : theme.text)
            .background(isCustomer ? theme.customerBubble : theme.agentBubble)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isCustomer ? Color.clear : theme.line, lineWidth: 1)
            )
            .onLongPressGesture {
              withAnimation(.easeInOut(duration: 0.15)) { showTimestamp.toggle() }
            }
          if !isCustomer { Spacer(minLength: 60) }
        }
        if showTimestamp {
          Text(timestamp)
            .font(.system(size: 11))
            .foregroundStyle(theme.tertiaryText)
            .padding(.horizontal, 4)
            .transition(.opacity)
        }
      }
    }
  }

  private struct TypingIndicatorRow: View {
    let theme: SupportConversationTheme
    @State private var animating = false

    var body: some View {
      HStack(alignment: .bottom, spacing: 0) {
        HStack(spacing: 5) {
          ForEach(0..<3, id: \.self) { index in
            Circle()
              .fill(theme.secondaryText)
              .frame(width: 8, height: 8)
              .opacity(dotOpacity(for: index))
              .animation(
                .easeInOut(duration: 0.55)
                  .repeatForever(autoreverses: true)
                  .delay(Double(index) * 0.18),
                value: animating
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
      .onAppear { animating = true }
      .onDisappear { animating = false }
    }

    private func dotOpacity(for index: Int) -> Double {
      animating ? (index == 1 ? 0.3 : 0.15) : 1.0
    }
  }

  private struct SupportComposerInput: View {
    @Binding var text: String
    let theme: SupportConversationTheme
    @State private var isFocused = false

    var body: some View {
      ZStack(alignment: .topLeading) {
        if text.isEmpty && !isFocused {
          Text("Message...")
            .foregroundStyle(theme.tertiaryText)
            .padding(.horizontal, 1)
            .padding(.vertical, 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        #if canImport(UIKit)
          GrowingTextView(text: $text, foregroundColor: theme.text, isFocused: $isFocused)
            .frame(minHeight: 28, maxHeight: 132)
        #else
          TextField("Message...", text: $text, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .foregroundStyle(theme.text)
            .padding(.vertical, 2)
        #endif
      }
      .accessibilityLabel("Message...")
    }
  }

  private struct CitationLabel: View {
    let title: String
    let theme: SupportConversationTheme
    let isTappable: Bool

    var body: some View {
      HStack(spacing: 5) {
        Image(systemName: "doc.text")
          .font(.caption)
        Text(title)
          .lineLimit(1)
          .font(.caption)
        if isTappable {
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(theme.tertiaryText)
        }
      }
      .foregroundStyle(theme.text)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
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

  private struct WelcomeView: View {
    let branding: SupportConversationBranding
    let model: SupportConversationModel
    let theme: SupportConversationTheme
    @State private var appeared = false

    var body: some View {
      VStack(spacing: 16) {
        SupportAvatarView(
          name: branding.assistantName ?? model.channelName,
          avatarURL: branding.assistantAvatarURL,
          theme: theme
        )
        .frame(width: 64, height: 64)
        VStack(spacing: 6) {
          Text("Hi there 👋")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(theme.text)
          Text("How can we help you today?")
            .font(.system(size: 15))
            .foregroundStyle(theme.secondaryText)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .scaleEffect(appeared ? 1 : 0.88)
      .opacity(appeared ? 1 : 0)
      .onAppear {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.05)) {
          appeared = true
        }
      }
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
      @Binding var isFocused: Bool

      func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
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
        textView.accessibilityLabel = "Message..."
        textView.accessibilityHint = "Enter a message for support"
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        return textView
      }

      func updateUIView(_ textView: IntrinsicTextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isFocused = $isFocused
        textView.textColor = UIColor(foregroundColor)
        if textView.text != text {
          textView.text = text
          textView.invalidateIntrinsicContentSize()
        }
      }

      @MainActor
      final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
          self.text = text
          self.isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
          text.wrappedValue = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
          isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
          isFocused.wrappedValue = false
        }
      }
    }

    @MainActor
    private final class IntrinsicTextView: UITextView {
      private let minimumHeight: CGFloat = 34
      private let maximumHeight: CGFloat = 120
      private var isUpdatingScrollState = false

      override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        isScrollEnabled = false
      }

      @available(*, unavailable)
      required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

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

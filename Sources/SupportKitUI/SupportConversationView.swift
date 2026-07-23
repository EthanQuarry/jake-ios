#if canImport(SwiftUI)
  import SupportKitCore
  import SwiftUI

  @MainActor
  public final class SupportConversationModel: ObservableObject, SupportChannelAdapterDelegate {
    @Published public private(set) var messages: [SupportMessage] = []
    @Published public private(set) var citations: [SupportCitation] = []
    @Published public private(set) var requestedActions: [SupportActionRequest] = []
    @Published public var draft = ""
    @Published public private(set) var isSending = false
    @Published public private(set) var errorMessage: String?

    private let channel: any SupportChannelAdapter

    public init(channel: any SupportChannelAdapter) {
      self.channel = channel
      channel.delegate = self
    }

    public func send() {
      let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !body.isEmpty, !isSending else { return }
      draft = ""
      isSending = true
      let outgoing = OutgoingSupportMessage(body: body)
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
        do { try await channel.send(outgoing, in: nil) } catch {
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
      case .handoffRequested(let reason, _): errorMessage = reason
      case .failure(_, let message): errorMessage = message
      default: break
      }
    }
  }

  public struct SupportConversationView: View {
    @ObservedObject private var model: SupportConversationModel

    public init(model: SupportConversationModel) { self.model = model }

    public var body: some View {
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          ZStack(alignment: .bottomTrailing) {
            Circle()
              .fill(Color(.systemGray5))
              .frame(width: 34, height: 34)
              .overlay {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(Color(.label))
              }
            Circle()
              .fill(Color.green)
              .frame(width: 10, height: 10)
              .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
          }
          Text("Support")
            .font(.system(size: 15, weight: .semibold))
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }

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
                      message.role == .customer ? Color(.label) : Color(.systemGray6)
                    )
                    .foregroundStyle(message.role == .customer ? Color(.systemBackground) : Color(.label))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                  if message.role != .customer { Spacer(minLength: 44) }
                }
                .id(message.id)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
          }
          .background(Color(.systemBackground))
          .onChange(of: model.messages.count) { _ in
            if let id = model.messages.last?.id {
              withAnimation { proxy.scrollTo(id, anchor: .bottom) }
            }
          }
        }
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
        if let action = model.requestedActions.last, action.approvalRequired {
          Text("Approval required: \(action.name)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        if let errorMessage = model.errorMessage {
          Text(errorMessage).font(.caption).foregroundStyle(.red).padding(.horizontal)
        }
        HStack {
          TextField("Message support", text: $model.draft)
            .textFieldStyle(.roundedBorder)
            .onSubmit { model.send() }
          Button(action: model.send) {
            if model.isSending {
              ProgressView()
            } else {
              Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
            }
          }
          .foregroundStyle(Color(.label))
          .disabled(
            model.isSending || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
      }
      .background(Color(.systemBackground))
    }
  }
#endif

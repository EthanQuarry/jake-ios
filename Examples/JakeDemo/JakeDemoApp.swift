import JakeSDK
import SwiftUI

@main
struct JakeDemoApp: App {
  @StateObject private var model = DemoModel()

  var body: some Scene {
    WindowGroup {
      NavigationView {
        VStack(spacing: 24) {
          Image(systemName: "message.fill")
            .font(.system(size: 52))
            .foregroundStyle(.tint)

          VStack(spacing: 8) {
            Text("Jake iOS Demo")
              .font(.largeTitle.bold())
            Text(model.status)
              .multilineTextAlignment(.center)
              .foregroundStyle(.secondary)
          }

          Button {
            Task { await model.connectAndPresent() }
          } label: {
            HStack {
              if model.isLoading {
                ProgressView()
              }
              Text(model.isReady ? "Open Messenger" : "Connect to Jake")
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(model.isLoading)

          if let error = model.error {
            Text(error)
              .font(.footnote)
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
          }

          Spacer()

          Text("The local token bridge must be running on port 8787.")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(28)
        .navigationTitle("Jake")
      }
      .navigationViewStyle(.stack)
    }
  }
}

@MainActor
final class DemoModel: ObservableObject, JakeDelegate {
  @Published private(set) var isLoading = false
  @Published private(set) var isReady = false
  @Published private(set) var status = "Ready to connect through the local token bridge."
  @Published private(set) var error: String?

  private let tokenURL = URL(string: "http://127.0.0.1:8787/mobile/support-token")!

  init() {
    Jake.delegate = self
  }

  func connectAndPresent() async {
    error = nil

    if isReady {
      presentMessenger()
      return
    }

    isLoading = true
    status = "Requesting a short-lived session…"
    defer { isLoading = false }

    do {
      var request = URLRequest(url: tokenURL)
      request.httpMethod = "POST"
      request.setValue("Bearer local-development-session", forHTTPHeaderField: "Authorization")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw DemoError.invalidResponse
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
        let serverError = try? JSONDecoder().decode(ServerError.self, from: data)
        throw DemoError.server(
          serverError?.message ?? serverError?.error ?? "HTTP \(httpResponse.statusCode)"
        )
      }

      let session = try JSONDecoder().decode(SupportSession.self, from: data)
      try Jake.configureMessenger(
        workspaceId: session.workspaceId,
        publicKey: session.publicKey
      )
      try await Jake.authenticate(userId: "local-ios-test-user", token: session.token)

      isReady = true
      status = "Connected. Messenger is ready."
      presentMessenger()
    } catch {
      status = "Could not connect."
      self.error = error.localizedDescription
    }
  }

  func jakeAuthenticationDidExpire() {
    isReady = false
    status = "The session expired. Connect again."
  }

  func jakeDidFail(with error: JakeError) {
    self.error = error.localizedDescription
  }

  private func presentMessenger() {
    do {
      try Jake.presentMessenger()
    } catch {
      self.error = error.localizedDescription
    }
  }
}

private struct SupportSession: Decodable {
  let token: String
  let workspaceId: String
  let publicKey: String
}

private struct ServerError: Decodable {
  let error: String?
  let message: String?
}

private enum DemoError: LocalizedError {
  case invalidResponse
  case server(String)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "The local token bridge returned an invalid response."
    case .server(let message):
      return message
    }
  }
}

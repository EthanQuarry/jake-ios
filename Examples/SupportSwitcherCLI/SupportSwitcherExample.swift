import Foundation
import SupportAdapterKit

@main
@MainActor
struct SupportSwitcherExample {
  static func main() async throws {
    let requestedProvider = SupportProviderID(
      rawValue: CommandLine.arguments.dropFirst().first ?? "jake"
    )
    let coordinator = SupportCoordinator()

    for providerID in [SupportProviderID.jake, .intercom, .internalAgent] {
      try coordinator.register(
        CustomSupportProvider(
          id: providerID,
          displayName: providerID.rawValue.capitalized,
          handlers: CustomSupportProviderHandlers(
            authenticate: { session in
              print("[\(providerID)] authenticated \(session.user.id)")
            },
            present: {
              print("[\(providerID)] messenger presented")
            },
            logout: {
              print("[\(providerID)] logged out")
            }
          )
        )
      )
    }

    try coordinator.selectProvider(requestedProvider)
    try await coordinator.startSession(
      SupportSession(user: SupportUser(id: "example-customer"))
    )
    try await coordinator.present()
    await coordinator.endSession()
  }
}

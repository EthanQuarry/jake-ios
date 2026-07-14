# Migration guide

## From direct Jake Messenger

Existing `JakeSDK` calls remain source compatible. For a portable channel:

1. Add `SupportKitCore`, `SupportKitUI`, and `CustomAgentAdapter`.
2. Mount `@open-support/router` on your backend and implement a transactional store.
3. Register `JakeAgentProvider` server-side; keep all credentials off-device.
4. Create `RouterChannelAdapter` and `SupportConversationModel` in the app.
5. Route an internal cohort to `supportkit-native` + `jake`.
6. Verify transcript export, timeout/cancel, human escalation, and failed-handoff rollback.

Keep `JakeSupportAdapter` when you want the hosted Jake Messenger rather than the portable native
UI. Its capability model correctly reports that it is an opaque vendor channel.

## Add Fin without coupling the app to Fin

1. Configure `FinAgentProvider` in the router with a server-side access token.
2. Keep `supportkit-native` as the channel and choose `intercom-fin` as the agent provider.
3. Configure `FinHumanHandoffAdapter` for Inbox escalation.
4. Test cumulative SSE snapshots, final HTML rendering, webhook persistence, and escalation.
5. Roll out only to new conversations.

Use `IntercomChannelAdapter` separately only when the desired UI is Intercom Messenger itself.

## Add an internal agent

Implement the neutral HTTP agent protocol and use `HttpAgentProvider`, or expose the same tools via
MCP and use `McpAgentProvider`. Advertise only capabilities that work. Run the conformance suite and
test incomplete handoff import before enabling the provider.

## Configuration v1 to v2

Version 1 treated a provider as both UI and brain. Version 2 splits:

- `defaultChannel` / `channels`
- `defaultAgentProvider` / `agentProviders`
- optional `humanHandoffAdapter`
- routing rules that may select channel, agent, or both

The API still parses v1 and serves the old selection endpoint. Publish v2 only after the app has
registered the new channel IDs.

## Rollout checklist

- New conversations pin both the selected channel and agent assignment.
- Active conversations change agents only through normalized handoff.
- Target import commits before source close; failures keep the source active.
- Human escalation has its own adapter and audited external reference.
- Identity comes from a signed session; client attributes cannot self-select privileged routes.
- Provider secrets are server-side and redacted from logs/traces.
- Canonical data is transactional, exportable, and restorable.
- Each provider passes capability, streaming, cancellation, timeout, and handoff tests.
- A kill switch changes defaults for new conversations without breaking current ones.

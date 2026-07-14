# Architecture

```text
iOS app
  ├─ SupportKitUI (portable native channel)
  │    └─ RouterChannelAdapter
  ├─ JakeChannelAdapter (opaque Jake Messenger, optional)
  └─ IntercomChannelAdapter (opaque Intercom Messenger, optional)
             │
             ▼
canonical support router
  ├─ verified customer/conversation/message history
  ├─ pinned agent assignment + namespaced provider references
  ├─ normalized agent/human handoffs
  ├─ audit and export
  ├─ JakeAgentProvider ───────── proprietary Jake runtime
  ├─ FinAgentProvider ────────── Fin Agent API
  ├─ HttpAgentProvider ───────── company/internal agent
  └─ McpAgentProvider ────────── optional agent-to-agent/configuration layer
```

## Ownership

The channel owns presentation, dismissal, outgoing customer input, incoming display, unread state,
push integration, and attachment UI. It does not own prompts, tools, policy, retrieval, or agent
selection.

The server-side agent adapter owns capabilities, conversation start, streamed normalized events,
citations/actions/clarification, cancellation, timeout, handoff import, and close.

The canonical router—not an agent vendor—owns stable identity, verified history, the active
assignment, handoff records, audit, and export. Provider IDs are namespaced references, never the
canonical primary key.

## State rules

Remote configuration may select a channel and agent only for a new conversation. Once started, the
conversation remains pinned. The only transition is an explicit handoff:

```text
source active → build package → prepare/import target → atomic assignment commit → close source
                                      │ failure
                                      └──────────────→ source remains active
```

A human escalation is a separate adapter and state transition. It commits the desk reference before
closing the source agent. Cleanup failure is audited rather than rolling back a completed external
handoff.

## Handoff package

Every target receives verified customer identity and transcript, current intent, completed work,
pending approvals, evidence/citations, reason, source assignment, request time, and metadata.
Capability/import results explicitly report anything a provider could not transfer.

## Proprietary boundary

The neutral contracts, conformance tests, reference HTTP server, iOS channel, and customer-owned
configuration are open. Jake's system prompt, orchestration, safety implementation, model routing,
tool execution, retrieval strategy, and private evaluations stay in Jake-controlled services.

MCP complements this architecture for configuration and agent-to-agent tools. It is not a mobile
messaging transport and does not replace the canonical router.

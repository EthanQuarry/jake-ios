# Backend contract

## Select channel and agent independently

```http
POST /v1/sdk/support-selection
Authorization: Bearer <short-lived SDK session>
X-Jake-Public-Key: <application public key>
Content-Type: application/json
```

```json
{
  "userID": "customer-42",
  "locale": "en-IE",
  "appVersion": "3.8.0"
}
```

```json
{
  "channel": "supportkit-native",
  "agentProvider": "jake",
  "humanHandoffAdapter": "intercom-inbox",
  "reason": "application default",
  "ttlSeconds": 300
}
```

The server derives workspace, application, customer, and routing attributes from the verified
session. It ignores device-supplied attributes for authorization/routing. The legacy
`/v1/sdk/provider-selection` endpoint remains available for old combined-provider clients.

Selection applies to new conversations only. A client must not reinterpret a later response as
permission to move an active conversation.

## Native-channel router API

All routes require the application session. The server's authentication callback supplies the
verified customer; a customer object in the request is never authoritative.

```http
POST /v1/router/conversations
```

```json
{ "providerId": "jake", "subject": "Refund question" }
```

The response contains the canonical conversation and pinned assignment. Send a turn with:

```http
POST /v1/router/conversations/{canonicalId}/turns
Accept: application/x-ndjson
```

```json
{
  "clientMessageId": "019f...",
  "content": { "body": "Can I get a refund?", "format": "plain" },
  "attachments": []
}
```

The NDJSON stream emits normalized events such as `response.delta`, `response.snapshot`,
`response.completed`, `citation`, `action.requested`, `clarification.requested`,
`handoff.requested`, `usage`, and `error`.

Other routes:

- `POST /v1/router/conversations/:id/agent-handoffs`
- `POST /v1/router/conversations/:id/human-handoffs`
- `GET /v1/router/conversations/:id/export`
- `DELETE /v1/router/conversations/:id`

## Agent provider protocol

Internal and third-party agents can implement the server-to-server HTTP contract:

- capabilities: `GET /v1/support/capabilities`
- start: `POST /v1/support/conversations`
- turn: `POST /v1/support/conversations/:id/turns` (NDJSON)
- import handoff: `POST /v1/support/handoffs`
- cancel and close routes

The Jake API additionally exposes authenticated bridge routes for server-side `JakeAgentProvider`:

- `POST /v1/support/conversations`
- `POST /v1/support/handoffs`
- `DELETE /v1/support/conversations/:id`
- `/v1/realtime` for streamed Jake turns

The bridge stores imported normalized handoff context in Jake's conversation record and audits the
transition. It does not expose Jake prompts or orchestration.

Handoff import requires both the customer's short-lived session (identity/ownership) and a distinct
`X-Support-Router-Secret` server credential (`SUPPORT_ROUTER_HANDOFF_SECRET` in the Jake service).
This prevents a mobile customer from fabricating verified transcript or completed-work context.

## Credentials and persistence

Mobile clients receive only short-lived customer session credentials. Fin tokens, internal-agent
keys, MCP credentials, signing secrets, and Jake server credentials remain in a secret manager.

Production routers implement the transactional `CanonicalRouterStore`. The included in-memory
store is for tests/reference use. Persist stable IDs, verified messages and attachments, provider
references, assignment version, events, handoffs, audit, and export data. Deduplicate both client
message IDs and provider event IDs.

Migration `0006_narrow_centennial.sql` adds versioned application support routing and is registered
in the Drizzle journal.

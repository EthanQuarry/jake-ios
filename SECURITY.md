# Security

## Secrets

Never commit or embed Jake secrets, Fin/Intercom API secrets, model-provider keys, MCP credentials,
signing keys, or long-lived user tokens. The iOS app may contain public application identifiers and
short-lived customer credentials issued by an authenticated backend.

Keep provider credentials in a secret manager. Jake handoff import uses a distinct server-to-server
credential in addition to the customer's identity token; never send that credential to iOS. Redact
all authorization and router-secret headers from logs, crash reports, and traces.

## Identity and routing

Production endpoints use HTTPS. Loopback HTTP is permitted only for local development. The router
derives customer/workspace/application identity from the signed session and ignores client-supplied
identity and routing attributes. Return only non-sensitive channel/agent decisions.

Remote configuration affects new conversations only. An active conversation stays pinned until a
normalized handoff atomically commits a new assignment.

## Canonical data and handoffs

Treat transcripts, attachments, summaries, evidence, approvals, and external IDs as customer data.
Apply tenant isolation, retention, consent, encryption, and export/delete policy. Deduplicate client
and provider event IDs.

Only a trusted router may label a transcript verified. Targets report partial import honestly. Never
put raw credentials, hidden system prompts, or tool secrets in a handoff package. Prepare the target
before closing the source, and audit cleanup failures.

## Mobile channel

Opaque vendor Messenger adapters do not claim arbitrary-agent routing. The portable native channel
accepts streamed text as display data; it does not execute HTML, tool calls, links, or provider
actions. Validate attachment types and sizes server-side even when iOS has already checked them.

## Reporting

Report suspected vulnerabilities privately to the repository owner. Do not include live credentials
or customer transcripts in an issue.

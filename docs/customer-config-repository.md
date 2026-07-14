# Optional customer configuration repository

Use one private repository per customer when they want agent-assisted configuration, code review, and portable history. Do not fork the Jake runtime into it.

The repository should contain only customer-owned material:

- channel, agent-provider, human-desk enablement and routing rules;
- company instructions, tone, escalation rules, and examples;
- tool declarations that reference secret names, never secret values;
- evaluation cases and expected outcomes;
- deployment metadata and changelog.

Keep Jake's core prompt, orchestration, safety implementation, credentials, and internal evaluation sets in Jake-controlled infrastructure.

`Templates/customer-config` is a starting layout. An ordinary Git workflow gives Codex, Claude Code, and human operators durable context. An MCP control plane can later expose validated read/publish operations over the same files; Git remains the review and history layer rather than the live runtime database.

Recommended deployment flow:

```text
edit or speak-to-code → pull request → schema/policy/eval checks → approval → signed release
→ control-plane import → immutable configuration version → gradual rollout
```

The runtime should use an imported immutable version, not fetch the Git repository on every customer message.

The current Jake control plane accepts the repository's validated schema-v2 `support.config.json` through `updateApplicationSupportRouting`. A deployment workflow should call that mutation with a service identity after review; end-user devices must never receive administrative credentials. Channel and agent selection affect new conversations only.

# Customer support configuration

This repository contains customer-owned support behavior. Keep changes reviewable and vendor-neutral.

- Validate `support.config.json` against `Schemas/support-routing.schema.json` before proposing it.
- Never add API keys, signing secrets, user tokens, customer transcripts, or Jake internal prompts.
- Put company-specific behavior in `prompts/company.md`.
- Add or update evaluation cases for every material behavior change.
- Do not change a provider ID without coordinating an application release that registers it.
- Treat routing changes as affecting new sessions only. Never design a rule that silently moves an active conversation.

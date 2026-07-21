# AGENTS.md — plaid_omni_connect

## Artemis governance

Before non-trivial changes: read the shared Artemis constitution at
`../govern/.specify/memory/constitution.md` (veto power over plans/tasks).
Write authority ends at this repo root — do not edit sibling Artemis repos in this session.
Archives under `../docs/archives/` are out-of-band (human-EM gate).

## Project purpose

Flutter package providing cross-platform Plaid Link UI. Pluto/Neelo backends own
link tokens and secrets; this package must never embed provider secrets.

## Guardrails

- Keep the package free of Artemis business PII and provider credentials.
- Prefer documented public APIs; update README/CHANGELOG for breaking changes.
- Constitution cost gate applies to any new paid SDK/runtime dependency.

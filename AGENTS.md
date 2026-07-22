# AGENTS.md — plaid_omni_connect

## Artemis governance

Before non-trivial changes: read the shared Artemis constitution at
`../govern/.specify/memory/constitution.md` (veto power over plans/tasks).
Write authority ends at this repo root — do not edit sibling Artemis repos in this session.
Archives under `../docs/archives/` are out-of-band (human-EM gate).

## Project purpose

**Public pub.dev package** ([plaid_omni_connect](https://pub.dev/packages/plaid_omni_connect)) providing cross-platform Plaid Link UI.
This Artemis workspace folder is a **convenience clone for package maintenance** — it is **not** Neelo’s (or any product app’s) dependency source.
Consumers depend on the **hosted** version from pub.dev; publish changes, then bump the version constraint in consumers.

Pluto/Neelo backends own link tokens and secrets; this package must never embed provider secrets.

## Guardrails

- Keep the package free of Artemis business PII and provider credentials.
- Prefer documented public APIs; update README/CHANGELOG for breaking changes.
- Constitution cost gate applies to any new paid SDK/runtime dependency.
- Do not instruct product apps to add `path:` / `git:` / `dependency_overrides` pointing at this clone.

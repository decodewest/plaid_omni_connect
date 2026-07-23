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

## Releasing (agents)

Canonical path — do **not** invent alternatives:

1. Bump `version` in `pubspec.yaml` and add a matching `## X.Y.Z` section in `CHANGELOG.md`.
2. Commit and push (or merge) that bump to `main`.
3. Create and push the version tag only (after human approval to push tags if required by session rules):
   `git tag vX.Y.Z && git push origin vX.Y.Z`
4. Wait for `.github/workflows/publish.yml` — it publishes to pub.dev via OIDC and creates the GitHub Release from the CHANGELOG section.

**Forbidden:**
- `dart pub publish` / `flutter pub publish` locally (or telling humans to do that as the primary path)
- Publishing without a `vX.Y.Z` tag that matches `pubspec.yaml`
- Instructing product apps (Neelo/Pluto) to use `path:`, `git:`, or `dependency_overrides` to this clone

**One-time human setup** (already done for this package; re-check only if CI publish fails auth):
pub.dev → package Admin → Automated publishing → GitHub Actions enabled for
`decodewest/plaid_omni_connect` with tag pattern `v{{version}}`.

After a new version is on pub.dev, bump consumer constraints in a **separate** product-repo session (e.g. Neelo `plaid_omni_connect: ^X.Y.Z`).

## Guardrails

- Keep the package free of Artemis business PII and provider credentials.
- Prefer documented public APIs; update README/CHANGELOG for breaking changes.
- Constitution cost gate applies to any new paid SDK/runtime dependency.
- Do not instruct product apps to add `path:` / `git:` / `dependency_overrides` pointing at this clone.

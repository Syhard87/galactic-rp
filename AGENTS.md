# AGENTS.md — Galactic RP

## Project context

Galactic RP is a nanos world RP/RPG persistent server project.

The project must be built as a serious software product:
- modular nanos world Lua packages
- React/TypeScript WebUI for HUD and Datapad
- PostgreSQL for persistence
- Docker for local infrastructure
- GitHub Issues / Projects for backlog
- GitHub Actions for CI/CD
- server-authoritative gameplay
- clean documentation

The main specification is located at:

`docs/cahier-des-charges.md`

Every agent must read it before proposing architecture or implementation.

## Absolute rules

- Never commit secrets.
- Never create real `.env` files with production secrets.
- Use `.env.example` only.
- Keep gameplay-sensitive logic server-side.
- The client must never directly grant XP, money, items, reputation, permissions, quest rewards, or admin actions.
- Every feature must be linked to a user story or technical task.
- Prefer small pull requests.
- Prefer simple MVP-first implementation over over-engineered architecture.
- Update documentation when architecture changes.
- Use Git branches for every change.

## Git workflow

Branches:
- `main` = stable production
- `develop` = integration/staging
- `feature/*` = features
- `fix/*` = bug fixes
- `hotfix/*` = urgent fixes

Commit convention:
- `feat: ...`
- `fix: ...`
- `docs: ...`
- `ci: ...`
- `chore: ...`
- `refactor: ...`
- `test: ...`

## Definition of Ready

A task is ready only if:
- description is clear
- acceptance criteria exist
- impacted package is identified
- DB/UI impact is documented
- priority is defined
- complexity is estimated

## Definition of Done

A task is done only if:
- code is committed
- CI passes
- acceptance criteria are met
- documentation is updated if needed
- no secret is committed
- tests/checks were run or documented

## Architecture direction

Use a modular monolith architecture with nanos world packages:

- `gr-core`
- `gr-database`
- `gr-characters`
- `gr-progression`
- `gr-skills`
- `gr-inventory`
- `gr-crafting`
- `gr-quests`
- `gr-factions`
- `gr-reputation`
- `gr-contracts`
- `gr-chat`
- `gr-voip`
- `gr-admin`
- `gr-hud`
- `gr-datapad`

Each package should separate:
- `Server/`
- `Client/`
- `Shared/`

## Preferred stack

- Gameplay: Lua nanos world
- UI: React + TypeScript + Vite
- Styling: Tailwind CSS
- Database: PostgreSQL
- Local infra: Docker Compose
- CI/CD: GitHub Actions
- Docs: Markdown

## Nanos world documentation rule

This project targets nanos world.

Before changing Lua code, package structure, server lifecycle, client lifecycle, networking, WebUI, entities, maps, assets or `Package.toml`, agents must consult the official nanos world documentation.

Use these sources in priority order:

1. Local docs submodule:
   - `external/nanos-world-docs/versioned_docs/version-latest/`
   - `external/nanos-world-docs/docs/`
2. Project reference:
   - `docs/nanos-world-reference.md`
3. Official web docs if internet is available:
   - https://docs.nanos-world.com/docs/getting-started/essential-concepts
   - https://github.com/nanos-world/docs

Hard rules:

- Do not invent nanos world API calls.
- Do not invent event names.
- Do not invent class constructors.
- Do not assume server/client authority behavior.
- If a feature depends on an undocumented or uncertain API, stop and document the uncertainty.
- For gameplay, persistence and security, prefer server-authoritative logic.
- Client code must not be trusted for money, permissions, character ownership, faction rights, inventory or admin actions.
- Every PR touching nanos world scripts must mention which documentation pages were checked.

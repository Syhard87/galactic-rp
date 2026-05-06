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

- `gr_core`
- `gr_database`
- `gr_characters`
- `gr_progression`
- `gr_skills`
- `gr_inventory`
- `gr_crafting`
- `gr_quests`
- `gr_factions`
- `gr_reputation`
- `gr_contracts`
- `gr_chat`
- `gr_voip`
- `gr_admin`
- `gr_hud`
- `gr_datapad`

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
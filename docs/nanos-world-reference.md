# Nanos world official documentation reference

## Official sources

- Web documentation: https://docs.nanos-world.com/docs/getting-started/essential-concepts
- GitHub documentation repository: https://github.com/nanos-world/docs
- Local documentation submodule: `external/nanos-world-docs/`

## Local documentation paths

Codex and project agents must use the local documentation first:

- `external/nanos-world-docs/versioned_docs/version-latest/`
- `external/nanos-world-docs/docs/`
- `external/nanos-world-docs/sidebars.js`

## Rules for nanos world development

Before modifying any file under `server/Packages/`, Codex must:

1. Search the local nanos world documentation.
2. Identify the relevant documentation page.
3. Respect the official Server / Client / Shared lifecycle.
4. Respect nanos world authority rules: server-only, client-only, both sides, authority-only.
5. Never invent a nanos world API method, event, class or constructor.
6. If the documentation is unclear, stop and explain what must be verified in game.

## Important concepts

- Packages are the core building blocks.
- A script package uses `Package.toml`.
- Lua entrypoints are usually:
  - `Server/Index.lua`
  - `Client/Index.lua`
  - `Shared/Index.lua`
- The package must be listed in the server `Config.toml` to be loaded.
- Networking and synchronization must respect nanos world client/server rules.
- Use server-authoritative logic for gameplay, persistence, permissions and security.

## Project priority

For Galactic RP, use nanos world documentation as the source of truth before implementing:

- packages
- events
- player lifecycle
- character lifecycle
- entities
- networking
- WebUI
- server configuration
- maps
- assets
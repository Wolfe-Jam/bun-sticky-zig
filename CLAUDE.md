# bun-sticky

Fastest bun under the sum. Zig-native FAF CLI.

## Quick Commands

```bash
zig build test --summary all             # 157/157 tests passed (WJTTC)
zig build -Doptimize=ReleaseFast         # Build (77KB binary)
./zig-out/bin/faf score           # Score current project
./zig-out/bin/faf help            # Show commands
```

## Architecture

```
bun-sticky-zig/
├── src/
│   ├── main.zig      # CLI entry + ASCII banner
│   ├── scorer.zig    # Wolfejam 21-slot scoring
│   ├── tier.zig      # 7-tier ranking system
│   └── tests.zig     # WJTTC test suite
├── build.zig         # Zig 0.15+ build config
└── project.faf       # Self-scoring (100%)
```

## Scoring System

**Wolfejam Slot-Based Scoring** — a Zig-native approximation of faf-cli's
live scoring kernel, not an authoritative reimplementation (the real
kernel is a private compiled binary — see `~/FAF/cli/src/core/scorer.ts`).
Run `faf-cli score` for the authoritative number.

- 21 base slots (project/frontend/backend/universal/human), always applicable
  to every project type — a `cli`-type project is not exempted, it fills
  frontend/backend with `none`
- 12 enterprise slots, applicable only when a `monorepo:` block or
  `app_type: enterprise` is present — 33 Mk4 canonical total
- Formula: `Score = (Filled / Applicable) × 100`

| Category | Slots | Fields |
|----------|-------|--------|
| Project | 3 | name, goal, main_language |
| Frontend | 4 | frontend, css_framework, ui_library, state_management |
| Backend | 5 | backend, api_type, runtime, database, connection |
| Universal | 3 | hosting, build, cicd |
| Human | 6 | who, what, why, where, when, how |
| Enterprise | 12 | monorepo/pkg-manager/admin/cache/search/storage/versioning/configs/remote-cache — conditional |

## Tier System

| Score | Tier | Symbol | Notes |
|-------|------|--------|-------|
| 100% | Trophy | ✪ | Work-surface proof seal (not 🏆 — that's social-only) |
| 99%+ | Gold | ★ | |
| 95%+ | Silver | ◆ | |
| 85%+ | Bronze | ◇ | Production ready |
| 70%+ | Green | ● | |
| 55%+ | Yellow | ● | |
| 1%+ | Red | ○ | |
| 0% | White | ♡ | Empty |

**Big Orange 🍊** is the honor above Trophy — multi-criteria, AI/human-awarded,
never calculated from a single score, never described as "above 100%."
tier.zig deliberately does not compute it.

## Key Files

| File | Purpose |
|------|---------|
| `src/scorer.zig` | SLOTS definitions (33 Mk4 canonical: 21 base + 12 enterprise) |
| `src/scorer.zig` | `ProjectType` enum (display-only, no longer gates applicability) |
| `src/scorer.zig` | `calculateScore()` function |
| `src/tier.zig` | Single source of truth for the tier ladder — `getTier()` etc. |
| `src/main.zig` | `main()` CLI entry, card renderers |

## Distribution

**Source distribution** (poster child):
```bash
git clone https://github.com/Wolfe-Jam/bun-sticky-zig
cd bun-sticky-zig
zig build -Doptimize=ReleaseFast
```

## Why Zig?

**Bun is built on Zig.** This is how they would build it.

- Zero runtime dependencies
- 77KB release binary
- Sub-millisecond cold start
- Zig 0.15+ compatible

## Development Rules

1. **Zero Dependencies** - Only Zig std lib
2. **Wolfejam slots only** - Never use Elon weights
3. **Tests first** - All changes need tests
4. **Source distribution** - Clone + build

---
*Part of FAF ecosystem. Built for Bun/Anthropic.*

# bun-sticky

Fastest bun under the sum. Zig-native FAF CLI.

## Quick Commands

```bash
zig build test                           # Run 136 tests
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

**Wolfejam Slot-Based Scoring**:

- 21 total slots across 5 categories
- Type-aware: CLI=9, Fullstack=21, etc.
- Formula: `Score = (Filled / Applicable) × 100`

| Category | Slots | Fields |
|----------|-------|--------|
| Project | 3 | name, goal, main_language |
| Frontend | 4 | frontend, css_framework, ui_library, state_management |
| Backend | 5 | backend, api_type, runtime, database, connection |
| Universal | 3 | hosting, build, cicd |
| Human | 6 | who, what, why, where, when, how |

## Tier System

| Score | Tier | Emoji | Notes |
|-------|------|-------|-------|
| 105% | Big Croissant | 🥐 | AI-awarded for excellence beyond 100% |
| 100% | Trophy | 🏆 | Perfect score |
| 99%+ | Gold | 🥇 | |
| 95%+ | Silver | 🥈 | |
| 85%+ | Bronze | 🥉 | Production ready |
| 70%+ | Green | 🟢 | |
| 55%+ | Yellow | 🟡 | |
| <55% | Red | 🔴 | |

**Big Croissant** is the Michelin Star - awarded for projects that score 100% AND demonstrate excellence: great docs, clean code, fast, well-tested.

## Key Files

| File | Purpose |
|------|---------|
| `src/scorer.zig:16` | SLOTS definition (21 slots) |
| `src/scorer.zig:60` | ProjectType enum |
| `src/scorer.zig:248` | calculateScore() function |
| `src/tier.zig:42` | getTier() function |
| `src/main.zig:72` | main() CLI entry |

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

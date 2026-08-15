# 🏁 WJTTC Test Suite — bun-sticky-zig

**Wolfe-Jam Test & Tuning Certification** — championship-grade coverage for the
Zig-native FAF CLI. Zero dependencies, runs on the metal.

```bash
zig build test --summary all     # 157/157 tests passed
```

## Layout

| Artifact | Tests | Covers |
|----------|------:|--------|
| `src/tests.zig` | 93 | Scoring formula, slot definitions, type detection, tier boundaries, edge cases |
| `src/main.zig` | 43 | Render/CLI layer + WJTTC race tiers (below) |
| `src/scorer.zig` | 9 | In-module scorer unit tests |
| `src/tier.zig` | 12 | In-module tier unit tests — single source of truth for the ladder |

## The race tiers (`src/main.zig`)

The render and CLI surface — the parts that emit cards, badges, and JSON — are
certified across four F1-inspired tiers:

### 🏎️ ENGINE — core decision logic
Pure, deterministic functions, tested at every boundary:
- `tier.getTierHex(score)` / `tier.getTierEmoji(score)` (from `tier.zig` — the
  only tier implementation; main.zig used to carry a second, disagreeing copy)
- `barColor(pct)` — section bar fill at 85/55 cutoffs
- `sectionRows()` — the 6 canonical sections (5 base + Enterprise), always in order

### 🎨 LIVERY — card output is well-formed and complete
Renderers are captured into a buffer and asserted:
- SVG card opens `<svg`, closes `</svg>`, and carries every design element (✪ proof-seal glyph, dark gradient `url(#bg)`, glow filter, score, tier name, project name)
- **Tier label is right-aligned** (`text-anchor="end"`) — the regression lock for the v1.3.1 collision fix; the old hard-coded `x="128"` coordinate must never return
- HTML and ASCII cards render non-empty and name-bearing
- `grab` emits a JSON object carrying `_score` and `_tier`

### 🛑 BRAKE — safety, never emit broken markup
- `htmlEsc` neutralizes `< > & "` → entities; no raw tag survives
- A hostile project name (`</text><script>…`) is escaped, not emitted verbatim, and the SVG still closes cleanly

### 🌬️ AERO — fuzz, stress, determinism (the bug-finders)
Reproducible seeded fuzzing — *more data finds latent bugs*:
- 8,000 random-byte inputs to the scorer → never crashes, `score ≤ 100`, `filled ≤ total`
- 3,000 random-content card renders → never crash, output stays within the 64KB bound
- 3,000 hostile-byte project names → SVG stays well-formed (opens `<svg`, closes `</svg>`)
- Determinism: identical input yields **byte-identical** card output

## Test capture hook

The card/JSON renderers write to STDOUT via a thin `print`/`puts` layer. A
test-only `card_sink` (an allocation-free fixed buffer, null in production)
redirects that output into memory so the renderers are fully assertable — with
**zero overhead on the shipped binary** (the null branch is the production path).

---
*Part of the FAF · Zig family. Bun is built on Zig — so are we.*

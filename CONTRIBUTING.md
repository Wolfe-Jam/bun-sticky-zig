# Contributing to bun-sticky

Thanks for your interest in contributing!

## Quick Start

```bash
git clone https://github.com/Wolfe-Jam/bun-sticky-zig
cd bun-sticky-zig
zig build test --summary all
```

## Development

```bash
zig build                           # Debug build
zig build -Doptimize=ReleaseFast    # Release build
zig build test --summary all        # 136/136 tests
./zig-out/bin/faf score      # Test locally
```

## Guidelines

1. **Zero dependencies** - Only Zig std lib
2. **Tests required** - All changes need tests
3. **Wolfejam slots** - Never use Elon weights
4. **Keep it fast** - Sub-millisecond is the goal

## Pull Requests

1. Fork the repo
2. Create a branch (`git checkout -b feature/thing`)
3. Make changes + add tests
4. Run `zig build test --summary all`
5. Submit PR

## Code Style

- Follow existing patterns
- Keep functions small
- Add doc comments for public APIs

## Questions?

Open an issue.

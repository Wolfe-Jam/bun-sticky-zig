# Contributing to bun-sticky

Thanks for your interest in contributing!

## Quick Start

```bash
git clone https://github.com/wolfejam/bun-sticky-zig
cd bun-sticky-zig
zig build test
```

## Development

```bash
zig build                           # Debug build
zig build -Doptimize=ReleaseFast    # Release build
zig build test                      # Run all tests
./zig-out/bin/bun-sticky score      # Test locally
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
4. Run `zig build test`
5. Submit PR

## Code Style

- Follow existing patterns
- Keep functions small
- Add doc comments for public APIs

## Questions?

Open an issue.

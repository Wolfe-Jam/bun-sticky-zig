///! bun-sticky - Fastest bun under the sum
///!
///! Zero dependencies. Pure Zig.
///! Wolfejam slot-based scoring.
///!
///! The poster child FAF CLI for Bun/Anthropic.

const std = @import("std");
const scorer = @import("scorer.zig");
const tier = @import("tier.zig");
const posix = std.posix;
const fs = std.fs;

const VERSION = "1.0.0";

// Global color state
var no_color: bool = false;

// ANSI colors (functions to respect --no-color)
fn CYAN() []const u8 {
    return if (no_color) "" else "\x1b[36m";
}
fn GREEN() []const u8 {
    return if (no_color) "" else "\x1b[32m";
}
fn YELLOW() []const u8 {
    return if (no_color) "" else "\x1b[33m";
}
fn RED() []const u8 {
    return if (no_color) "" else "\x1b[31m";
}
fn BOLD() []const u8 {
    return if (no_color) "" else "\x1b[1m";
}
fn DIM() []const u8 {
    return if (no_color) "" else "\x1b[2m";
}
fn RESET() []const u8 {
    return if (no_color) "" else "\x1b[0m";
}

const BANNER =
    \\
    \\────────────────────────────────────────────────
    \\
    \\   ▄▄       ▄▀▀▀ ▀█▀ █ ▄▀▀ █▄▀ █ █
    \\  ████      ▀▀█▄  █  █ █   █▀▄  █
    \\██████      ▄▄▄▀  █  █ ▀▀▀ █ █  █
    \\████████
    \\████████    █▀▄  █ █ █▀▄   ▀▀█ █ ▄▀▀
    \\ ██████     ██▀  █ █ █ █   ▄ ▀ █ █ ▄
    \\   ████     █▄▀  ▀▄▀ █ █   █▄▄ █ ▀▀█
    \\     ▀▀
    \\
    \\bun-sticky v1.0.0 [ZIG]
    \\Fastest bun under the sum.
    \\
    \\────────────────────────────────────────────────
    \\
;

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    _ = posix.write(posix.STDOUT_FILENO, msg) catch {};
}

fn puts(s: []const u8) void {
    _ = posix.write(posix.STDOUT_FILENO, s) catch {};
}

pub fn main() !void {
    var args = std.process.args();

    // Skip program name
    _ = args.skip();

    // Check for --no-color flag first
    var cmd: []const u8 = "help";
    var init_name: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--no-color")) {
            no_color = true;
        } else if (cmd[0] == 'h' and cmd.len == 4) {
            // First non-flag arg is the command
            cmd = arg;
        } else if (std.mem.eql(u8, cmd, "init") and init_name == null) {
            init_name = arg;
        }
    }

    if (std.mem.eql(u8, cmd, "score")) {
        try cmdScore();
    } else if (std.mem.eql(u8, cmd, "init")) {
        const name = init_name orelse {
            print("{s}Usage: faf init <name>{s}\n", .{ RED(), RESET() });
            return;
        };
        try cmdInit(name);
    } else if (std.mem.eql(u8, cmd, "sync")) {
        try cmdSync();
    } else if (std.mem.eql(u8, cmd, "version") or std.mem.eql(u8, cmd, "-v") or std.mem.eql(u8, cmd, "--version")) {
        print("bun-sticky v{s}\n", .{VERSION});
    } else if (std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
        cmdHelp();
    } else {
        cmdHelp();
    }
}

fn cmdScore() !void {
    // Read project.faf
    const file = fs.cwd().openFile("project.faf", .{}) catch {
        print("{s}No project.faf found{s}\n", .{ RED(), RESET() });
        print("{s}Run: faf init <name>{s}\n", .{ DIM(), RESET() });
        return;
    };
    defer file.close();

    var buf: [16384]u8 = undefined;
    const content = file.readAll(&buf) catch {
        print("{s}Error reading project.faf{s}\n", .{ RED(), RESET() });
        return;
    };

    const faf_content = buf[0..content];

    // Calculate score
    const result = scorer.calculateScore(faf_content);
    const t = tier.getTier(result.score);

    // Print banner
    puts(BANNER);

    // Extract project name
    var name: []const u8 = "Unknown";
    if (std.mem.indexOf(u8, faf_content, "name:")) |idx| {
        var start = idx + 5;
        while (start < faf_content.len and (faf_content[start] == ' ' or faf_content[start] == '\t')) {
            start += 1;
        }
        var end = start;
        while (end < faf_content.len and faf_content[end] != '\n' and faf_content[end] != '\r') {
            end += 1;
        }
        name = faf_content[start..end];
    }

    print("  Project: {s}{s}{s}\n", .{ BOLD(), name, RESET() });
    print("  Type:    {s}{s}{s}\n\n", .{ DIM(), @tagName(result.project_type), RESET() });

    // Section breakdown
    if (result.project.total > 0) {
        printBar("Project  ", result.project);
    }
    if (result.frontend.total > 0) {
        printBar("Frontend ", result.frontend);
    }
    if (result.backend.total > 0) {
        printBar("Backend  ", result.backend);
    }
    if (result.universal.total > 0) {
        printBar("Universal", result.universal);
    }
    if (result.human.total > 0) {
        printBar("Human    ", result.human);
    }

    puts("\n");

    // Total score with tier
    print("  {s}{s} {s}{d}%{s} {s}{s}{s}\n", .{
        if (no_color) "" else t.color,
        t.emoji,
        BOLD(),
        result.score,
        RESET(),
        if (no_color) "" else t.color,
        t.name,
        RESET(),
    });
    print("  {s}Filled: {d}/{d} slots{s}\n\n", .{ DIM(), result.filled, result.total, RESET() });

    // Show missing slots if not 100%
    if (result.score < 100) {
        print("  {s}Missing slots:{s}\n", .{ YELLOW(), RESET() });
        printMissingSlots(faf_content, result);
        puts("\n");
    }
}

fn printBar(label: []const u8, section: scorer.SectionResult) void {
    const width: u8 = 12;
    // Use u16 to avoid overflow (100 * 12 = 1200)
    const filled_blocks: u8 = @intCast((@as(u16, section.percentage) * @as(u16, width)) / 100);
    const empty_blocks = width - filled_blocks;

    const color = if (section.percentage >= 85) GREEN() else if (section.percentage >= 55) YELLOW() else RED();

    print("  {s}{s}{s} {s}", .{ DIM(), label, RESET(), color });

    var i: u8 = 0;
    while (i < filled_blocks) : (i += 1) {
        puts("\xe2\x96\x88"); // Block char
    }
    i = 0;
    while (i < empty_blocks) : (i += 1) {
        puts("\xe2\x96\x91"); // Light block
    }

    print("{s} {d}/{d}\n", .{ RESET(), section.filled, section.total });
}

fn printMissingSlots(content: []const u8, result: scorer.ScoreResult) void {
    // Check project slots
    if (result.project.total > 0) {
        for (scorer.PROJECT_SLOTS) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                print("    {s}{s}{s}: \"{s}\"\n", .{ CYAN(), slot, RESET(), getHint(slot) });
            }
        }
    }

    // Check human slots
    if (result.human.total > 0) {
        for (scorer.HUMAN_SLOTS) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                print("    {s}{s}{s}: \"{s}\"\n", .{ CYAN(), slot, RESET(), getHint(slot) });
            }
        }
    }

    // Check frontend slots if applicable
    if (result.frontend.total > 0) {
        for (scorer.FRONTEND_SLOTS) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                print("    {s}{s}{s}: \"{s}\"\n", .{ CYAN(), slot, RESET(), getHint(slot) });
            }
        }
    }

    // Check backend slots if applicable
    if (result.backend.total > 0) {
        for (scorer.BACKEND_SLOTS) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                print("    {s}{s}{s}: \"{s}\"\n", .{ CYAN(), slot, RESET(), getHint(slot) });
            }
        }
    }

    // Check universal slots if applicable
    if (result.universal.total > 0) {
        for (scorer.UNIVERSAL_SLOTS) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                print("    {s}{s}{s}: \"{s}\"\n", .{ CYAN(), slot, RESET(), getHint(slot) });
            }
        }
    }
}

fn getHint(slot: []const u8) []const u8 {
    // Project hints
    if (std.mem.eql(u8, slot, "project.name")) return "Project name";
    if (std.mem.eql(u8, slot, "project.goal")) return "What problem does this solve?";
    if (std.mem.eql(u8, slot, "project.main_language")) return "TypeScript";

    // Human context hints (questions)
    if (std.mem.eql(u8, slot, "human_context.who")) return "Who is it for?";
    if (std.mem.eql(u8, slot, "human_context.what")) return "What does it do?";
    if (std.mem.eql(u8, slot, "human_context.why")) return "Why does it exist?";
    if (std.mem.eql(u8, slot, "human_context.where")) return "Where is it deployed?";
    if (std.mem.eql(u8, slot, "human_context.when")) return "When is it due?";
    if (std.mem.eql(u8, slot, "human_context.how")) return "How is it built?";

    // Stack hints
    if (std.mem.eql(u8, slot, "stack.frontend")) return "React";
    if (std.mem.eql(u8, slot, "stack.css_framework")) return "Tailwind";
    if (std.mem.eql(u8, slot, "stack.ui_library")) return "shadcn";
    if (std.mem.eql(u8, slot, "stack.state_management")) return "zustand";
    if (std.mem.eql(u8, slot, "stack.backend")) return "Node.js";
    if (std.mem.eql(u8, slot, "stack.api_type")) return "REST";
    if (std.mem.eql(u8, slot, "stack.runtime")) return "Bun";
    if (std.mem.eql(u8, slot, "stack.database")) return "PostgreSQL";
    if (std.mem.eql(u8, slot, "stack.connection")) return "prisma";
    if (std.mem.eql(u8, slot, "stack.hosting")) return "Vercel";
    if (std.mem.eql(u8, slot, "stack.build")) return "vite";
    if (std.mem.eql(u8, slot, "stack.cicd")) return "GitHub Actions";

    return "";
}

fn detectLanguage() struct { lang: []const u8, runtime: []const u8, build: []const u8 } {
    const cwd = fs.cwd();

    // Check for common project files
    if (cwd.openFile("package.json", .{})) |f| {
        f.close();
        return .{ .lang = "TypeScript", .runtime = "Bun", .build = "bun run build" };
    } else |_| {}

    if (cwd.openFile("Cargo.toml", .{})) |f| {
        f.close();
        return .{ .lang = "Rust", .runtime = "Rust", .build = "cargo build" };
    } else |_| {}

    if (cwd.openFile("go.mod", .{})) |f| {
        f.close();
        return .{ .lang = "Go", .runtime = "Go", .build = "go build" };
    } else |_| {}

    if (cwd.openFile("pyproject.toml", .{})) |f| {
        f.close();
        return .{ .lang = "Python", .runtime = "Python", .build = "pip install -e ." };
    } else |_| {}

    if (cwd.openFile("build.zig", .{})) |f| {
        f.close();
        return .{ .lang = "Zig", .runtime = "Zig", .build = "zig build" };
    } else |_| {}

    // Default to Zig (we're a Zig tool after all)
    return .{ .lang = "Zig", .runtime = "Zig", .build = "zig build" };
}

fn cmdInit(name: []const u8) !void {
    // Check if file exists
    if (fs.cwd().openFile("project.faf", .{})) |file| {
        file.close();
        print("{s}project.faf already exists{s}\n", .{ YELLOW(), RESET() });
        return;
    } else |_| {}

    // Detect language from project files
    const detected = detectLanguage();

    // Create template
    const file = try fs.cwd().createFile("project.faf", .{});
    defer file.close();

    var buf: [2048]u8 = undefined;
    const template = std.fmt.bufPrint(&buf,
        \\# {s} - Project DNA
        \\# Generated by bun-sticky
        \\
        \\faf_version: 2.5.0
        \\
        \\project:
        \\  name: {s}
        \\  goal: Define your project goal here
        \\  main_language: {s}
        \\  type: cli
        \\  version: 0.1.0
        \\
        \\human_context:
        \\  who: Your target users
        \\  what: What this project does
        \\  why: Why it exists
        \\  where: Where it runs
        \\  when: When to use it
        \\  how: How to get started
        \\
        \\stack:
        \\  runtime: {s}
        \\  build: {s}
        \\
    , .{ name, name, detected.lang, detected.runtime, detected.build }) catch return;

    _ = file.writeAll(template) catch return;

    puts(BANNER);
    print("  {s}Created{s} project.faf\n", .{ GREEN(), RESET() });
    print("  {s}Run: faf score{s}\n\n", .{ DIM(), RESET() });
}

fn cmdSync() !void {
    // Read project.faf
    const file = fs.cwd().openFile("project.faf", .{}) catch {
        print("{s}No project.faf found{s}\n", .{ RED(), RESET() });
        return;
    };
    defer file.close();

    var buf: [16384]u8 = undefined;
    const content = file.readAll(&buf) catch {
        print("{s}Error reading project.faf{s}\n", .{ RED(), RESET() });
        return;
    };

    const faf_content = buf[0..content];

    // Calculate score
    const result = scorer.calculateScore(faf_content);
    const t = tier.getTier(result.score);

    // Extract name and goal
    var name: []const u8 = "Project";
    var goal: []const u8 = "";

    if (std.mem.indexOf(u8, faf_content, "name:")) |idx| {
        var start = idx + 5;
        while (start < faf_content.len and (faf_content[start] == ' ' or faf_content[start] == '\t')) {
            start += 1;
        }
        var end = start;
        while (end < faf_content.len and faf_content[end] != '\n') {
            end += 1;
        }
        name = faf_content[start..end];
    }

    if (std.mem.indexOf(u8, faf_content, "goal:")) |idx| {
        var start = idx + 5;
        while (start < faf_content.len and (faf_content[start] == ' ' or faf_content[start] == '\t')) {
            start += 1;
        }
        var end = start;
        while (end < faf_content.len and faf_content[end] != '\n') {
            end += 1;
        }
        goal = faf_content[start..end];
    }

    // Write CLAUDE.md
    const out_file = try fs.cwd().createFile("CLAUDE.md", .{});
    defer out_file.close();

    var out_buf: [2048]u8 = undefined;
    const md = std.fmt.bufPrint(&out_buf,
        \\# {s}
        \\
        \\{s}
        \\
        \\## Score: {s} {d}%
        \\
        \\Filled: {d}/{d} slots
        \\
        \\---
        \\*Synced by bun-sticky*
        \\
    , .{ name, goal, t.emoji, result.score, result.filled, result.total }) catch return;

    _ = out_file.writeAll(md) catch return;

    puts(BANNER);
    print("  {s}Synced{s} project.faf -> CLAUDE.md\n", .{ GREEN(), RESET() });
    print("  {s}by bun-sticky (Zig Edition){s}\n\n", .{ DIM(), RESET() });
}

fn cmdHelp() void {
    puts(BANNER);
    print("  {s}Commands{s}\n\n", .{ BOLD(), RESET() });
    puts("    score         Show FAF score + tier\n");
    puts("    init <n>      Create project.faf\n");
    puts("    sync          Sync to CLAUDE.md\n");
    puts("    version       Show version\n");
    puts("    help          Show this help\n\n");
    print("  {s}Options{s}\n\n", .{ BOLD(), RESET() });
    puts("    --no-color    Disable colored output\n\n");
    print("  {s}Zero dependencies. Pure Zig.{s}\n", .{ DIM(), RESET() });
    print("  {s}Wolfejam slot-based scoring.{s}\n\n", .{ DIM(), RESET() });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "hints return values" {
    try std.testing.expect(getHint("project.name").len > 0);
    try std.testing.expect(getHint("human_context.who").len > 0);
}

test "import scorer" {
    const result = scorer.calculateScore("project:\n  name: test\n  type: cli\n");
    try std.testing.expect(result.score > 0);
}

test "import tier" {
    const t = tier.getTier(100);
    try std.testing.expectEqualStrings("Trophy", t.name);
}

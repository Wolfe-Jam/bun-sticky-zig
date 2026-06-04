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

const VERSION = "1.3.0";

// Global flags
var no_color: bool = false;
var json_output: bool = false;
var badge_output: bool = false;
var min_threshold: ?u32 = null;
var print_html: bool = false;
var ascii_output: bool = false;
var svg_output: bool = false;

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
    \\bun-sticky v1.3.0 [ZIG]
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

    var cmd: []const u8 = "help";
    var init_name: ?[]const u8 = null;
    var want_min = false;

    while (args.next()) |arg| {
        if (want_min) {
            min_threshold = std.fmt.parseInt(u32, arg, 10) catch null;
            want_min = false;
        } else if (std.mem.eql(u8, arg, "--no-color")) {
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            json_output = true;
            no_color = true; // JSON mode implies no color
        } else if (std.mem.eql(u8, arg, "--badge")) {
            badge_output = true;
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--grabjson")) {
            cmd = "grab"; // flag alias for the `grab` command
        } else if (std.mem.eql(u8, arg, "--print")) {
            print_html = true;
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--ascii")) {
            ascii_output = true;
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--svg")) {
            svg_output = true;
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--min")) {
            want_min = true; // next arg is the threshold
        } else if (cmd[0] == 'h' and cmd.len == 4) {
            // First non-flag arg is the command
            cmd = arg;
        } else if (std.mem.eql(u8, cmd, "init") and init_name == null) {
            init_name = arg;
        }
    }

    // Output flags with no command imply `score`.
    if (std.mem.eql(u8, cmd, "help") and (json_output or badge_output or print_html or ascii_output or svg_output)) {
        cmd = "score";
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
    } else if (std.mem.eql(u8, cmd, "grab")) {
        try cmdGrab();
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

    // CI gate threshold (set via `--min N`)
    const below_min = if (min_threshold) |m| result.score < m else false;

    // Badge output for READMEs (--badge): ready-to-paste shields.io markdown
    if (badge_output) {
        const bcolor = if (result.score >= 100) "brightgreen" else if (result.score >= 85) "green" else if (result.score >= 70) "yellowgreen" else if (result.score >= 55) "yellow" else if (result.score >= 1) "orange" else "lightgrey";
        print("![FAF](https://img.shields.io/badge/FAF-{d}%25%20{s}-{s})\n", .{ result.score, t.name, bcolor });
        if (below_min) std.process.exit(1);
        return;
    }

    // JSON output for CI / automation (lean: structured, no banner)
    if (json_output) {
        print("{{\"score\":{d},\"tier\":\"{s}\",\"filled\":{d},\"total\":{d},\"type\":\"{s}\",\"name\":\"{s}\"}}\n", .{
            result.score,
            t.name,
            result.filled,
            result.total,
            @tagName(result.project_type),
            name,
        });
        if (below_min) std.process.exit(1);
        return;
    }

    const lang = extractValue(faf_content, "main_language:");

    // ASCII score card (--ascii) — pure text, paste anywhere
    if (ascii_output) {
        printAsciiCard(faf_content, result, t.name, name, lang);
        if (below_min) std.process.exit(1);
        return;
    }

    // HTML score card (--print) — stdout snippet to move into a page
    if (print_html) {
        printHtmlCard(faf_content, result, t.name, name, lang);
        if (below_min) std.process.exit(1);
        return;
    }

    // SVG trading card (--svg) — embeddable, self-hosted, scales clean
    if (svg_output) {
        printSvgCard(faf_content, result, t.name, name, lang);
        if (below_min) std.process.exit(1);
        return;
    }

    // Print banner (human mode)
    puts(BANNER);

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

    // CI gate: exit non-zero if below --min threshold
    if (below_min) std.process.exit(1);
}

// ── JSON writer (escaped, fixed-buffer) ──────────────────────────────
const JsonW = struct {
    buf: []u8,
    len: usize = 0,
    fn rawc(self: *JsonW, c: u8) void {
        if (self.len < self.buf.len) {
            self.buf[self.len] = c;
            self.len += 1;
        }
    }
    fn raw(self: *JsonW, s: []const u8) void {
        for (s) |c| self.rawc(c);
    }
    fn str(self: *JsonW, s: []const u8) void {
        self.rawc('"');
        for (s) |c| switch (c) {
            '"' => self.raw("\\\""),
            '\\' => self.raw("\\\\"),
            '\n' => self.raw("\\n"),
            '\r' => self.raw("\\r"),
            '\t' => self.raw("\\t"),
            else => {
                if (c < 0x20) {
                    var tmp: [8]u8 = undefined;
                    self.raw(std.fmt.bufPrint(&tmp, "\\u{x:0>4}", .{c}) catch "");
                } else self.rawc(c);
            },
        };
        self.rawc('"');
    }
    fn num(self: *JsonW, v: u8) void {
        var tmp: [8]u8 = undefined;
        self.raw(std.fmt.bufPrint(&tmp, "{d}", .{v}) catch "0");
    }
    fn comma(self: *JsonW, first: *bool) void {
        if (first.*) first.* = false else self.rawc(',');
    }
    fn slice(self: *JsonW) []const u8 {
        return self.buf[0..self.len];
    }
};

// `faf grab` (--grabjson): emit the parsed .faf as JSON — the CONTENT, not just
// the score — so tools can grab a project's context. Score+tier appended as _score/_tier.
fn cmdGrab() !void {
    const file = fs.cwd().openFile("project.faf", .{}) catch {
        puts("{\"error\":\"no project.faf found\"}\n");
        return;
    };
    defer file.close();
    var buf: [16384]u8 = undefined;
    const n = file.readAll(&buf) catch {
        puts("{\"error\":\"could not read project.faf\"}\n");
        return;
    };
    const content = buf[0..n];

    const result = scorer.calculateScore(content);
    const t = tier.getTier(result.score);

    var out: [32768]u8 = undefined;
    var w = JsonW{ .buf = &out };
    w.rawc('{');
    var first = true;
    var in_section = false;
    var sec_first = false;

    var it = std.mem.splitScalar(u8, content, '\n');
    while (it.next()) |raw_line| {
        var line = raw_line;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0) continue;
        var indent: usize = 0;
        while (indent < line.len and line[indent] == ' ') indent += 1;
        const trimmed = line[indent..];
        if (trimmed.len == 0 or trimmed[0] == '#' or trimmed[0] == '-') continue;
        const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const key = std.mem.trim(u8, trimmed[0..colon], " ");
        var val = std.mem.trim(u8, trimmed[colon + 1 ..], " ");
        if (key.len == 0) continue;
        if (std.mem.indexOf(u8, val, " #")) |h| val = std.mem.trim(u8, val[0..h], " "); // strip trailing comment

        if (indent == 0) {
            if (in_section) {
                w.rawc('}');
                in_section = false;
            }
            if (val.len == 0) {
                w.comma(&first);
                w.str(key);
                w.rawc(':');
                w.rawc('{');
                in_section = true;
                sec_first = true;
            } else {
                w.comma(&first);
                w.str(key);
                w.rawc(':');
                w.str(val);
            }
        } else {
            if (!in_section or val.len == 0) continue; // skip list-parents / nested
            w.comma(&sec_first);
            w.str(key);
            w.rawc(':');
            w.str(val);
        }
    }
    if (in_section) w.rawc('}');
    w.comma(&first);
    w.str("_score");
    w.rawc(':');
    w.num(result.score);
    w.comma(&first);
    w.str("_tier");
    w.rawc(':');
    w.str(t.name);
    w.rawc('}');
    w.rawc('\n');
    puts(w.slice());
}

// Generalized "key: value" extractor (first match, to end of line).
fn extractValue(content: []const u8, key: []const u8) []const u8 {
    if (std.mem.indexOf(u8, content, key)) |idx| {
        var start = idx + key.len;
        while (start < content.len and (content[start] == ' ' or content[start] == '\t')) start += 1;
        var end = start;
        while (end < content.len and content[end] != '\n' and content[end] != '\r') end += 1;
        return std.mem.trim(u8, content[start..end], " ");
    }
    return "—";
}

const SectionRow = struct { label: []const u8, r: scorer.SectionResult };
fn sectionRows(result: scorer.ScoreResult) [5]SectionRow {
    return .{
        .{ .label = "Project", .r = result.project },
        .{ .label = "Frontend", .r = result.frontend },
        .{ .label = "Backend", .r = result.backend },
        .{ .label = "Universal", .r = result.universal },
        .{ .label = "Human", .r = result.human },
    };
}

// Print the empty (missing) slot keys, comma-separated. Returns true if any printed.
fn printMissingNames(content: []const u8, result: scorer.ScoreResult) bool {
    const Grp = struct { on: bool, slots: []const []const u8 };
    const grps = [_]Grp{
        .{ .on = result.project.total > 0, .slots = &scorer.PROJECT_SLOTS },
        .{ .on = result.frontend.total > 0, .slots = &scorer.FRONTEND_SLOTS },
        .{ .on = result.backend.total > 0, .slots = &scorer.BACKEND_SLOTS },
        .{ .on = result.universal.total > 0, .slots = &scorer.UNIVERSAL_SLOTS },
        .{ .on = result.human.total > 0, .slots = &scorer.HUMAN_SLOTS },
    };
    var any = false;
    for (grps) |g| {
        if (!g.on) continue;
        for (g.slots) |slot| {
            if (!scorer.hasSlotValue(content, slot)) {
                if (any) puts(", ");
                puts(slot);
                any = true;
            }
        }
    }
    return any;
}

fn htmlEsc(s: []const u8) void {
    for (s) |c| switch (c) {
        '&' => puts("&amp;"),
        '<' => puts("&lt;"),
        '>' => puts("&gt;"),
        '"' => puts("&quot;"),
        else => {
            const b = [_]u8{c};
            puts(&b);
        },
    };
}

// --ascii: pure-text score card — the dev's project context + score + what's missing.
fn printAsciiCard(content: []const u8, result: scorer.ScoreResult, tier_name: []const u8, name: []const u8, lang: []const u8) void {
    puts("\n");
    print("  {s}\n", .{name});
    print("  {s} \xc2\xb7 {s}\n", .{ @tagName(result.project_type), lang });
    puts("  ----------------------------------------\n");
    print("  FAF  {d}%  {s}   {d}/{d} slots\n", .{ result.score, tier_name, result.filled, result.total });
    puts("  ----------------------------------------\n");
    for (sectionRows(result)) |s| {
        if (s.r.total == 0) continue;
        const width: u8 = 12;
        const fb: u8 = @intCast((@as(u16, s.r.percentage) * @as(u16, width)) / 100);
        print("  {s:<9}  ", .{s.label});
        var i: u8 = 0;
        while (i < fb) : (i += 1) puts("\xe2\x96\x88");
        i = 0;
        while (i < width - fb) : (i += 1) puts("\xe2\x96\x91");
        print("  {d}%\n", .{s.r.percentage});
    }
    puts("  ----------------------------------------\n");
    puts("  Missing: ");
    if (!printMissingNames(content, result)) puts("none");
    puts("\n\n");
}

// --print: self-contained HTML score card — drop/move into any page.
fn printHtmlCard(content: []const u8, result: scorer.ScoreResult, tier_name: []const u8, name: []const u8, lang: []const u8) void {
    const tcolor = if (result.score >= 100) "#1d8348" else if (result.score >= 85) "#27c93f" else if (result.score >= 55) "#d4a000" else "#c0392b";
    puts("<div style=\"max-width:380px;font-family:-apple-system,Segoe UI,sans-serif;border:1px solid #e5e5e5;border-radius:12px;padding:20px;background:#fff;color:#1a1a1a\">\n");
    puts("  <div style=\"font-size:20px;font-weight:800\">");
    htmlEsc(name);
    puts("</div>\n  <div style=\"color:#5b6570;font-size:13px;margin-bottom:14px\">");
    htmlEsc(@tagName(result.project_type));
    puts(" \xc2\xb7 ");
    htmlEsc(lang);
    puts("</div>\n");
    puts("  <div style=\"font-size:12px;color:#5b6570;letter-spacing:.08em\">FAF SCORE</div>\n");
    print("  <div style=\"font-size:40px;font-weight:800;color:{s}\">{d}%<span style=\"font-size:18px;font-weight:700;margin-left:8px;color:#1a1a1a\">{s}</span></div>\n", .{ tcolor, result.score, tier_name });
    print("  <div style=\"color:#5b6570;font-size:13px;margin-bottom:14px\">{d} / {d} slots</div>\n", .{ result.filled, result.total });
    for (sectionRows(result)) |s| {
        if (s.r.total == 0) continue;
        const bc = if (s.r.percentage >= 85) "#27c93f" else if (s.r.percentage >= 55) "#d4a000" else "#c0392b";
        print("  <div style=\"display:flex;align-items:center;gap:8px;margin:5px 0;font-size:12px\"><span style=\"width:72px;color:#5b6570\">{s}</span><span style=\"flex:1;height:8px;background:#eee;border-radius:4px;overflow:hidden\"><span style=\"display:block;height:8px;width:{d}%;background:{s}\"></span></span><span style=\"width:34px;text-align:right;color:#1a1a1a\">{d}%</span></div>\n", .{ s.label, s.r.percentage, bc, s.r.percentage });
    }
    puts("  <div style=\"font-size:12px;color:#5b6570;margin-top:12px\">Missing: <span style=\"color:#1a1a1a\">");
    if (!printMissingNames(content, result)) puts("none");
    puts("</span></div>\n</div>\n");
}

// --svg: embeddable trading-card SVG (self-hosted, scales clean, README <img>).
// Tier-colored border = rarity. Same dev data as the other cards.
fn printSvgCard(content: []const u8, result: scorer.ScoreResult, tier_name: []const u8, name: []const u8, lang: []const u8) void {
    var sec_count: u8 = 0;
    for (sectionRows(result)) |s| {
        if (s.r.total > 0) sec_count += 1;
    }
    const W: u16 = 340;
    const bars_top: u16 = 172;
    const H: u16 = bars_top + @as(u16, sec_count) * 24 + 44;
    const tcolor = if (result.score >= 100) "#1d8348" else if (result.score >= 85) "#27c93f" else if (result.score >= 55) "#d4a000" else "#c0392b";

    print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d}\" height=\"{d}\" viewBox=\"0 0 {d} {d}\" font-family=\"-apple-system,Segoe UI,Helvetica,Arial,sans-serif\">\n", .{ W, H, W, H });
    print("<rect x=\"1.5\" y=\"1.5\" width=\"{d}\" height=\"{d}\" rx=\"16\" fill=\"#ffffff\" stroke=\"{s}\" stroke-width=\"3\"/>\n", .{ W - 3, H - 3, tcolor });
    puts("<text x=\"22\" y=\"46\" font-size=\"22\" font-weight=\"700\" fill=\"#1a1a1a\">");
    htmlEsc(name);
    puts("</text>\n<text x=\"22\" y=\"68\" font-size=\"13\" fill=\"#5b6570\">");
    htmlEsc(@tagName(result.project_type));
    puts(" \xc2\xb7 ");
    htmlEsc(lang);
    puts("</text>\n");
    puts("<text x=\"22\" y=\"100\" font-size=\"11\" letter-spacing=\"1.5\" fill=\"#5b6570\">FAF SCORE</text>\n");
    print("<text x=\"22\" y=\"140\" font-size=\"42\" font-weight=\"800\" fill=\"{s}\">{d}%</text>\n", .{ tcolor, result.score });
    print("<text x=\"128\" y=\"140\" font-size=\"19\" font-weight=\"700\" fill=\"#1a1a1a\">{s}</text>\n", .{tier_name});
    print("<text x=\"22\" y=\"160\" font-size=\"12\" fill=\"#5b6570\">{d} / {d} slots</text>\n", .{ result.filled, result.total });

    var y: u16 = bars_top;
    for (sectionRows(result)) |s| {
        if (s.r.total == 0) continue;
        const bc = if (s.r.percentage >= 85) "#27c93f" else if (s.r.percentage >= 55) "#d4a000" else "#c0392b";
        const fw: u16 = @intCast((@as(u32, s.r.percentage) * 150) / 100);
        print("<text x=\"22\" y=\"{d}\" font-size=\"11\" fill=\"#5b6570\">{s}</text>\n", .{ y + 9, s.label });
        print("<rect x=\"100\" y=\"{d}\" width=\"150\" height=\"8\" rx=\"4\" fill=\"#eeeeee\"/>\n", .{y + 2});
        print("<rect x=\"100\" y=\"{d}\" width=\"{d}\" height=\"8\" rx=\"4\" fill=\"{s}\"/>\n", .{ y + 2, fw, bc });
        print("<text x=\"262\" y=\"{d}\" font-size=\"11\" fill=\"#1a1a1a\">{d}%</text>\n", .{ y + 9, s.r.percentage });
        y += 24;
    }
    print("<text x=\"22\" y=\"{d}\" font-size=\"11\" fill=\"#5b6570\">Missing: <tspan fill=\"#1a1a1a\">", .{y + 14});
    if (!printMissingNames(content, result)) puts("none");
    puts("</tspan></text>\n</svg>\n");
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
    puts("    grab          Emit parsed .faf as JSON (grab context)\n");
    puts("    version       Show version\n");
    puts("    help          Show this help\n\n");
    print("  {s}Options{s}\n\n", .{ BOLD(), RESET() });
    puts("    --json        Machine-readable JSON (CI / automation)\n");
    puts("    --badge       Print a shields.io README badge\n");
    puts("    --min <N>     Exit non-zero if score < N (CI gate)\n");
    puts("    --print       HTML score card to stdout\n");
    puts("    --ascii       ASCII score card to stdout\n");
    puts("    --svg         SVG trading card to stdout (embeddable)\n");
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

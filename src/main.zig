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

const VERSION = "1.4.1";

// Global flags
var no_color: bool = false;
var json_output: bool = false;
var badge_output: bool = false;
var min_threshold: ?u32 = null;
var print_html: bool = false;
var ascii_output: bool = false;
var svg_output: bool = false;
var flip_output: bool = false; // mystack --flip → interactive HTML flip-card

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
    \\bun-sticky v1.4.1 [ZIG]
    \\Fastest bun under the sum.
    \\
    \\────────────────────────────────────────────────
    \\
;

// ── WJTTC test hook ──────────────────────────────────────────────
// When set (tests only), print/puts append into a fixed buffer instead
// of writing to STDOUT, so card/JSON renderers become capturable and
// assertable. Allocation-free; null in production (zero overhead path).
const CardCapture = struct {
    buf: [65536]u8 = undefined,
    len: usize = 0,
    truncated: bool = false,
    fn write(self: *CardCapture, s: []const u8) void {
        const space = self.buf.len - self.len;
        const n = @min(space, s.len);
        if (n < s.len) self.truncated = true;
        @memcpy(self.buf[self.len .. self.len + n], s[0..n]);
        self.len += n;
    }
    fn slice(self: *const CardCapture) []const u8 {
        return self.buf[0..self.len];
    }
};
var card_sink: ?*CardCapture = null;

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    if (card_sink) |sink| {
        sink.write(msg);
        return;
    }
    _ = posix.write(posix.STDOUT_FILENO, msg) catch {};
}

fn puts(s: []const u8) void {
    if (card_sink) |sink| {
        sink.write(s);
        return;
    }
    _ = posix.write(posix.STDOUT_FILENO, s) catch {};
}

pub fn main() !void {
    var args = std.process.args();

    // Skip program name
    _ = args.skip();

    var cmd: []const u8 = "help";
    var init_name: ?[]const u8 = null;
    var soul_path: ?[]const u8 = null;
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
        } else if (std.mem.eql(u8, arg, "--flip")) {
            flip_output = true;
            no_color = true;
        } else if (std.mem.eql(u8, arg, "--min")) {
            want_min = true; // next arg is the threshold
        } else if (cmd[0] == 'h' and cmd.len == 4) {
            // First non-flag arg is the command
            cmd = arg;
        } else if (std.mem.eql(u8, cmd, "init") and init_name == null) {
            init_name = arg;
        } else if (std.mem.eql(u8, cmd, "mystack") and soul_path == null) {
            soul_path = arg;
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
    } else if (std.mem.eql(u8, cmd, "mystack")) {
        try cmdMyStack(soul_path orelse "soul.faf");
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
// ── Card visual decision logic (pure → unit-tested in WJTTC) ──────
// Dark-moody tier color (border + score). Pops on charcoal.
fn tierColor(score: u8) []const u8 {
    return if (score >= 100) "#FFCB45" // gold (Trophy)
    else if (score >= 85) "#3FB950" // green
    else if (score >= 55) "#D29922" // amber
    else "#F85149"; // red
}

// Tier glyph: 🏆 is the ONLY emoji (Trophy); sub-Trophy = clean geometric symbols.
fn tierGlyph(score: u8) []const u8 {
    return if (score >= 100) "\xf0\x9f\x8f\x86" // 🏆
    else if (score >= 99) "\xe2\x98\x85" // ★
    else if (score >= 95) "\xe2\x97\x86" // ◆
    else if (score >= 85) "\xe2\x97\x87" // ◇
    else if (score >= 55) "\xe2\x97\x8f" // ●
    else "\xe2\x97\x8b"; // ○
}

// Section bar fill color by percentage.
fn barColor(pct: u8) []const u8 {
    return if (pct >= 85) "#3FB950" else if (pct >= 55) "#D29922" else "#F85149";
}

fn printSvgCard(content: []const u8, result: scorer.ScoreResult, tier_name: []const u8, name: []const u8, lang: []const u8) void {
    var sec_count: u8 = 0;
    for (sectionRows(result)) |s| {
        if (s.r.total > 0) sec_count += 1;
    }
    const W: u16 = 340;
    const bars_top: u16 = 190;
    const H: u16 = bars_top + @as(u16, sec_count) * 24 + 44;
    const tcolor = tierColor(result.score);
    const tsym = tierGlyph(result.score);

    print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d}\" height=\"{d}\" viewBox=\"0 0 {d} {d}\" font-family=\"-apple-system,Segoe UI,Helvetica,Arial,sans-serif\">\n", .{ W, H, W, H });
    puts("<defs><linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#161b22\"/><stop offset=\"1\" stop-color=\"#0b0e14\"/></linearGradient>");
    puts("<filter id=\"glow\" x=\"-40%\" y=\"-40%\" width=\"180%\" height=\"180%\"><feGaussianBlur stdDeviation=\"5\" result=\"b\"/><feMerge><feMergeNode in=\"b\"/><feMergeNode in=\"SourceGraphic\"/></feMerge></filter></defs>\n");
    print("<rect x=\"1.5\" y=\"1.5\" width=\"{d}\" height=\"{d}\" rx=\"16\" fill=\"url(#bg)\" stroke=\"{s}\" stroke-width=\"3\"/>\n", .{ W - 3, H - 3, tcolor });
    puts("<text x=\"22\" y=\"46\" font-size=\"22\" font-weight=\"700\" fill=\"#f0f6fc\">");
    htmlEsc(name);
    puts("</text>\n<text x=\"22\" y=\"68\" font-size=\"13\" fill=\"#8b949e\">");
    htmlEsc(@tagName(result.project_type));
    puts(" \xc2\xb7 ");
    htmlEsc(lang);
    puts("</text>\n");
    // Tier glyph, top-right, scaled as a design mark
    print("<text x=\"{d}\" y=\"56\" text-anchor=\"end\" font-size=\"30\" fill=\"{s}\">{s}</text>\n", .{ W - 22, tcolor, tsym });
    puts("<text x=\"22\" y=\"104\" font-size=\"11\" letter-spacing=\"1.5\" fill=\"#8b949e\">FAF SCORE</text>\n");
    print("<text x=\"22\" y=\"150\" font-size=\"44\" font-weight=\"800\" fill=\"{s}\" filter=\"url(#glow)\">{d}%</text>\n", .{ tcolor, result.score });
    // Tier name right-aligned — collision-proof regardless of score width
    print("<text x=\"{d}\" y=\"150\" text-anchor=\"end\" font-size=\"20\" font-weight=\"700\" fill=\"#f0f6fc\">{s}</text>\n", .{ W - 22, tier_name });
    print("<text x=\"22\" y=\"170\" font-size=\"12\" fill=\"#8b949e\">{d} / {d} slots</text>\n", .{ result.filled, result.total });

    var y: u16 = bars_top;
    for (sectionRows(result)) |s| {
        if (s.r.total == 0) continue;
        const bc = barColor(s.r.percentage);
        const fw: u16 = @intCast((@as(u32, s.r.percentage) * 150) / 100);
        print("<text x=\"22\" y=\"{d}\" font-size=\"11\" fill=\"#8b949e\">{s}</text>\n", .{ y + 9, s.label });
        print("<rect x=\"100\" y=\"{d}\" width=\"150\" height=\"8\" rx=\"4\" fill=\"#21262d\"/>\n", .{y + 2});
        print("<rect x=\"100\" y=\"{d}\" width=\"{d}\" height=\"8\" rx=\"4\" fill=\"{s}\"/>\n", .{ y + 2, fw, bc });
        print("<text x=\"262\" y=\"{d}\" font-size=\"11\" fill=\"#c9d1d9\">{d}%</text>\n", .{ y + 9, s.r.percentage });
        y += 24;
    }
    print("<text x=\"22\" y=\"{d}\" font-size=\"11\" fill=\"#8b949e\">Missing: <tspan fill=\"#c9d1d9\">", .{y + 14});
    if (!printMissingNames(content, result)) puts("none");
    puts("</tspan></text>\n</svg>\n");
}

// ── MyStack: the `soul` app-type (a dev's DNA → a flip-card) ──────
// Phase 0+1 first cut: hand-authored soul .faf → static SVG, front+back
// stacked. Front = profile (the soul); back = "MY STACK" (tech DNA).
const SOUL_SLOTS = [_][]const u8{
    "handle:",     "name:",      "role:",       "tagline:",
    "who:",        "what:",      "why:",        "where:",
    "languages:",  "runtimes:",  "frameworks:", "tools:",
};

const SoulScore = struct { filled: u8, total: u8, pct: u8 };

// Real, honest completeness: filled soul slots / total. Feeds the card's
// tier color + the Top-Trumps stat line (no fabricated number).
fn soulScore(content: []const u8) SoulScore {
    var filled: u8 = 0;
    for (SOUL_SLOTS) |k| {
        const v = extractValue(content, k);
        if (v.len > 0 and !std.mem.eql(u8, v, "\xe2\x80\x94")) filled += 1; // not empty, not "—"
    }
    const total: u8 = SOUL_SLOTS.len;
    const pct: u8 = @intCast((@as(u16, filled) * 100) / total);
    return .{ .filled = filled, .total = total, .pct = pct };
}

// Count comma-separated items in a stack line (e.g. "Rust, Zig, TS" → 3).
fn countCsv(v: []const u8) u8 {
    if (v.len == 0 or std.mem.eql(u8, v, "\xe2\x80\x94")) return 0;
    var n: u8 = 1;
    for (v) |c| if (c == ',') {
        n += 1;
    };
    return n;
}

// A soul slot is empty if extractValue found nothing ("—") or an empty value.
fn isEmpty(v: []const u8) bool {
    return v.len == 0 or std.mem.eql(u8, v, "\xe2\x80\x94");
}

// One SVG value line that becomes a dim italic "add ___" prompt when empty —
// so a first-time card reads as a fillable invite, not a broken full card.
fn svgVal(y: u16, size: u8, val_color: []const u8, val: []const u8, prompt: []const u8) void {
    if (isEmpty(val)) {
        print("<text x=\"32\" y=\"{d}\" font-size=\"{d}\" font-style=\"italic\" fill=\"#586069\">{s}</text>\n", .{ y, size, prompt });
    } else {
        print("<text x=\"32\" y=\"{d}\" font-size=\"{d}\" fill=\"{s}\">", .{ y, size, val_color });
        htmlEsc(val);
        puts("</text>\n");
    }
}

fn cmdMyStack(path: []const u8) !void {
    const file = fs.cwd().openFile(path, .{}) catch {
        print("{s}No soul .faf found at {s}{s}\n", .{ RED(), path, RESET() });
        print("{s}Usage: faf mystack <soul.faf>{s}\n", .{ DIM(), RESET() });
        return;
    };
    defer file.close();
    var buf: [16384]u8 = undefined;
    const n = file.readAll(&buf) catch {
        print("{s}Error reading {s}{s}\n", .{ RED(), path, RESET() });
        return;
    };
    if (flip_output) printMyStackFlip(buf[0..n]) else printMyStackCard(buf[0..n]);
}

// Static MyStack SVG — two dark-moody panels stacked (front profile / back
// stack). The 3D flip is a later web step; static shows both faces.
fn printMyStackCard(content: []const u8) void {
    const handle = extractValue(content, "handle:");
    const name = extractValue(content, "name:");
    const role = extractValue(content, "role:");
    const tagline = extractValue(content, "tagline:");
    const what = extractValue(content, "what:");
    const github = extractValue(content, "github:");
    const site = extractValue(content, "site:");
    const languages = extractValue(content, "languages:");
    const runtimes = extractValue(content, "runtimes:");
    const frameworks = extractValue(content, "frameworks:");
    const tools = extractValue(content, "tools:");

    const ss = soulScore(content);
    const tname = tier.getTierName(ss.pct);
    const tcolor = tierColor(ss.pct);
    const nlangs = countCsv(languages);

    const W: u16 = 360;
    const H: u16 = 388;

    print("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"{d}\" height=\"{d}\" viewBox=\"0 0 {d} {d}\" font-family=\"-apple-system,Segoe UI,Helvetica,Arial,sans-serif\">\n", .{ W, H, W, H });
    puts("<defs><linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"#161b22\"/><stop offset=\"1\" stop-color=\"#0b0e14\"/></linearGradient></defs>\n");

    // ── FRONT: the soul / profile ──
    print("<rect x=\"12\" y=\"12\" width=\"336\" height=\"166\" rx=\"16\" fill=\"url(#bg)\" stroke=\"{s}\" stroke-width=\"3\"/>\n", .{tcolor});
    print("<text x=\"32\" y=\"52\" font-size=\"24\" font-weight=\"800\" fill=\"{s}\">\xe2\x9a\xa1 ", .{tcolor});
    htmlEsc(handle);
    puts("</text>\n");
    puts("<text x=\"32\" y=\"78\" font-size=\"15\" font-weight=\"700\" fill=\"#f0f6fc\">");
    htmlEsc(name);
    puts("</text>\n");
    svgVal(98, 12, "#8b949e", role, "add role");
    // tagline (quoted when present; dim prompt when empty)
    if (isEmpty(tagline)) {
        puts("<text x=\"32\" y=\"126\" font-size=\"13\" font-style=\"italic\" fill=\"#586069\">add tagline</text>\n");
    } else {
        puts("<text x=\"32\" y=\"126\" font-size=\"13\" font-style=\"italic\" fill=\"#c9d1d9\">\xe2\x80\x9c");
        htmlEsc(tagline);
        puts("\xe2\x80\x9d</text>\n");
    }
    // what + links: shown only when present (a sparse card stays clean, not "—")
    if (!isEmpty(what)) {
        puts("<text x=\"32\" y=\"150\" font-size=\"11\" fill=\"#8b949e\">");
        htmlEsc(what);
        puts("</text>\n");
    }
    if (!isEmpty(github) or !isEmpty(site)) {
        puts("<text x=\"32\" y=\"168\" font-size=\"11\" fill=\"#6e7681\">");
        if (!isEmpty(github)) htmlEsc(github);
        if (!isEmpty(github) and !isEmpty(site)) puts(" \xc2\xb7 ");
        if (!isEmpty(site)) htmlEsc(site);
        puts("</text>\n");
    }

    // ── BACK: MY STACK (tech DNA) ──
    print("<rect x=\"12\" y=\"192\" width=\"336\" height=\"184\" rx=\"16\" fill=\"url(#bg)\" stroke=\"{s}\" stroke-width=\"3\"/>\n", .{tcolor});
    puts("<text x=\"32\" y=\"222\" font-size=\"13\" letter-spacing=\"2\" fill=\"#8b949e\">MY STACK</text>\n");
    const Row = struct { l: []const u8, v: []const u8, p: []const u8 };
    const rows = [_]Row{
        .{ .l = "LANGUAGES", .v = languages, .p = "add languages" },
        .{ .l = "RUNTIMES", .v = runtimes, .p = "add runtimes" },
        .{ .l = "FRAMEWORKS", .v = frameworks, .p = "add frameworks" },
        .{ .l = "TOOLS", .v = tools, .p = "add tools" },
    };
    var y: u16 = 244;
    for (rows) |r| {
        print("<text x=\"32\" y=\"{d}\" font-size=\"9\" letter-spacing=\"1\" fill=\"#6e7681\">{s}</text>\n", .{ y, r.l });
        svgVal(y + 15, 12, "#f0f6fc", r.v, r.p);
        y += 28;
    }
    // Top-Trumps stat line — real numbers; sub-Trophy cards get a "level up" nudge.
    if (ss.pct >= 100) {
        print("<text x=\"32\" y=\"366\" font-size=\"11\" font-weight=\"700\" fill=\"{s}\">{d}/{d} slots \xc2\xb7 {s} \xc2\xb7 {d} langs</text>\n", .{ tcolor, ss.filled, ss.total, tname, nlangs });
    } else {
        print("<text x=\"32\" y=\"366\" font-size=\"11\" font-weight=\"700\" fill=\"{s}\">{d}/{d} slots \xc2\xb7 {s} \xc2\xb7 {d} langs \xe2\x96\xb8 level up</text>\n", .{ tcolor, ss.filled, ss.total, tname, nlangs });
    }
    puts("</svg>\n");
}

// --flip: interactive HTML flip-card (Phase 3). Self-contained: equal faces,
// click-anywhere 3D flip, persistent ↻ icon, first-time hint (localStorage
// "don't show again"), and a "View all info" mode (both faces stacked).
fn printMyStackFlip(content: []const u8) void {
    const handle = extractValue(content, "handle:");
    const name = extractValue(content, "name:");
    const role = extractValue(content, "role:");
    const tagline = extractValue(content, "tagline:");
    const what = extractValue(content, "what:");
    const github = extractValue(content, "github:");
    const site = extractValue(content, "site:");
    const languages = extractValue(content, "languages:");
    const runtimes = extractValue(content, "runtimes:");
    const frameworks = extractValue(content, "frameworks:");
    const tools = extractValue(content, "tools:");
    const ss = soulScore(content);
    const tname = tier.getTierName(ss.pct);
    const nlangs = countCsv(languages);

    // Static head + CSS + hint + stage open (Zig multiline = no quote escaping).
    puts(
        \\<!doctype html>
        \\<html lang="en"><head><meta charset="utf-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<title>MyStack</title>
        \\<style>
        \\  :root{--gold:#FFCB45;--fg:#f0f6fc;--muted:#8b949e;--soft:#c9d1d9;--dim:#6e7681}
        \\  *{box-sizing:border-box}
        \\  body{margin:0;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;background:#07090d;color:var(--fg);font-family:-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
        \\  .stage{perspective:1400px}
        \\  .card{position:relative;width:336px;height:208px;cursor:pointer;transform-style:preserve-3d;transition:transform .6s cubic-bezier(.2,.7,.2,1)}
        \\  .card.flipped{transform:rotateY(180deg)}
        \\  .face{position:absolute;inset:0;backface-visibility:hidden;border-radius:16px;border:3px solid var(--gold);background:linear-gradient(#161b22,#0b0e14);padding:20px 24px;overflow:hidden}
        \\  .face.back{transform:rotateY(180deg)}
        \\  .flipicon{position:absolute;top:12px;right:14px;font-size:15px;color:var(--gold);opacity:.55;user-select:none}
        \\  .handle{font-size:24px;font-weight:800;color:var(--gold);margin:2px 0 6px}
        \\  .name{font-size:15px;font-weight:700} .role{font-size:12px;color:var(--muted);margin-top:2px}
        \\  .tagline{font-size:13px;font-style:italic;color:var(--soft);margin-top:12px}
        \\  .what{font-size:11px;color:var(--muted);margin-top:10px} .links{font-size:11px;color:var(--dim);margin-top:6px}
        \\  .stacktitle{font-size:13px;letter-spacing:2px;color:var(--muted);margin-bottom:6px}
        \\  .row{margin-top:8px} .row .lbl{font-size:9px;letter-spacing:1px;color:var(--dim)} .row .val{font-size:12px;color:var(--fg)}
        \\  .prompt{color:#586069;font-style:italic}
        \\  .stat{margin-top:12px;font-size:11px;font-weight:700;color:var(--gold)}
        \\  .hint{display:flex;align-items:center;gap:8px;background:#11161f;border:1px solid #232a36;border-radius:999px;padding:6px 12px;font-size:12px;color:var(--soft)}
        \\  .hint b{color:var(--gold);font-weight:700} .hint .x{cursor:pointer;color:var(--dim);font-weight:700;padding:0 2px} .hint .x:hover{color:var(--fg)} .hint.gone{display:none}
        \\  .viewall{background:none;border:none;color:var(--muted);font-size:12px;cursor:pointer;text-decoration:underline;font-family:inherit} .viewall:hover{color:var(--fg)}
        \\  .stacked{display:none;flex-direction:column;gap:14px}
        \\  body.both .stage{display:none} body.both .stacked{display:flex}
        \\  .stacked .face{position:relative;inset:auto;backface-visibility:visible;transform:none;width:336px;height:208px}
        \\</style></head><body>
        \\  <div class="hint" id="hint"><span><b>Tap the card to flip</b> — front is you, back is your stack</span><span class="x" id="hintx" title="don't show again">✕</span></div>
        \\  <div class="stage"><div class="card" id="card">
        \\
    );

    // FRONT face (dynamic)
    puts("  <div class=\"face front\"><span class=\"flipicon\">\xe2\x86\xbb</span>\n    <div class=\"handle\">\xe2\x9a\xa1 ");
    htmlEsc(handle);
    puts("</div>\n    <div class=\"name\">");
    htmlEsc(name);
    puts("</div>\n");
    if (isEmpty(role)) {
        puts("    <div class=\"role prompt\">add role</div>\n");
    } else {
        puts("    <div class=\"role\">");
        htmlEsc(role);
        puts("</div>\n");
    }
    if (isEmpty(tagline)) {
        puts("    <div class=\"tagline prompt\">add tagline</div>\n");
    } else {
        puts("    <div class=\"tagline\">\xe2\x80\x9c");
        htmlEsc(tagline);
        puts("\xe2\x80\x9d</div>\n");
    }
    if (!isEmpty(what)) {
        puts("    <div class=\"what\">");
        htmlEsc(what);
        puts("</div>\n");
    }
    if (!isEmpty(github) or !isEmpty(site)) {
        puts("    <div class=\"links\">");
        if (!isEmpty(github)) htmlEsc(github);
        if (!isEmpty(github) and !isEmpty(site)) puts(" \xc2\xb7 ");
        if (!isEmpty(site)) htmlEsc(site);
        puts("</div>\n");
    }
    puts("  </div>\n");

    // BACK face (dynamic)
    puts("  <div class=\"face back\"><span class=\"flipicon\">\xe2\x86\xbb</span>\n    <div class=\"stacktitle\">MY STACK</div>\n");
    const Row = struct { l: []const u8, v: []const u8, p: []const u8 };
    const rows = [_]Row{
        .{ .l = "LANGUAGES", .v = languages, .p = "add languages" },
        .{ .l = "RUNTIMES", .v = runtimes, .p = "add runtimes" },
        .{ .l = "FRAMEWORKS", .v = frameworks, .p = "add frameworks" },
        .{ .l = "TOOLS", .v = tools, .p = "add tools" },
    };
    for (rows) |r| {
        puts("    <div class=\"row\"><div class=\"lbl\">");
        puts(r.l);
        if (isEmpty(r.v)) {
            puts("</div><div class=\"val prompt\">");
            puts(r.p);
        } else {
            puts("</div><div class=\"val\">");
            htmlEsc(r.v);
        }
        puts("</div></div>\n");
    }
    if (ss.pct >= 100) {
        print("    <div class=\"stat\">{d}/{d} slots \xc2\xb7 {s} \xc2\xb7 {d} langs</div>\n", .{ ss.filled, ss.total, tname, nlangs });
    } else {
        print("    <div class=\"stat\">{d}/{d} slots \xc2\xb7 {s} \xc2\xb7 {d} langs \xe2\x96\xb8 level up</div>\n", .{ ss.filled, ss.total, tname, nlangs });
    }
    puts("  </div>\n");

    // Static tail: close card+stage, stacked container, view-all button, script.
    puts(
        \\  </div></div>
        \\  <div class="stacked" id="stacked"></div>
        \\  <button class="viewall" id="viewall">View all info ▾</button>
        \\<script>
        \\  var card=document.getElementById('card'),hint=document.getElementById('hint');
        \\  if(localStorage.getItem('mystack-hint')==='off')hint.classList.add('gone');
        \\  function dh(){hint.classList.add('gone');localStorage.setItem('mystack-hint','off');}
        \\  document.getElementById('hintx').addEventListener('click',function(e){e.stopPropagation();dh();});
        \\  card.addEventListener('click',function(){card.classList.toggle('flipped');dh();});
        \\  var s=document.getElementById('stacked');s.innerHTML=card.innerHTML;
        \\  var b=document.getElementById('viewall');
        \\  b.addEventListener('click',function(){document.body.classList.toggle('both');b.textContent=document.body.classList.contains('both')?'Flip card ▴':'View all info ▾';});
        \\</script></body></html>
        \\
    );
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

// ══════════════════════════════════════════════════════════════════
// 🏁 WJTTC — Wolfe-Jam Test & Tuning Certification
// Championship-grade coverage for the render/CLI layer.
//   🏎️ ENGINE — core decision logic (colors, glyphs, JSON)
//   🎨 LIVERY  — card output is well-formed + carries every design element
//   🛑 BRAKE   — safety: escaping, never emit malformed markup
//   🌬️ AERO    — fuzz / stress / determinism (the bug-finders)
// ══════════════════════════════════════════════════════════════════

const CLI_100 =
    \\project:
    \\  name: TestCLI
    \\  goal: Test the system
    \\  main_language: Zig
    \\  type: cli
    \\human_context:
    \\  who: Developers
    \\  what: A CLI tool
    \\  why: Testing
    \\  where: Terminal
    \\  when: Now
    \\  how: zig build run
;

// ── 🏎️ ENGINE ─────────────────────────────────────────────────────

test "WJTTC ENGINE - tierColor boundaries" {
    try std.testing.expectEqualStrings("#FFCB45", tierColor(100)); // gold
    try std.testing.expectEqualStrings("#3FB950", tierColor(99)); // green
    try std.testing.expectEqualStrings("#3FB950", tierColor(85));
    try std.testing.expectEqualStrings("#D29922", tierColor(84)); // amber
    try std.testing.expectEqualStrings("#D29922", tierColor(55));
    try std.testing.expectEqualStrings("#F85149", tierColor(54)); // red
    try std.testing.expectEqualStrings("#F85149", tierColor(0));
}

test "WJTTC ENGINE - tierGlyph follows the ladder, 🏆 only at 100" {
    try std.testing.expectEqualStrings("\xf0\x9f\x8f\x86", tierGlyph(100)); // 🏆
    try std.testing.expectEqualStrings("\xe2\x98\x85", tierGlyph(99)); // ★
    try std.testing.expectEqualStrings("\xe2\x97\x86", tierGlyph(95)); // ◆
    try std.testing.expectEqualStrings("\xe2\x97\x87", tierGlyph(85)); // ◇
    try std.testing.expectEqualStrings("\xe2\x97\x8f", tierGlyph(70)); // ●
    try std.testing.expectEqualStrings("\xe2\x97\x8f", tierGlyph(55)); // ●
    try std.testing.expectEqualStrings("\xe2\x97\x8b", tierGlyph(54)); // ○
    // The one emoji must never leak below a perfect score.
    try std.testing.expect(std.mem.indexOf(u8, tierGlyph(99), "\xf0\x9f\x8f\x86") == null);
}

test "WJTTC ENGINE - barColor boundaries" {
    try std.testing.expectEqualStrings("#3FB950", barColor(100));
    try std.testing.expectEqualStrings("#3FB950", barColor(85));
    try std.testing.expectEqualStrings("#D29922", barColor(84));
    try std.testing.expectEqualStrings("#D29922", barColor(55));
    try std.testing.expectEqualStrings("#F85149", barColor(54));
}

test "WJTTC ENGINE - sectionRows always returns the 5 canonical sections in order" {
    const rows = sectionRows(scorer.calculateScore(CLI_100));
    try std.testing.expectEqual(@as(usize, 5), rows.len);
    try std.testing.expectEqualStrings("Project", rows[0].label);
    try std.testing.expectEqualStrings("Frontend", rows[1].label);
    try std.testing.expectEqualStrings("Backend", rows[2].label);
    try std.testing.expectEqualStrings("Universal", rows[3].label);
    try std.testing.expectEqualStrings("Human", rows[4].label);
}

// ── 🎨 LIVERY ──────────────────────────────────────────────────────

test "WJTTC LIVERY - svg card is well-formed and carries every design element" {
    var cap = CardCapture{};
    const result = scorer.calculateScore(CLI_100);
    card_sink = &cap;
    printSvgCard(CLI_100, result, tier.getTierName(result.score), "demo", "Zig");
    card_sink = null;

    const out = cap.slice();
    const body = std.mem.trimRight(u8, out, "\n");
    try std.testing.expect(!cap.truncated);
    try std.testing.expect(std.mem.startsWith(u8, out, "<svg"));
    try std.testing.expect(std.mem.endsWith(u8, body, "</svg>"));
    try std.testing.expect(std.mem.indexOf(u8, out, "\xf0\x9f\x8f\x86") != null); // 🏆 glyph
    try std.testing.expect(std.mem.indexOf(u8, out, "url(#bg)") != null); // dark gradient
    try std.testing.expect(std.mem.indexOf(u8, out, "filter=\"url(#glow)\"") != null); // glow
    try std.testing.expect(std.mem.indexOf(u8, out, "100%") != null); // score
    try std.testing.expect(std.mem.indexOf(u8, out, "Trophy") != null); // tier name
    try std.testing.expect(std.mem.indexOf(u8, out, "demo") != null); // project name
}

test "WJTTC LIVERY - tier label is right-aligned (collision-proof, the v1.3.1 fix)" {
    // The bug: tier name was pinned at x=128 and the wide "100%" overran it.
    // The fix: right-anchored text. Lock it so the collision can't return.
    var cap = CardCapture{};
    const result = scorer.calculateScore(CLI_100);
    card_sink = &cap;
    printSvgCard(CLI_100, result, "Trophy", "demo", "Zig");
    card_sink = null;
    const out = cap.slice();
    try std.testing.expect(std.mem.indexOf(u8, out, "text-anchor=\"end\"") != null);
    // The old hard-coded collision coordinate must be gone.
    try std.testing.expect(std.mem.indexOf(u8, out, "x=\"128\" y=\"140\"") == null);
}

test "WJTTC LIVERY - html and ascii cards render non-empty and name-bearing" {
    const result = scorer.calculateScore(CLI_100);

    var h = CardCapture{};
    card_sink = &h;
    printHtmlCard(CLI_100, result, "Trophy", "demo", "Zig");
    card_sink = null;
    try std.testing.expect(!h.truncated);
    try std.testing.expect(h.slice().len > 0);
    try std.testing.expect(std.mem.indexOf(u8, h.slice(), "demo") != null);

    var a = CardCapture{};
    card_sink = &a;
    printAsciiCard(CLI_100, result, "Trophy", "demo", "Zig");
    card_sink = null;
    try std.testing.expect(!a.truncated);
    try std.testing.expect(a.slice().len > 0);
}

test "WJTTC LIVERY - grab emits JSON object with score and tier" {
    // cmdGrab reads ./project.faf from cwd (the repo root during tests).
    var cap = CardCapture{};
    card_sink = &cap;
    cmdGrab() catch {};
    card_sink = null;
    const out = cap.slice();
    try std.testing.expect(!cap.truncated);
    try std.testing.expect(std.mem.startsWith(u8, out, "{"));
    try std.testing.expect(std.mem.indexOf(u8, out, "\"_score\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"_tier\":") != null);
}

// ── 🛑 BRAKE ───────────────────────────────────────────────────────

test "WJTTC BRAKE - htmlEsc neutralizes markup-breaking characters" {
    var cap = CardCapture{};
    card_sink = &cap;
    htmlEsc("<script>\"&\">");
    card_sink = null;
    const out = cap.slice();
    try std.testing.expect(std.mem.indexOf(u8, out, "&lt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "&gt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "&amp;") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "&quot;") != null);
    // No raw opening tag may survive.
    try std.testing.expect(std.mem.indexOf(u8, out, "<script") == null);
}

test "WJTTC BRAKE - hostile project name cannot break the svg document" {
    const result = scorer.calculateScore(CLI_100);
    var cap = CardCapture{};
    card_sink = &cap;
    printSvgCard(CLI_100, result, "Trophy", "</text><script>alert(1)</script>", "Zig");
    card_sink = null;
    const out = cap.slice();
    // The injected raw tags must have been escaped, not emitted verbatim.
    try std.testing.expect(std.mem.indexOf(u8, out, "<script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "&lt;script&gt;") != null);
    const body = std.mem.trimRight(u8, out, "\n");
    try std.testing.expect(std.mem.endsWith(u8, body, "</svg>"));
}

// ── 🌬️ AERO ────────────────────────────────────────────────────────

test "WJTTC AERO - fuzz: random bytes never crash the scorer, score stays bounded" {
    var prng = std.Random.DefaultPrng.init(0xF1F1F1F1);
    const rand = prng.random();
    var buf: [512]u8 = undefined;
    var i: usize = 0;
    while (i < 8000) : (i += 1) {
        const len = rand.intRangeAtMost(usize, 0, buf.len);
        rand.bytes(buf[0..len]);
        const result = scorer.calculateScore(buf[0..len]);
        try std.testing.expect(result.score <= 100);
        try std.testing.expect(result.filled <= result.total);
        _ = scorer.detectProjectType(buf[0..len]);
    }
}

test "WJTTC AERO - fuzz: card renderer survives garbage content, output stays bounded" {
    var prng = std.Random.DefaultPrng.init(0x68686868);
    const rand = prng.random();
    var buf: [256]u8 = undefined;
    var i: usize = 0;
    while (i < 3000) : (i += 1) {
        const len = rand.intRangeAtMost(usize, 0, buf.len);
        rand.bytes(buf[0..len]);
        const result = scorer.calculateScore(buf[0..len]);
        var cap = CardCapture{};
        card_sink = &cap;
        printSvgCard(buf[0..len], result, tier.getTierName(result.score), "fuzz", "x");
        card_sink = null;
        try std.testing.expect(!cap.truncated); // never blows the 64KB buffer
        try std.testing.expect(std.mem.startsWith(u8, cap.slice(), "<svg"));
    }
}

test "WJTTC AERO - fuzz: hostile names of any byte pattern keep the svg well-formed" {
    const result = scorer.calculateScore(CLI_100);
    var prng = std.Random.DefaultPrng.init(0xBADBEEF);
    const rand = prng.random();
    var nbuf: [64]u8 = undefined;
    var i: usize = 0;
    while (i < 3000) : (i += 1) {
        const len = rand.intRangeAtMost(usize, 0, nbuf.len);
        rand.bytes(nbuf[0..len]);
        var cap = CardCapture{};
        card_sink = &cap;
        printSvgCard(CLI_100, result, "Trophy", nbuf[0..len], "Zig");
        card_sink = null;
        const out = cap.slice();
        try std.testing.expect(!cap.truncated);
        try std.testing.expect(std.mem.startsWith(u8, out, "<svg"));
        const body = std.mem.trimRight(u8, out, "\n");
        try std.testing.expect(std.mem.endsWith(u8, body, "</svg>"));
    }
}

// ── 🪪 MyStack (soul app-type) ─────────────────────────────────────

const SOUL_FAF =
    \\app_type: soul
    \\soul:
    \\  handle: wolfejam
    \\  name: James Wolfe Harrison
    \\  role: Architect
    \\  tagline: FAF defines.
    \\human_context:
    \\  who: Solo architect
    \\  what: Project & Dev DNA for AI
    \\  why: Eliminate setup tax
    \\  where: faf.one
    \\stack:
    \\  languages: Rust, Zig, TypeScript, Python
    \\  runtimes: Bun, Cloudflare Workers
    \\  frameworks: SvelteKit, Hono
    \\  tools: WASM, MCP
    \\links:
    \\  github: Wolfe-Jam
    \\  site: faf.one
;

test "WJTTC ENGINE - soulScore counts filled soul slots + countCsv" {
    const s = soulScore(SOUL_FAF);
    try std.testing.expectEqual(@as(u8, 12), s.total);
    try std.testing.expectEqual(@as(u8, 12), s.filled); // all 12 present
    try std.testing.expectEqual(@as(u8, 100), s.pct);
    try std.testing.expectEqual(@as(u8, 4), countCsv("Rust, Zig, TypeScript, Python"));
    try std.testing.expectEqual(@as(u8, 1), countCsv("Rust"));
    try std.testing.expectEqual(@as(u8, 0), countCsv("\xe2\x80\x94")); // "—" = none
}

test "WJTTC LIVERY - mystack card has both faces, the stack, and a stat line" {
    var cap = CardCapture{};
    card_sink = &cap;
    printMyStackCard(SOUL_FAF);
    card_sink = null;
    const out = cap.slice();
    const body = std.mem.trimRight(u8, out, "\n");
    try std.testing.expect(!cap.truncated);
    try std.testing.expect(std.mem.startsWith(u8, out, "<svg"));
    try std.testing.expect(std.mem.endsWith(u8, body, "</svg>"));
    try std.testing.expect(std.mem.indexOf(u8, out, "wolfejam") != null); // handle (front)
    try std.testing.expect(std.mem.indexOf(u8, out, "MY STACK") != null); // back face
    try std.testing.expect(std.mem.indexOf(u8, out, "Rust, Zig") != null); // stack DNA
    try std.testing.expect(std.mem.indexOf(u8, out, "langs") != null); // Top-Trumps stat
    // Two stacked panels = two rounded borders.
    var rects: usize = 0;
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, out, i, "rx=\"16\"")) |p| {
        rects += 1;
        i = p + 1;
    }
    try std.testing.expect(rects >= 2);
}

test "WJTTC LIVERY - mystack --flip emits self-contained HTML with both faces + flip JS" {
    var cap = CardCapture{};
    card_sink = &cap;
    printMyStackFlip(SOUL_FAF);
    card_sink = null;
    const out = cap.slice();
    try std.testing.expect(!cap.truncated);
    try std.testing.expect(std.mem.indexOf(u8, out, "<!doctype html>") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "class=\"face front\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "class=\"face back\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "wolfejam") != null); // injected handle
    try std.testing.expect(std.mem.indexOf(u8, out, "Rust, Zig") != null); // injected stack
    try std.testing.expect(std.mem.indexOf(u8, out, "classList.toggle('flipped')") != null); // flip wired
    try std.testing.expect(std.mem.indexOf(u8, out, "mystack-hint") != null); // dismissible hint
    try std.testing.expect(std.mem.endsWith(u8, std.mem.trimRight(u8, out, "\n"), "</html>"));
}

test "WJTTC LIVERY - sparse soul card coaches with 'add ___' prompts, no — holes, level-up nudge" {
    const sparse =
        \\app_type: soul
        \\soul:
        \\  handle: newdev
        \\  name: Jordan
    ;
    // static SVG
    var cap = CardCapture{};
    card_sink = &cap;
    printMyStackCard(sparse);
    card_sink = null;
    const svg = cap.slice();
    try std.testing.expect(std.mem.indexOf(u8, svg, "add languages") != null); // empty stack → prompt
    try std.testing.expect(std.mem.indexOf(u8, svg, "add role") != null); // empty front → prompt
    try std.testing.expect(std.mem.indexOf(u8, svg, "level up") != null); // sub-Trophy nudge
    try std.testing.expect(std.mem.indexOf(u8, svg, ">\xe2\x80\x94<") == null); // NO bare "—" holes
    // flip HTML coaches too (prompt class)
    var c2 = CardCapture{};
    card_sink = &c2;
    printMyStackFlip(sparse);
    card_sink = null;
    try std.testing.expect(std.mem.indexOf(u8, c2.slice(), "val prompt\">add languages") != null);
}

test "WJTTC BRAKE - mystack escapes a hostile handle, stays well-formed" {
    const hostile =
        \\soul:
        \\  handle: </text><script>x</script>
        \\  name: x
        \\stack:
        \\  languages: Rust
    ;
    var cap = CardCapture{};
    card_sink = &cap;
    printMyStackCard(hostile);
    card_sink = null;
    const out = cap.slice();
    try std.testing.expect(std.mem.indexOf(u8, out, "<script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "&lt;script&gt;") != null);
    try std.testing.expect(std.mem.endsWith(u8, std.mem.trimRight(u8, out, "\n"), "</svg>"));
}

test "WJTTC AERO - deterministic: identical input yields byte-identical card" {
    const result = scorer.calculateScore(CLI_100);
    var a = CardCapture{};
    var b = CardCapture{};
    card_sink = &a;
    printSvgCard(CLI_100, result, "Trophy", "Det", "Zig");
    card_sink = &b;
    printSvgCard(CLI_100, result, "Trophy", "Det", "Zig");
    card_sink = null;
    try std.testing.expectEqualSlices(u8, a.slice(), b.slice());
}

///! Wolfejam Slot-Based Scoring System
///! Score = (Filled Slots / Applicable Slots) x 100
///!
///! This is a Zig-native APPROXIMATION of the live faf-cli scoring kernel,
///! not the authoritative implementation. faf-cli's real scorer delegates to
///! a private compiled kernel (see faf-cli/src/core/scorer.ts — `kernel.score()`,
///! WASM); there is no public spec file to diff this against, only faf-cli's
///! own observed output. Run `faf-cli score` for the authoritative number.
///!
///! Slot list mirrors faf-cli's public/OSS `src/core/slots.ts` (33 canonical
///! Mk4 slots, checked 2026-08-14) — that file ships in faf-cli and is not
///! the private kernel, so mirroring it is not a moat leak. The kernel's
///! exact per-project-type applicability rules ARE private and not visible
///! from outside; the 21-base/12-enterprise split below is a best-effort
///! rule inferred from one verified live data point (faf-cli scored a
///! `type: cli` project.faf as 21 active slots, not 9 — see git history),
///! not a guaranteed match to every project type.
///!
///! NOT Elon weights. Wolfejam slots.

const std = @import("std");

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLOT DEFINITIONS — 33 Mk4 canonical slots
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 21 "base" slots (project + human + frontend + backend + universal) are
// applicable to every project — this matches the one live faf-cli data
// point we have (a `cli`-type project.faf scored 21 active slots).
// 12 "enterprise" slots are applicable only when the file shows a
// monorepo/enterprise signal (see isEnterpriseApplicable below).

/// Project slots (3)
pub const PROJECT_SLOTS = [_][]const u8{
    "project.name",
    "project.goal",
    "project.main_language",
};

/// Human context slots (6)
pub const HUMAN_SLOTS = [_][]const u8{
    "human_context.who",
    "human_context.what",
    "human_context.why",
    "human_context.where",
    "human_context.when",
    "human_context.how",
};

/// Frontend slots (4)
pub const FRONTEND_SLOTS = [_][]const u8{
    "stack.frontend",
    "stack.css_framework",
    "stack.ui_library",
    "stack.state_management",
};

/// Backend slots (5)
pub const BACKEND_SLOTS = [_][]const u8{
    "stack.backend",
    "stack.api_type",
    "stack.runtime",
    "stack.database",
    "stack.connection",
};

/// Universal slots (3)
pub const UNIVERSAL_SLOTS = [_][]const u8{
    "stack.hosting",
    "stack.build",
    "stack.cicd",
};

/// Enterprise slots (12) — Mk4 addition on top of the original 21.
/// Merges faf-cli's three enterprise_infra/enterprise_app/enterprise_ops
/// categories into one display section; a simplification made for this
/// Zig port, not a faf-cli distinction.
pub const ENTERPRISE_SLOTS = [_][]const u8{
    "stack.monorepo_tool",
    "stack.package_manager",
    "stack.workspaces",
    "monorepo.packages_count",
    "monorepo.build_orchestrator",
    "stack.admin",
    "stack.cache",
    "stack.search",
    "stack.storage",
    "monorepo.versioning_strategy",
    "monorepo.shared_configs",
    "monorepo.remote_cache",
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PROJECT TYPES — informational/display only, no longer gates applicability.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub const ProjectType = enum {
    cli,
    library,
    api,
    webapp,
    fullstack,
    mobile,
    unknown,
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SECTION RESULT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub const SectionResult = struct {
    filled: u8,
    total: u8,
    percentage: u8,
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SCORE RESULT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub const ScoreResult = struct {
    project_type: ProjectType,
    project: SectionResult,
    frontend: SectionResult,
    backend: SectionResult,
    universal: SectionResult,
    human: SectionResult,
    enterprise: SectionResult,
    filled: u8,
    total: u8,
    score: u8,

    pub fn init() ScoreResult {
        return .{
            .project_type = .unknown,
            .project = .{ .filled = 0, .total = 0, .percentage = 0 },
            .frontend = .{ .filled = 0, .total = 0, .percentage = 0 },
            .backend = .{ .filled = 0, .total = 0, .percentage = 0 },
            .universal = .{ .filled = 0, .total = 0, .percentage = 0 },
            .human = .{ .filled = 0, .total = 0, .percentage = 0 },
            .enterprise = .{ .filled = 0, .total = 0, .percentage = 0 },
            .filled = 0,
            .total = 0,
            .score = 0,
        };
    }
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SCORING FUNCTIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Detect project type from content — informational label only.
pub fn detectProjectType(content: []const u8) ProjectType {
    if (std.mem.indexOf(u8, content, "type: cli") != null or
        std.mem.indexOf(u8, content, "type: CLI") != null)
    {
        return .cli;
    }
    if (std.mem.indexOf(u8, content, "type: lib") != null or
        std.mem.indexOf(u8, content, "type: package") != null)
    {
        return .library;
    }
    if (std.mem.indexOf(u8, content, "type: api") != null or
        std.mem.indexOf(u8, content, "type: backend") != null)
    {
        return .api;
    }
    if (std.mem.indexOf(u8, content, "type: web") != null or
        std.mem.indexOf(u8, content, "type: frontend") != null)
    {
        return .webapp;
    }
    if (std.mem.indexOf(u8, content, "type: full") != null) {
        return .fullstack;
    }
    if (std.mem.indexOf(u8, content, "type: mobile") != null or
        std.mem.indexOf(u8, content, "type: app") != null)
    {
        return .mobile;
    }

    const has_frontend = std.mem.indexOf(u8, content, "frontend:") != null;
    const has_backend = std.mem.indexOf(u8, content, "backend:") != null or
        std.mem.indexOf(u8, content, "database:") != null;

    if (has_frontend and has_backend) return .fullstack;
    if (has_frontend) return .webapp;
    if (has_backend) return .api;

    return .unknown;
}

/// Best-effort heuristic: are the 12 enterprise slots applicable?
/// True when the file shows a monorepo/enterprise signal. Approximation —
/// the real kernel's rule is private and may differ.
pub fn isEnterpriseApplicable(content: []const u8) bool {
    return std.mem.indexOf(u8, content, "monorepo:") != null or
        std.mem.indexOf(u8, content, "app_type: enterprise") != null;
}

/// Check if a slot has a value in the content
pub fn hasSlotValue(content: []const u8, slot: []const u8) bool {
    // Extract the field name (after the last dot)
    var field_name: []const u8 = slot;
    if (std.mem.lastIndexOf(u8, slot, ".")) |idx| {
        field_name = slot[idx + 1 ..];
    }

    // Look for "field_name:" followed by non-empty content
    var search_buf: [64]u8 = undefined;
    const search_pattern = std.fmt.bufPrint(&search_buf, "{s}:", .{field_name}) catch return false;

    if (std.mem.indexOf(u8, content, search_pattern)) |idx| {
        // Check if there's content after the colon
        const after_colon = content[idx + search_pattern.len ..];
        // Skip whitespace
        var i: usize = 0;
        while (i < after_colon.len and (after_colon[i] == ' ' or after_colon[i] == '\t')) {
            i += 1;
        }
        // Check if there's actual content (not empty or just newline)
        if (i < after_colon.len and after_colon[i] != '\n' and after_colon[i] != '\r') {
            return true;
        }
    }
    return false;
}

/// Count filled slots in a section
pub fn countSection(content: []const u8, slots: []const []const u8, applies: bool) SectionResult {
    if (!applies) {
        return .{ .filled = 0, .total = 0, .percentage = 0 };
    }

    var filled: u8 = 0;
    for (slots) |slot| {
        if (hasSlotValue(content, slot)) {
            filled += 1;
        }
    }

    const total: u8 = @intCast(slots.len);
    // Use u16 for intermediate calculation to avoid overflow
    const percentage: u8 = if (total > 0) @intCast((@as(u16, filled) * 100) / @as(u16, total)) else 0;

    return .{ .filled = filled, .total = total, .percentage = percentage };
}

/// Calculate FAF score using Wolfejam slot-based system.
/// Base 21 slots (project/human/frontend/backend/universal) always apply;
/// 12 enterprise slots apply only when isEnterpriseApplicable() is true.
pub fn calculateScore(content: []const u8) ScoreResult {
    var result = ScoreResult.init();

    result.project_type = detectProjectType(content);
    const enterprise_applies = isEnterpriseApplicable(content);

    result.project = countSection(content, &PROJECT_SLOTS, true);
    result.frontend = countSection(content, &FRONTEND_SLOTS, true);
    result.backend = countSection(content, &BACKEND_SLOTS, true);
    result.universal = countSection(content, &UNIVERSAL_SLOTS, true);
    result.human = countSection(content, &HUMAN_SLOTS, true);
    result.enterprise = countSection(content, &ENTERPRISE_SLOTS, enterprise_applies);

    result.filled = result.project.filled + result.frontend.filled +
        result.backend.filled + result.universal.filled + result.human.filled +
        result.enterprise.filled;

    result.total = result.project.total + result.frontend.total +
        result.backend.total + result.universal.total + result.human.total +
        result.enterprise.total;

    result.score = if (result.total > 0) @intCast((@as(u16, result.filled) * 100) / @as(u16, result.total)) else 0;

    return result;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS - WJTTC Championship Grade
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "slot counts are correct — 21 base + 12 enterprise = 33 Mk4 canonical" {
    try std.testing.expectEqual(@as(usize, 3), PROJECT_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 4), FRONTEND_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 5), BACKEND_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 3), UNIVERSAL_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 6), HUMAN_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 12), ENTERPRISE_SLOTS.len);
    // 3 + 4 + 5 + 3 + 6 + 12 = 33
}

test "detect CLI project type" {
    const content = "project:\n  name: test\n  type: cli\n";
    const ptype = detectProjectType(content);
    try std.testing.expectEqual(ProjectType.cli, ptype);
}

test "detect fullstack from stack" {
    const content = "stack:\n  frontend: React\n  backend: Node\n";
    const ptype = detectProjectType(content);
    try std.testing.expectEqual(ProjectType.fullstack, ptype);
}

test "has slot value" {
    const content = "project:\n  name: MyProject\n  goal: Do stuff\n";
    try std.testing.expect(hasSlotValue(content, "project.name"));
    try std.testing.expect(hasSlotValue(content, "project.goal"));
    try std.testing.expect(!hasSlotValue(content, "project.main_language"));
}

test "enterprise slots are NOT applicable without a monorepo/enterprise signal" {
    const content = "project:\n  name: SmallCLI\n  type: cli\n";
    try std.testing.expect(!isEnterpriseApplicable(content));
    const result = calculateScore(content);
    try std.testing.expectEqual(@as(u8, 0), result.enterprise.total);
}

test "enterprise slots ARE applicable with a monorepo block" {
    const content = "project:\n  name: BigRepo\nmonorepo:\n  packages_count: 12\n";
    try std.testing.expect(isEnterpriseApplicable(content));
    const result = calculateScore(content);
    try std.testing.expectEqual(@as(u8, 12), result.enterprise.total);
}

test "a CLI-type project is held to the same 21 base slots as everything else" {
    // This is the headline fix: the old model gave CLI-type projects only
    // 9 applicable slots (project+human). The live faf-cli kernel does not
    // do that — verified 2026-08-14 by running faf-cli against a `type:
    // cli` project.faf and observing 21 active slots, not 9.
    const content = "project:\n  name: X\n  type: cli\n";
    const result = calculateScore(content);
    try std.testing.expectEqual(@as(u8, 21), result.total); // no enterprise signal → 21, not 9
}

test "calculate full score — all 21 base slots filled, no enterprise signal" {
    const content =
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
        \\stack:
        \\  frontend: none
        \\  css_framework: none
        \\  ui_library: none
        \\  state_management: none
        \\  backend: none
        \\  api_type: none
        \\  runtime: Zig
        \\  database: none
        \\  connection: none
        \\  hosting: GitHub
        \\  build: zig build
        \\  cicd: GitHub Actions
    ;

    const result = calculateScore(content);

    try std.testing.expectEqual(ProjectType.cli, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total); // base slots only, no enterprise signal
    try std.testing.expectEqual(@as(u8, 21), result.filled);
    try std.testing.expectEqual(@as(u8, 100), result.score);
}

test "partial score calculation" {
    const content =
        \\project:
        \\  name: Partial
        \\  type: cli
        \\human_context:
        \\  who: Someone
    ;

    const result = calculateScore(content);

    try std.testing.expectEqual(ProjectType.cli, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
    try std.testing.expectEqual(@as(u8, 2), result.filled); // name + who
    try std.testing.expectEqual(@as(u8, 9), result.score); // 2/21 ≈ 9%
}

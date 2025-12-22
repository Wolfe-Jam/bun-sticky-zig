///! Wolfejam Slot-Based Scoring System
///! Score = (Filled Slots / Applicable Slots) x 100
///!
///! 21 total slots across 5 categories.
///! Type-aware scoring - CLI uses 9 slots, Fullstack uses 21.
///!
///! NOT Elon weights. Wolfejam slots.

const std = @import("std");

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLOT DEFINITIONS - 21 Slots Total
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Project slots (3)
pub const PROJECT_SLOTS = [_][]const u8{
    "project.name",
    "project.goal",
    "project.main_language",
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

/// Human context slots (6)
pub const HUMAN_SLOTS = [_][]const u8{
    "human_context.who",
    "human_context.what",
    "human_context.why",
    "human_context.where",
    "human_context.when",
    "human_context.how",
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PROJECT TYPES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pub const ProjectType = enum {
    cli, // 9 slots: project + human
    library, // 9 slots: project + human
    api, // 17 slots: project + backend + universal + human
    webapp, // 16 slots: project + frontend + universal + human
    fullstack, // 21 slots: all
    mobile, // 9 slots: project + human
    unknown, // 9 slots: project + human (safe default)

    pub fn applicableSlotCount(self: ProjectType) u8 {
        return switch (self) {
            .cli, .library, .mobile, .unknown => 9, // project(3) + human(6)
            .webapp => 16, // project(3) + frontend(4) + universal(3) + human(6)
            .api => 17, // project(3) + backend(5) + universal(3) + human(6)
            .fullstack => 21, // all
        };
    }

    pub fn hasProject(self: ProjectType) bool {
        _ = self;
        return true; // All types have project
    }

    pub fn hasFrontend(self: ProjectType) bool {
        return switch (self) {
            .webapp, .fullstack => true,
            else => false,
        };
    }

    pub fn hasBackend(self: ProjectType) bool {
        return switch (self) {
            .api, .fullstack => true,
            else => false,
        };
    }

    pub fn hasUniversal(self: ProjectType) bool {
        return switch (self) {
            .api, .webapp, .fullstack => true,
            else => false,
        };
    }

    pub fn hasHuman(self: ProjectType) bool {
        _ = self;
        return true; // All types have human context
    }
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
            .filled = 0,
            .total = 0,
            .score = 0,
        };
    }
};

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SCORING FUNCTIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Detect project type from content
pub fn detectProjectType(content: []const u8) ProjectType {
    // Look for explicit type field
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

    // Infer from stack
    const has_frontend = std.mem.indexOf(u8, content, "frontend:") != null;
    const has_backend = std.mem.indexOf(u8, content, "backend:") != null or
        std.mem.indexOf(u8, content, "database:") != null;

    if (has_frontend and has_backend) return .fullstack;
    if (has_frontend) return .webapp;
    if (has_backend) return .api;

    return .unknown;
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

/// Calculate FAF score using Wolfejam slot-based system
/// Score = (Filled Slots / Applicable Slots) x 100
pub fn calculateScore(content: []const u8) ScoreResult {
    var result = ScoreResult.init();

    // Detect project type
    result.project_type = detectProjectType(content);

    // Count each section
    result.project = countSection(content, &PROJECT_SLOTS, result.project_type.hasProject());
    result.frontend = countSection(content, &FRONTEND_SLOTS, result.project_type.hasFrontend());
    result.backend = countSection(content, &BACKEND_SLOTS, result.project_type.hasBackend());
    result.universal = countSection(content, &UNIVERSAL_SLOTS, result.project_type.hasUniversal());
    result.human = countSection(content, &HUMAN_SLOTS, result.project_type.hasHuman());

    // Sum totals
    result.filled = result.project.filled + result.frontend.filled +
        result.backend.filled + result.universal.filled + result.human.filled;

    result.total = result.project.total + result.frontend.total +
        result.backend.total + result.universal.total + result.human.total;

    // Calculate final score (use u16 to avoid overflow)
    result.score = if (result.total > 0) @intCast((@as(u16, result.filled) * 100) / @as(u16, result.total)) else 0;

    return result;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS - WJTTC Championship Grade
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "slot counts are correct" {
    try std.testing.expectEqual(@as(usize, 3), PROJECT_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 4), FRONTEND_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 5), BACKEND_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 3), UNIVERSAL_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 6), HUMAN_SLOTS.len);
    // Total: 3 + 4 + 5 + 3 + 6 = 21
}

test "project type slot counts" {
    try std.testing.expectEqual(@as(u8, 9), ProjectType.cli.applicableSlotCount());
    try std.testing.expectEqual(@as(u8, 9), ProjectType.library.applicableSlotCount());
    try std.testing.expectEqual(@as(u8, 17), ProjectType.api.applicableSlotCount());
    try std.testing.expectEqual(@as(u8, 16), ProjectType.webapp.applicableSlotCount());
    try std.testing.expectEqual(@as(u8, 21), ProjectType.fullstack.applicableSlotCount());
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

test "calculate CLI score" {
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
    ;

    const result = calculateScore(content);

    try std.testing.expectEqual(ProjectType.cli, result.project_type);
    try std.testing.expectEqual(@as(u8, 9), result.total); // CLI = 9 slots
    try std.testing.expectEqual(@as(u8, 9), result.filled); // All filled
    try std.testing.expectEqual(@as(u8, 100), result.score); // 100%
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
    try std.testing.expectEqual(@as(u8, 9), result.total);
    try std.testing.expectEqual(@as(u8, 2), result.filled); // name + who
    try std.testing.expectEqual(@as(u8, 22), result.score); // 2/9 = 22%
}

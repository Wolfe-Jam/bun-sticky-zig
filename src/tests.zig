///! WJTTC Championship-Grade Test Suite
///! Comprehensive testing for bun-sticky
///!
///! Test categories:
///! - Slot definitions (21 base + 12 enterprise = 33 Mk4 canonical slots)
///! - Type detection (7 types, informational/display only)
///! - Score calculations
///! - Tier boundaries (8 tiers)
///! - Edge cases
///! - Integration tests

const std = @import("std");
const scorer = @import("scorer.zig");
const tier = @import("tier.zig");

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLOT DEFINITION TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "slot counts - project has 3 slots" {
    try std.testing.expectEqual(@as(usize, 3), scorer.PROJECT_SLOTS.len);
}

test "slot counts - frontend has 4 slots" {
    try std.testing.expectEqual(@as(usize, 4), scorer.FRONTEND_SLOTS.len);
}

test "slot counts - backend has 5 slots" {
    try std.testing.expectEqual(@as(usize, 5), scorer.BACKEND_SLOTS.len);
}

test "slot counts - universal has 3 slots" {
    try std.testing.expectEqual(@as(usize, 3), scorer.UNIVERSAL_SLOTS.len);
}

test "slot counts - human has 6 slots" {
    try std.testing.expectEqual(@as(usize, 6), scorer.HUMAN_SLOTS.len);
}

test "slot counts - base is 21, +12 enterprise = 33 Mk4 canonical" {
    const base = scorer.PROJECT_SLOTS.len +
        scorer.FRONTEND_SLOTS.len +
        scorer.BACKEND_SLOTS.len +
        scorer.UNIVERSAL_SLOTS.len +
        scorer.HUMAN_SLOTS.len;
    try std.testing.expectEqual(@as(usize, 21), base);
    try std.testing.expectEqual(@as(usize, 12), scorer.ENTERPRISE_SLOTS.len);
    try std.testing.expectEqual(@as(usize, 33), base + scorer.ENTERPRISE_SLOTS.len);
}

test "project slots contain required fields" {
    try std.testing.expectEqualStrings("project.name", scorer.PROJECT_SLOTS[0]);
    try std.testing.expectEqualStrings("project.goal", scorer.PROJECT_SLOTS[1]);
    try std.testing.expectEqualStrings("project.main_language", scorer.PROJECT_SLOTS[2]);
}

test "human slots contain 5W1H" {
    try std.testing.expectEqualStrings("human_context.who", scorer.HUMAN_SLOTS[0]);
    try std.testing.expectEqualStrings("human_context.what", scorer.HUMAN_SLOTS[1]);
    try std.testing.expectEqualStrings("human_context.why", scorer.HUMAN_SLOTS[2]);
    try std.testing.expectEqualStrings("human_context.where", scorer.HUMAN_SLOTS[3]);
    try std.testing.expectEqualStrings("human_context.when", scorer.HUMAN_SLOTS[4]);
    try std.testing.expectEqualStrings("human_context.how", scorer.HUMAN_SLOTS[5]);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PROJECT TYPE TESTS
//
// ProjectType is informational/display only as of the Mk4 resync — it no
// longer gates slot applicability. A verified live faf-cli data point
// (2026-08-14) showed a `type: cli` project.faf scored against 21 active
// slots, not the 9 the old per-type table claimed. Applicability is now
// binary: 21 base slots always apply, 12 enterprise slots apply only when
// isEnterpriseApplicable() detects a monorepo/enterprise signal — see
// scorer.zig's own tests for that behavior.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "type detection still labels cli correctly (display only, no longer scored)" {
    const content = "project:\n  type: cli\n";
    try std.testing.expectEqual(scorer.ProjectType.cli, scorer.detectProjectType(content));
}

test "type detection still labels fullstack correctly (display only)" {
    const content = "project:\n  type: full\n";
    try std.testing.expectEqual(scorer.ProjectType.fullstack, scorer.detectProjectType(content));
}

test "a cli-type and a fullstack-type project face the same 21 base slots" {
    const cli_content = "project:\n  name: A\n  type: cli\n";
    const full_content = "project:\n  name: B\n  type: full\n";
    try std.testing.expectEqual(scorer.calculateScore(cli_content).total, scorer.calculateScore(full_content).total);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TYPE DETECTION TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "detect type - explicit cli" {
    const content = "project:\n  type: cli\n";
    try std.testing.expectEqual(scorer.ProjectType.cli, scorer.detectProjectType(content));
}

test "detect type - explicit CLI uppercase" {
    const content = "project:\n  type: CLI\n";
    try std.testing.expectEqual(scorer.ProjectType.cli, scorer.detectProjectType(content));
}

test "detect type - explicit library" {
    const content = "project:\n  type: library\n";
    try std.testing.expectEqual(scorer.ProjectType.library, scorer.detectProjectType(content));
}

test "detect type - explicit package" {
    const content = "project:\n  type: package\n";
    try std.testing.expectEqual(scorer.ProjectType.library, scorer.detectProjectType(content));
}

test "detect type - explicit api" {
    const content = "project:\n  type: api\n";
    try std.testing.expectEqual(scorer.ProjectType.api, scorer.detectProjectType(content));
}

test "detect type - explicit backend" {
    const content = "project:\n  type: backend\n";
    try std.testing.expectEqual(scorer.ProjectType.api, scorer.detectProjectType(content));
}

test "detect type - explicit webapp" {
    const content = "project:\n  type: webapp\n";
    try std.testing.expectEqual(scorer.ProjectType.webapp, scorer.detectProjectType(content));
}

test "detect type - explicit frontend" {
    const content = "project:\n  type: frontend\n";
    try std.testing.expectEqual(scorer.ProjectType.webapp, scorer.detectProjectType(content));
}

test "detect type - explicit fullstack" {
    const content = "project:\n  type: fullstack\n";
    try std.testing.expectEqual(scorer.ProjectType.fullstack, scorer.detectProjectType(content));
}

test "detect type - explicit mobile" {
    const content = "project:\n  type: mobile\n";
    try std.testing.expectEqual(scorer.ProjectType.mobile, scorer.detectProjectType(content));
}

test "detect type - infer fullstack from stack" {
    const content = "stack:\n  frontend: React\n  backend: Node\n";
    try std.testing.expectEqual(scorer.ProjectType.fullstack, scorer.detectProjectType(content));
}

test "detect type - infer webapp from frontend only" {
    const content = "stack:\n  frontend: React\n";
    try std.testing.expectEqual(scorer.ProjectType.webapp, scorer.detectProjectType(content));
}

test "detect type - infer api from backend only" {
    const content = "stack:\n  backend: Express\n";
    try std.testing.expectEqual(scorer.ProjectType.api, scorer.detectProjectType(content));
}

test "detect type - infer api from database" {
    const content = "stack:\n  database: PostgreSQL\n";
    try std.testing.expectEqual(scorer.ProjectType.api, scorer.detectProjectType(content));
}

test "detect type - unknown when empty" {
    const content = "";
    try std.testing.expectEqual(scorer.ProjectType.unknown, scorer.detectProjectType(content));
}

test "detect type - unknown when no type info" {
    const content = "project:\n  name: test\n";
    try std.testing.expectEqual(scorer.ProjectType.unknown, scorer.detectProjectType(content));
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLOT VALUE DETECTION TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "hasSlotValue - finds name" {
    const content = "project:\n  name: MyProject\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.name"));
}

test "hasSlotValue - finds goal" {
    const content = "project:\n  goal: Build something great\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.goal"));
}

test "hasSlotValue - missing field returns false" {
    const content = "project:\n  name: Test\n";
    try std.testing.expect(!scorer.hasSlotValue(content, "project.goal"));
}

test "hasSlotValue - empty value returns false" {
    const content = "project:\n  name:\n";
    try std.testing.expect(!scorer.hasSlotValue(content, "project.name"));
}

test "hasSlotValue - whitespace only returns false" {
    const content = "project:\n  name:   \n";
    try std.testing.expect(!scorer.hasSlotValue(content, "project.name"));
}

test "hasSlotValue - finds nested human_context" {
    const content = "human_context:\n  who: Developers\n";
    try std.testing.expect(scorer.hasSlotValue(content, "human_context.who"));
}

test "hasSlotValue - finds stack values" {
    const content = "stack:\n  frontend: React\n  backend: Node\n";
    try std.testing.expect(scorer.hasSlotValue(content, "stack.frontend"));
    try std.testing.expect(scorer.hasSlotValue(content, "stack.backend"));
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SCORE CALCULATION TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "score - CLI needs all 21 base slots for 100%, not just project+human" {
    // Old Mk3 model gave CLI-type projects only 9 applicable slots
    // (project+human). Verified live against faf-cli 2026-08-14: a
    // `type: cli` project.faf is scored against 21 active slots. A CLI
    // project that only fills project+human now lands well under 100%.
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
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(scorer.ProjectType.cli, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
    try std.testing.expectEqual(@as(u8, 9), result.filled); // project(3) + human(6)
    try std.testing.expectEqual(@as(u8, 42), result.score); // 9/21 ≈ 42%
}

test "score - CLI partial (3/21)" {
    const content =
        \\project:
        \\  name: Partial
        \\  goal: Something
        \\  type: cli
        \\human_context:
        \\  who: Someone
    ;
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(scorer.ProjectType.cli, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
    try std.testing.expectEqual(@as(u8, 3), result.filled);
    try std.testing.expectEqual(@as(u8, 14), result.score); // 3/21 ≈ 14%
}

test "score - fullstack 100% (21/21 base slots, no enterprise signal)" {
    const content =
        \\project:
        \\  name: FullApp
        \\  goal: Complete app
        \\  main_language: TypeScript
        \\  type: fullstack
        \\stack:
        \\  frontend: React
        \\  css_framework: Tailwind
        \\  ui_library: shadcn
        \\  state_management: zustand
        \\  backend: Node
        \\  api_type: REST
        \\  runtime: Bun
        \\  database: PostgreSQL
        \\  connection: prisma
        \\  hosting: Vercel
        \\  build: vite
        \\  cicd: GitHub Actions
        \\human_context:
        \\  who: Users
        \\  what: Full app
        \\  why: Complete solution
        \\  where: Web
        \\  when: 2025
        \\  how: npm start
    ;
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(scorer.ProjectType.fullstack, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
    try std.testing.expectEqual(@as(u8, 21), result.filled);
    try std.testing.expectEqual(@as(u8, 100), result.score);
}

test "score - webapp faces the same 21 base slots (type no longer gates applicability)" {
    const content = "project:\n  type: webapp\n";
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(scorer.ProjectType.webapp, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
}

test "score - api faces the same 21 base slots (type no longer gates applicability)" {
    const content = "project:\n  type: api\n";
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(scorer.ProjectType.api, result.project_type);
    try std.testing.expectEqual(@as(u8, 21), result.total);
}

test "score - enterprise 12 slots only count with a monorepo signal (33 total)" {
    const content = "project:\n  name: Big\n  type: fullstack\nmonorepo:\n  packages_count: 5\n";
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(@as(u8, 33), result.total);
}

test "score - section breakdown correct" {
    const content =
        \\project:
        \\  name: Test
        \\  goal: Test
        \\  type: cli
        \\human_context:
        \\  who: Devs
        \\  what: Tool
    ;
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(@as(u8, 2), result.project.filled);
    try std.testing.expectEqual(@as(u8, 3), result.project.total);
    try std.testing.expectEqual(@as(u8, 2), result.human.filled);
    try std.testing.expectEqual(@as(u8, 6), result.human.total);
}

test "score - empty content returns 0" {
    const content = "";
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(@as(u8, 0), result.filled);
    try std.testing.expectEqual(@as(u8, 0), result.score);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TIER TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "tier - 100 is Trophy" {
    const t = tier.getTier(100);
    try std.testing.expectEqualStrings("Trophy", t.name);
}

test "tier - 99 is Gold" {
    const t = tier.getTier(99);
    try std.testing.expectEqualStrings("Gold", t.name);
}

test "tier - 95 is Silver" {
    const t = tier.getTier(95);
    try std.testing.expectEqualStrings("Silver", t.name);
}

test "tier - 96 is Silver" {
    const t = tier.getTier(96);
    try std.testing.expectEqualStrings("Silver", t.name);
}

test "tier - 85 is Bronze" {
    const t = tier.getTier(85);
    try std.testing.expectEqualStrings("Bronze", t.name);
}

test "tier - 94 is Bronze" {
    const t = tier.getTier(94);
    try std.testing.expectEqualStrings("Bronze", t.name);
}

test "tier - 70 is Green" {
    const t = tier.getTier(70);
    try std.testing.expectEqualStrings("Green", t.name);
}

test "tier - 84 is Green" {
    const t = tier.getTier(84);
    try std.testing.expectEqualStrings("Green", t.name);
}

test "tier - 55 is Yellow" {
    const t = tier.getTier(55);
    try std.testing.expectEqualStrings("Yellow", t.name);
}

test "tier - 69 is Yellow" {
    const t = tier.getTier(69);
    try std.testing.expectEqualStrings("Yellow", t.name);
}

test "tier - 54 is Red" {
    const t = tier.getTier(54);
    try std.testing.expectEqualStrings("Red", t.name);
}

test "tier - 0 is White, not Red" {
    // 8-tier ladder: Red is 1-54, White is exactly 0 (empty .faf).
    const t = tier.getTier(0);
    try std.testing.expectEqualStrings("White", t.name);
}

test "tier - 1 is Red" {
    const t = tier.getTier(1);
    try std.testing.expectEqualStrings("Red", t.name);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// BOUNDARY TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "boundary - exactly 100 is Trophy not Gold" {
    const t = tier.getTier(100);
    try std.testing.expectEqualStrings("Trophy", t.name);
}

test "boundary - exactly 99 is Gold not Silver" {
    const t = tier.getTier(99);
    try std.testing.expectEqualStrings("Gold", t.name);
}

test "boundary - exactly 95 is Silver not Bronze" {
    const t = tier.getTier(95);
    try std.testing.expectEqualStrings("Silver", t.name);
}

test "boundary - exactly 85 is Bronze not Green" {
    const t = tier.getTier(85);
    try std.testing.expectEqualStrings("Bronze", t.name);
}

test "boundary - exactly 70 is Green not Yellow" {
    const t = tier.getTier(70);
    try std.testing.expectEqualStrings("Green", t.name);
}

test "boundary - exactly 55 is Yellow not Red" {
    const t = tier.getTier(55);
    try std.testing.expectEqualStrings("Yellow", t.name);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// EDGE CASE TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "edge - very long field value" {
    const content = "project:\n  name: ThisIsAVeryLongProjectNameThatShouldStillWork\n  type: cli\n";
    const result = scorer.calculateScore(content);
    try std.testing.expect(result.filled > 0);
}

test "edge - special characters in value" {
    const content = "project:\n  name: Test-Project_123\n  type: cli\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.name"));
}

test "edge - multiple colons in value" {
    const content = "project:\n  goal: Build a CLI: fast and simple\n  type: cli\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.goal"));
}

test "edge - unicode in content" {
    const content = "project:\n  name: 日本語プロジェクト\n  type: cli\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.name"));
}

test "edge - tabs instead of spaces" {
    const content = "project:\n\tname: Test\n\ttype: cli\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.name"));
}

test "edge - CRLF line endings" {
    const content = "project:\r\n  name: Test\r\n  type: cli\r\n";
    try std.testing.expect(scorer.hasSlotValue(content, "project.name"));
}

test "edge - no newline at end" {
    const content = "project:\n  name: Test\n  type: cli";
    const result = scorer.calculateScore(content);
    try std.testing.expect(result.filled > 0);
}

test "edge - percentage calculation no overflow" {
    // 21 filled * 100 = 2100, must not overflow u8
    const content =
        \\project:
        \\  name: FullApp
        \\  goal: Complete app
        \\  main_language: TypeScript
        \\  type: fullstack
        \\stack:
        \\  frontend: React
        \\  css_framework: Tailwind
        \\  ui_library: shadcn
        \\  state_management: zustand
        \\  backend: Node
        \\  api_type: REST
        \\  runtime: Bun
        \\  database: PostgreSQL
        \\  connection: prisma
        \\  hosting: Vercel
        \\  build: vite
        \\  cicd: GitHub Actions
        \\human_context:
        \\  who: Users
        \\  what: Full app
        \\  why: Complete solution
        \\  where: Web
        \\  when: 2025
        \\  how: npm start
    ;
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(@as(u8, 100), result.score);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// WOLFEJAM FORMULA VERIFICATION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "wolfejam formula - score equals filled/total * 100" {
    const content =
        \\project:
        \\  name: Test
        \\  goal: Test
        \\  main_language: Zig
        \\  type: cli
        \\human_context:
        \\  who: Devs
    ;
    const result = scorer.calculateScore(content);
    // 4 filled / 21 total ≈ 19%
    try std.testing.expectEqual(@as(u8, 4), result.filled);
    try std.testing.expectEqual(@as(u8, 21), result.total);
    try std.testing.expectEqual(@as(u8, 19), result.score);
}

test "wolfejam formula - type no longer gates the base slot count" {
    // Both cli and fullstack face the same 21 base slots now — verified
    // against live faf-cli 2026-08-14. Only the 12 enterprise slots are
    // conditional (on a monorepo/enterprise signal, not on type).
    const cli_content = "project:\n  type: cli\n";
    const cli_result = scorer.calculateScore(cli_content);
    try std.testing.expectEqual(@as(u8, 21), cli_result.total);

    const full_content = "project:\n  type: fullstack\n";
    const full_result = scorer.calculateScore(full_content);
    try std.testing.expectEqual(@as(u8, 21), full_result.total);
}

test "wolfejam formula - only enterprise is conditionally non-applicable" {
    const content = "project:\n  type: cli\n";
    const result = scorer.calculateScore(content);
    try std.testing.expectEqual(@as(u8, 4), result.frontend.total);
    try std.testing.expectEqual(@as(u8, 5), result.backend.total);
    try std.testing.expectEqual(@as(u8, 3), result.universal.total);
    try std.testing.expectEqual(@as(u8, 0), result.enterprise.total); // no monorepo signal
}

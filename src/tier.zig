///! FAF Tier System — single source of truth for bun-sticky-zig.
///!
///! Mirrors ~/FAF/cli/src/core/tiers.ts (public/OSS source, checked
///! 2026-08-14). 8 tiers, geometric ladder — NOT the medal/colored-circle
///! emoji set. Per current doctrine that ladder (🥇🥈🥉🟢🟡🔴🤍) is HISTORY
///! and must not be reintroduced.
///!
///! ✪ (Proof Seal, U+272A) marks 100% on work surfaces — CLI, code, docs.
///! 🏆 is reserved for social surfaces (X, blogs) and is deliberately not
///! used here: this binary IS a work surface.
///!
///! The honor tier ("Big Orange" 🍊) is deliberately NOT represented here —
///! it's never calculated from a score (multi-criteria, AI/human-awarded,
///! never described as "above 100%"). A prior version of this file computed
///! a "Big Croissant" tier at score > 100, which broke that doctrine on two
///! counts (superseded name, and being score-computed at all). Removed,
///! not renamed — main.zig previously carried a second, independent
///! tierColor()/tierGlyph() implementation that disagreed with this file;
///! that duplicate is gone too. This is now the only tier ladder.

const std = @import("std");

pub const Tier = struct {
    name: []const u8,
    emoji: []const u8, // display glyph (terminal + card text)
    min_score: u8,
    color: []const u8, // ANSI escape, for terminal output
    hex: []const u8, // hex color, for SVG/HTML cards
};

// ANSI colors
const ANSI_GOLD = "\x1b[38;5;220m";
const ANSI_CYAN = "\x1b[38;5;51m";
const ANSI_CYAN_DEEP = "\x1b[38;5;44m";
const ANSI_GREEN = "\x1b[1;32m";
const ANSI_YELLOW = "\x1b[2;33m";
const ANSI_RED = "\x1b[2;31m";
const ANSI_DIM = "\x1b[2m";

pub const TIERS = [_]Tier{
    .{ .name = "Trophy", .emoji = "✪", .min_score = 100, .color = ANSI_GOLD, .hex = "#FFCB45" },
    .{ .name = "Gold", .emoji = "★", .min_score = 99, .color = ANSI_GOLD, .hex = "#FFCB45" },
    .{ .name = "Silver", .emoji = "◆", .min_score = 95, .color = ANSI_CYAN, .hex = "#00D4D4" },
    .{ .name = "Bronze", .emoji = "◇", .min_score = 85, .color = ANSI_CYAN_DEEP, .hex = "#00A0A0" },
    .{ .name = "Green", .emoji = "●", .min_score = 70, .color = ANSI_GREEN, .hex = "#3FB950" },
    .{ .name = "Yellow", .emoji = "●", .min_score = 55, .color = ANSI_YELLOW, .hex = "#D29922" },
    .{ .name = "Red", .emoji = "○", .min_score = 1, .color = ANSI_RED, .hex = "#F85149" },
    .{ .name = "White", .emoji = "♡", .min_score = 0, .color = ANSI_DIM, .hex = "#8B949E" },
};

/// Get tier for a given score
pub fn getTier(score: u8) Tier {
    for (TIERS) |t| {
        if (score >= t.min_score) {
            return t;
        }
    }
    return TIERS[TIERS.len - 1]; // White
}

/// Get tier name only
pub fn getTierName(score: u8) []const u8 {
    return getTier(score).name;
}

/// Get tier glyph only
pub fn getTierEmoji(score: u8) []const u8 {
    return getTier(score).emoji;
}

/// Get tier ANSI color only
pub fn getTierColor(score: u8) []const u8 {
    return getTier(score).color;
}

/// Get tier hex color only (SVG/HTML cards)
pub fn getTierHex(score: u8) []const u8 {
    return getTier(score).hex;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "trophy at 100 — proof seal, not the social trophy emoji" {
    const t = getTier(100);
    try std.testing.expectEqualStrings("Trophy", t.name);
    try std.testing.expectEqualStrings("✪", t.emoji);
}

test "gold at 99" {
    try std.testing.expectEqualStrings("Gold", getTier(99).name);
    try std.testing.expectEqualStrings("★", getTier(99).emoji);
}

test "silver at 95" {
    try std.testing.expectEqualStrings("Silver", getTier(95).name);
}

test "bronze at 85" {
    try std.testing.expectEqualStrings("Bronze", getTier(85).name);
}

test "green at 70" {
    try std.testing.expectEqualStrings("Green", getTier(70).name);
}

test "yellow at 55" {
    try std.testing.expectEqualStrings("Yellow", getTier(55).name);
}

test "red at 1" {
    try std.testing.expectEqualStrings("Red", getTier(1).name);
}

test "white at exactly 0 — score(), not tier(), decides emptiness" {
    const t = getTier(0);
    try std.testing.expectEqualStrings("White", t.name);
    try std.testing.expectEqualStrings("♡", t.emoji);
}

test "boundary - 84 is green not bronze" {
    try std.testing.expectEqualStrings("Green", getTier(84).name);
}

test "boundary - 54 is red not yellow" {
    try std.testing.expectEqualStrings("Red", getTier(54).name);
}

test "no medal emoji anywhere in the ladder" {
    for (TIERS) |t| {
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🥇"));
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🥈"));
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🥉"));
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🟢"));
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🟡"));
        try std.testing.expect(!std.mem.eql(u8, t.emoji, "🔴"));
    }
}

test "no Big Croissant / Big Orange auto-tier — honor is never score-computed" {
    // 8 tiers only: Trophy/Gold/Silver/Bronze/Green/Yellow/Red/White.
    try std.testing.expectEqual(@as(usize, 8), TIERS.len);
    for (TIERS) |t| {
        try std.testing.expect(!std.mem.eql(u8, t.name, "Big Croissant"));
        try std.testing.expect(!std.mem.eql(u8, t.name, "Big Orange"));
    }
}

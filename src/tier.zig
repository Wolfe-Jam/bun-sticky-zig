///! FAF Tier System
///! The Michelin Star for Repos
///!
///! 8 tiers from Big Croissant (105%) to Red (<55%)
///!
///! Big Croissant is AI-awarded for excellence beyond 100%:
///! - Perfect score (100%)
///! - Excellent documentation
///! - Clean, fast, well-tested code
///! - Goes above and beyond

const std = @import("std");

pub const Tier = struct {
    name: []const u8,
    emoji: []const u8,
    min_score: u8,
    color: []const u8,
};

// ANSI colors
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";
const GOLD = "\x1b[38;5;220m";
const SILVER = "\x1b[38;5;250m";
const BRONZE = "\x1b[38;5;208m";
const CROISSANT = "\x1b[38;5;208m"; // Big Croissant - the Michelin Star

pub const TIERS = [_]Tier{
    .{ .name = "Big Croissant", .emoji = "\xf0\x9f\xa5\x90", .min_score = 101, .color = CROISSANT }, // 🥐 AI-awarded excellence
    .{ .name = "Trophy", .emoji = "\xf0\x9f\x8f\x86", .min_score = 100, .color = GOLD }, // Trophy at 100%
    .{ .name = "Gold", .emoji = "\xf0\x9f\xa5\x87", .min_score = 99, .color = GOLD },
    .{ .name = "Silver", .emoji = "\xf0\x9f\xa5\x88", .min_score = 95, .color = SILVER },
    .{ .name = "Bronze", .emoji = "\xf0\x9f\xa5\x89", .min_score = 85, .color = BRONZE },
    .{ .name = "Green", .emoji = "\xf0\x9f\x9f\xa2", .min_score = 70, .color = GREEN },
    .{ .name = "Yellow", .emoji = "\xf0\x9f\x9f\xa1", .min_score = 55, .color = YELLOW },
    .{ .name = "Red", .emoji = "\xf0\x9f\x94\xb4", .min_score = 0, .color = RED },
};

/// Get tier for a given score
pub fn getTier(score: u8) Tier {
    for (TIERS) |tier| {
        if (score >= tier.min_score) {
            return tier;
        }
    }
    return TIERS[TIERS.len - 1]; // Red
}

/// Get tier name only
pub fn getTierName(score: u8) []const u8 {
    return getTier(score).name;
}

/// Get tier emoji only
pub fn getTierEmoji(score: u8) []const u8 {
    return getTier(score).emoji;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TESTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test "big croissant at 105 (AI-awarded)" {
    // Big Croissant can only be awarded externally - score never exceeds 100 automatically
    const tier = getTier(105);
    try std.testing.expectEqualStrings("Big Croissant", tier.name);
}

test "big croissant at 101 (minimum for AI award)" {
    const tier = getTier(101);
    try std.testing.expectEqualStrings("Big Croissant", tier.name);
}

test "trophy at 100" {
    const tier = getTier(100);
    try std.testing.expectEqualStrings("Trophy", tier.name);
}

test "gold at 99" {
    const tier = getTier(99);
    try std.testing.expectEqualStrings("Gold", tier.name);
}

test "silver at 95" {
    const tier = getTier(95);
    try std.testing.expectEqualStrings("Silver", tier.name);
}

test "bronze at 85" {
    const tier = getTier(85);
    try std.testing.expectEqualStrings("Bronze", tier.name);
}

test "green at 70" {
    const tier = getTier(70);
    try std.testing.expectEqualStrings("Green", tier.name);
}

test "yellow at 55" {
    const tier = getTier(55);
    try std.testing.expectEqualStrings("Yellow", tier.name);
}

test "red below 55" {
    const tier = getTier(54);
    try std.testing.expectEqualStrings("Red", tier.name);
}

test "boundary - 84 is green not bronze" {
    const tier = getTier(84);
    try std.testing.expectEqualStrings("Green", tier.name);
}

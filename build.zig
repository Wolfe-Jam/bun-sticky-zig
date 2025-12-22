const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable - Zig 0.15+ API
    const exe = b.addExecutable(.{
        .name = "bun-sticky",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run bun-sticky CLI");
    run_step.dependOn(&run_cmd.step);

    // Tests - main.zig tests
    const main_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Tests - scorer.zig tests
    const scorer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/scorer.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Tests - tier.zig tests
    const tier_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tier.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Tests - comprehensive WJTTC test suite
    const wjttc_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const run_scorer_tests = b.addRunArtifact(scorer_tests);
    const run_tier_tests = b.addRunArtifact(tier_tests);
    const run_wjttc_tests = b.addRunArtifact(wjttc_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_scorer_tests.step);
    test_step.dependOn(&run_tier_tests.step);
    test_step.dependOn(&run_wjttc_tests.step);
}

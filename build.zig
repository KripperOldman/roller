const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const pcre2_dep = b.dependency("pcre2", .{
        .target = target,
        .optimize = optimize,
    });
    const pcre2_lib = pcre2_dep.artifact("pcre2-8");

    const clap_dep = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    const clap_module = clap_dep.module("clap");

    const exe = b.addExecutable(.{
        .name = "roller",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.linkLibrary(pcre2_lib);
    exe.root_module.addImport("clap", clap_module);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibrary(pcre2_lib);
    exe_unit_tests.root_module.addImport("clap", clap_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const build_all_step = b.step("all", "Build for all targets");
    inline for (targets) |t| {
        const triple = try t.zigTriple(b.allocator);

        const target_pcre2_dep = b.dependency("pcre2", .{
            .target = b.resolveTargetQuery(t),
            .optimize = optimize,
        });
        const target_pcre2_lib = target_pcre2_dep.artifact("pcre2-8");

        const target_clap_dep = b.dependency("clap", .{
            .target = b.resolveTargetQuery(t),
            .optimize = optimize,
        });
        const target_clap_module = target_clap_dep.module("clap");

        const target_exe = b.addExecutable(.{
            .name = try std.fmt.allocPrint(
                b.allocator,
                "{s}-{s}",
                .{ "roller", triple },
            ),
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(t),
            .optimize = .ReleaseSafe,
        });

        target_exe.root_module.linkLibrary(target_pcre2_lib);
        target_exe.root_module.addImport("clap", target_clap_module);

        const target_output = b.addInstallArtifact(target_exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = "release",
                },
            },
        });

        build_all_step.dependOn(&target_output.step);
    }
}

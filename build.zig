const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = setupExe(b, target, optimize);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const prod_step = b.step("prod", "Build for all platforms");
    for (targets) |t| {
        const prod_target = b.resolveTargetQuery(t);
        const prod_exe = setupExe(b, prod_target, optimize);

        const triple = try t.zigTriple(b.allocator);
        const ext = if (t.os_tag == .windows) ".exe" else "";
        const exe_name = b.fmt("zournal{s}", .{ext});

        const wf = b.addWriteFiles();
        _ = wf.addCopyFile(prod_exe.getEmittedBin(), exe_name);
        if (t.os_tag == .linux) {
            _ = wf.addCopyFile(b.path("resources/zournal.desktop"), "zournal.desktop");
        }

        const tar = b.addSystemCommand(&.{ "tar", "czf" });
        tar.setCwd(wf.getDirectory());
        const archive_name = b.fmt("{s}.tar.gz", .{triple});
        const archive = tar.addOutputFileArg(archive_name);
        tar.addArg(".");

        const install_archive = b.addInstallFileWithDir(archive, .prefix, archive_name);
        prod_step.dependOn(&install_archive.step);
    }
}

fn setupExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "zournal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .use_llvm = true,
    });

    // zqlite
    const zqlite = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zqlite", zqlite.module("zqlite"));

    // DVUI
    switch (target.result.os.tag) {
        .macos => {
            const xcode_frameworks = b.dependency("xcode_frameworks", .{});
            const dvui_dep = b.dependency("dvui", .{
                .target = target,
                .optimize = optimize,
                .backend = .sdl3,
                .system_include_path = xcode_frameworks.path("include"),
                .system_framework_path = xcode_frameworks.path("Frameworks"),
                .library_path = xcode_frameworks.path("lib"),
            });
            exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
            exe.root_module.addImport("sdl-backend", dvui_dep.module("sdl3"));
            exe.root_module.addFrameworkPath(xcode_frameworks.path("Frameworks"));
            exe.root_module.addSystemIncludePath(xcode_frameworks.path("include"));
            exe.root_module.addLibraryPath(xcode_frameworks.path("lib"));
        },
        else => {
            const dvui_dep = b.dependency("dvui", .{
                .target = target,
                .optimize = optimize,
                .backend = .sdl3,
            });
            exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
            exe.root_module.addImport("sdl-backend", dvui_dep.module("sdl3"));
        },
    }

    // Known Folders
    const known_folders = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    }).module("known-folders");
    exe.root_module.addImport("known-folders", known_folders);

    return exe;
}

const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
    .{ .cpu_arch = .aarch64, .os_tag = .windows },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const prod = b.option(bool, "prod", "Build for all platform") orelse false;

    if (prod) {
        for (targets) |t| {
            const prod_target = b.resolveTargetQuery(t);
            const prod_exe = setupExe(b, prod_target, .ReleaseSafe);
            prod_exe.root_module.strip = true;
            if (t.os_tag == .windows) {
                prod_exe.subsystem = .windows;
            }

            const triple = try t.zigTriple(b.allocator);
            const ext = prod_target.result.exeFileExt();
            const dir_name = b.fmt("zournal-{s}", .{triple});

            const wf = b.addWriteFiles();
            _ = wf.addCopyFile(prod_exe.getEmittedBin(), b.fmt("{s}/zournal{s}", .{ dir_name, ext }));
            if (t.os_tag == .linux) {
                _ = wf.addCopyFile(b.path("resources/zournal.desktop"), b.fmt("{s}/zournal.desktop", .{dir_name}));
                _ = wf.addCopyFile(b.path("resources/zournal.png"), b.fmt("{s}/zournal.png", .{dir_name}));
            }

            const archive_name = b.fmt("{s}.tar.gz", .{dir_name});
            const tar = b.addSystemCommand(&.{ "tar", "-czf" });
            tar.setCwd(wf.getDirectory());
            const archive = tar.addOutputFileArg2(archive_name, .{});
            tar.addArg("-C");
            tar.addDirectoryArg2(wf.getDirectory(), .{});
            tar.addArg(dir_name);

            const install_archive = b.addInstallFileWithDir(archive, .prefix, archive_name);
            b.getInstallStep().dependOn(&install_archive.step);
        }
        return;
    }
    const exe = setupExe(b, target, optimize);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
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
    });

    // zqlite
    const zqlite = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    // Known Folders
    const known_folders = b.dependency("known_folders", .{
        .target = target,
        .optimize = optimize,
    }).module("known-folders");

    // DVUI
    const dvui_dep = switch (target.result.os.tag) {
        .macos => blk: {
            const xcode_frameworks = b.lazyDependency("xcode_frameworks", .{}) orelse return exe;

            break :blk b.dependency("dvui", .{
                .target = target,
                .optimize = optimize,
                .backend = .sdl3,
                .system_include_path = xcode_frameworks.path("include"),
                .system_framework_path = xcode_frameworks.path("Frameworks"),
                .library_path = xcode_frameworks.path("lib"),
            });
        },
        else => b.dependency("dvui", .{
            .target = target,
            .optimize = optimize,
            .backend = .sdl3,
        }),
    };

    exe.root_module.addImport("zqlite", zqlite.module("zqlite"));
    exe.root_module.addImport("known-folders", known_folders);
    exe.root_module.addImport("dvui", dvui_dep.module("dvui_sdl3"));
    exe.root_module.addImport("sdl-backend", dvui_dep.module("sdl3"));

    return exe;
}

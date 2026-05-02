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
        const out_name = b.fmt("Zournal-{s}{s}", .{ triple, ext });

        const install = b.addInstallArtifact(prod_exe, .{
            .dest_dir = .{ .override = .{ .custom = "." } },
            .dest_sub_path = out_name,
            .pdb_dir = .disabled,
        });
        prod_step.dependOn(&install.step);
    }
}

fn setupExe(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "Zournal",
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
    exe.root_module.addCSourceFile(.{
        .file = b.path("lib/sqlite3.c"),
        .flags = &[_][]const u8{
            "-DSQLITE_DQS=0",
            "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1",
            "-DSQLITE_USE_ALLOCA=1",
            "-DSQLITE_THREADSAFE=1",
            "-DSQLITE_TEMP_STORE=3",
            "-DSQLITE_ENABLE_API_ARMOR=1",
            "-DSQLITE_ENABLE_UNLOCK_NOTIFY",
            "-DSQLITE_DEFAULT_FILE_PERMISSIONS=0600",
            "-DSQLITE_OMIT_DECLTYPE=1",
            "-DSQLITE_OMIT_DEPRECATED=1",
            "-DSQLITE_OMIT_LOAD_EXTENSION=1",
            "-DSQLITE_OMIT_PROGRESS_CALLBACK=1",
            "-DSQLITE_OMIT_SHARED_CACHE",
            "-DSQLITE_OMIT_TRACE=1",
            "-DSQLITE_OMIT_UTF16=1",
            "-DHAVE_USLEEP=0",
        },
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

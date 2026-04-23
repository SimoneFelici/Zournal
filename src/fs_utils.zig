const std = @import("std");
const types = @import("types.zig");
const db = @import("db_utils.zig");
const known_folders = @import("known-folders");
const AppContext = @import("context.zig").AppContext;

pub fn getRootDir(ctx: *const AppContext) !std.Io.Dir {
    const data_dir = (try known_folders.getPath(ctx.io, ctx.allocator, &ctx.environ_map, .data)) orelse
        return error.NoDataDir;
    defer ctx.allocator.free(data_dir);

    const app_data = try std.Io.Dir.path.join(ctx.allocator, &.{ data_dir, "Zournal" });
    defer ctx.allocator.free(app_data);

    const cwd = std.Io.Dir.cwd();
    return cwd.openDir(ctx.io, app_data, .{}) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try cwd.createDirPath(ctx.io, app_data);
            std.log.info("Created root folder {s}", .{app_data});
            break :blk try cwd.openDir(ctx.io, app_data, .{});
        },
        else => return err,
    };
}

pub fn getProjectsDir(ctx: *const AppContext) !std.Io.Dir {
    var root = try getRootDir(ctx);
    defer root.close(ctx.io);

    return root.openDir(ctx.io, "projects", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try root.createDir(ctx.io, "projects", .default_dir);
            std.log.info("Created projects folder", .{});
            break :blk try root.openDir(ctx.io, "projects", .{ .iterate = true });
        },
        else => return err,
    };
}

fn compareByMtimeDesc(_: void, a: types.ProjectEntry, b: types.ProjectEntry) bool {
    return a.mtime.durationTo(b.mtime).toNanoseconds() < 0;
}

pub fn listProjects(ctx: *const AppContext) !std.ArrayList(types.ProjectEntry) {
    var dir = try getProjectsDir(ctx);
    defer dir.close(ctx.io);

    var projects: std.ArrayList(types.ProjectEntry) = .empty;
    var iter = dir.iterate();
    while (try iter.next(ctx.io)) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".db")) {
            const stat = dir.statFile(ctx.io, entry.name, .{}) catch continue;
            const cut = entry.name[0 .. entry.name.len - 3];
            const name = try ctx.allocator.dupe(u8, cut);
            try projects.append(ctx.allocator, .{ .name = name, .mtime = stat.mtime });
        }
    }

    std.mem.sort(types.ProjectEntry, projects.items, {}, compareByMtimeDesc);
    return projects;
}

pub fn importProject(ctx: *const AppContext, src_path: []const u8) !void {
    const basename = std.Io.Dir.path.basename(src_path);
    if (!std.mem.endsWith(u8, basename, ".db")) return error.InvalidFileType;

    const data_dir = (try known_folders.getPath(ctx.io, ctx.allocator, &ctx.environ_map, .data)) orelse
        return error.NoDataDir;
    defer ctx.allocator.free(data_dir);

    var dir = try getProjectsDir(ctx);
    dir.close(ctx.io);

    const dst_path = try std.Io.Dir.path.join(
        ctx.allocator,
        &.{ data_dir, "Zournal", "projects", basename },
    );
    defer ctx.allocator.free(dst_path);

    try std.Io.Dir.copyFileAbsolute(src_path, dst_path, ctx.io, .{});

    std.log.info("Imported project: {s}", .{basename});
}

pub fn getProjectPath(ctx: *const AppContext, name: []const u8) ![:0]u8 {
    const data_dir = (try known_folders.getPath(ctx.io, ctx.allocator, &ctx.environ_map, .data)) orelse
        return error.NoDataDir;
    defer ctx.allocator.free(data_dir);

    const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.db", .{name});
    defer ctx.allocator.free(filename);

    const path = try std.Io.Dir.path.join(
        ctx.allocator,
        &.{ data_dir, "Zournal", "projects", filename },
    );
    defer ctx.allocator.free(path);

    return ctx.allocator.dupeZ(u8, path);
}

pub fn createProject(ctx: *const AppContext, name: []const u8) !void {
    var dir = try getProjectsDir(ctx);
    defer dir.close(ctx.io);

    const filename = try std.fmt.allocPrint(ctx.allocator, "{s}.db", .{name});
    defer ctx.allocator.free(filename);

    var file = try dir.createFile(ctx.io, filename, .{ .exclusive = true });
    file.close(ctx.io);

    const path = try getProjectPath(ctx, name);
    defer ctx.allocator.free(path);

    try db.initDatabase(path);

    std.log.info("Created project: {s}.db", .{name});
}

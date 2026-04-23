const std = @import("std");
const types = @import("types.zig");
const db = @import("db_utils.zig");
const known_folders = @import("known-folders");

pub fn getRootDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
) !std.Io.Dir {
    const data_dir = (try known_folders.getPath(io, allocator, environ_map, .data)) orelse
        return error.NoDataDir;
    defer allocator.free(data_dir);

    const app_data = try std.Io.Dir.path.join(allocator, &.{ data_dir, "Zournal" });
    defer allocator.free(app_data);

    const cwd = std.Io.Dir.cwd();
    return cwd.openDir(io, app_data, .{}) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try cwd.createDirPath(io, app_data);
            std.log.info("Created root folder {s}", .{app_data});
            break :blk try cwd.openDir(io, app_data, .{});
        },
        else => return err,
    };
}

pub fn getProjectsDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
) !std.Io.Dir {
    var root = try getRootDir(allocator, io, environ_map);
    defer root.close(io);

    return root.openDir(io, "projects", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            try root.createDir(io, "projects", .default_dir);
            std.log.info("Created projects folder", .{});
            break :blk try root.openDir(io, "projects", .{ .iterate = true });
        },
        else => return err,
    };
}

fn compareByMtimeDesc(_: void, a: types.ProjectEntry, b: types.ProjectEntry) bool {
    return a.mtime.durationTo(b.mtime).toNanoseconds() < 0;
}

pub fn listProjects(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
) !std.ArrayList(types.ProjectEntry) {
    var dir = try getProjectsDir(allocator, io, environ_map);
    defer dir.close(io);

    var projects: std.ArrayList(types.ProjectEntry) = .empty;
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".db")) {
            const stat = dir.statFile(io, entry.name, .{}) catch continue;
            const cut = entry.name[0 .. entry.name.len - 3];
            const name = try allocator.dupe(u8, cut);
            try projects.append(allocator, .{ .name = name, .mtime = stat.mtime });
        }
    }

    std.mem.sort(types.ProjectEntry, projects.items, {}, compareByMtimeDesc);
    return projects;
}

pub fn importProject(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    src_path: []const u8,
) !void {
    const basename = std.Io.Dir.path.basename(src_path);
    if (!std.mem.endsWith(u8, basename, ".db")) return error.InvalidFileType;

    const data_dir = (try known_folders.getPath(io, allocator, environ_map, .data)) orelse
        return error.NoDataDir;
    defer allocator.free(data_dir);

    // Make sure the destination directory tree exists.
    var dir = try getProjectsDir(allocator, io, environ_map);
    dir.close(io);

    const dst_path = try std.Io.Dir.path.join(
        allocator,
        &.{ data_dir, "Zournal", "projects", basename },
    );
    defer allocator.free(dst_path);

    try std.Io.Dir.copyFileAbsolute(src_path, dst_path, io, .{});

    std.log.info("Imported project: {s}", .{basename});
}

pub fn getProjectPath(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    name: []const u8,
) ![:0]u8 {
    const data_dir = (try known_folders.getPath(io, allocator, environ_map, .data)) orelse
        return error.NoDataDir;
    defer allocator.free(data_dir);

    const filename = try std.fmt.allocPrint(allocator, "{s}.db", .{name});
    defer allocator.free(filename);

    const path = try std.Io.Dir.path.join(
        allocator,
        &.{ data_dir, "Zournal", "projects", filename },
    );
    defer allocator.free(path);

    return allocator.dupeZ(u8, path);
}

pub fn createProject(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    name: []const u8,
) !void {
    var dir = try getProjectsDir(allocator, io, environ_map);
    defer dir.close(io);

    const filename = try std.fmt.allocPrint(allocator, "{s}.db", .{name});
    defer allocator.free(filename);

    var file = try dir.createFile(io, filename, .{ .exclusive = true });
    file.close(io);

    const path = try getProjectPath(allocator, io, environ_map, name);
    defer allocator.free(path);

    try db.initDatabase(path);

    std.log.info("Created project: {s}.db", .{name});
}

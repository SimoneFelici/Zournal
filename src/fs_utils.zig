const std = @import("std");
const types = @import("types.zig");
const db = @import("db_utils.zig");

pub fn getRootDir(allocator: std.mem.Allocator) std.fs.Dir {
    const app_data = std.fs.getAppDataDir(allocator, "Zournal") catch unreachable;
    defer allocator.free(app_data);
    return std.fs.cwd().openDir(app_data, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.fs.cwd().makePath(app_data) catch unreachable;
            std.log.info("Created root folder {s}\n", .{app_data});
            return std.fs.cwd().openDir(app_data, .{}) catch unreachable;
        },
        else => unreachable,
    };
}

pub fn getProjectsDir(allocator: std.mem.Allocator) std.fs.Dir {
    var root = getRootDir(allocator);
    defer root.close();
    return root.openDir("projects", .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => {
            root.makeDir("projects") catch unreachable;
            std.log.info("Created projects folder\n", .{});
            return root.openDir("projects", .{ .iterate = true }) catch unreachable;
        },
        else => unreachable,
    };
}

fn compareByMtimeDesc(_: void, a: types.ProjectEntry, b: types.ProjectEntry) bool {
    return a.mtime > b.mtime;
}

pub fn listProjects(allocator: std.mem.Allocator) !std.ArrayList(types.ProjectEntry) {
    var dir = getProjectsDir(allocator);
    defer dir.close();

    var projects: std.ArrayList(types.ProjectEntry) = .{};
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".db")) {
            const stat = dir.statFile(entry.name) catch continue;
            const cut = entry.name[0 .. entry.name.len - 3];
            const name = try allocator.dupe(u8, cut);
            try projects.append(allocator, .{ .name = name, .mtime = stat.mtime });
        }
    }

    std.mem.sort(types.ProjectEntry, projects.items, {}, compareByMtimeDesc);
    return projects;
}

pub fn importProject(allocator: std.mem.Allocator, src_path: []const u8) !void {
    var dir = getProjectsDir(allocator);
    defer dir.close();

    const basename = std.fs.path.basename(src_path);

    if (!std.mem.endsWith(u8, basename, ".db")) return error.InvalidFileType;

    try std.fs.cwd().copyFile(src_path, dir, basename, .{});

    std.log.info("Imported project: {s}", .{basename});
}

pub fn getProjectPath(allocator: std.mem.Allocator, name: []const u8) ![:0]u8 {
    var dir = getProjectsDir(allocator);
    defer dir.close();

    const filename = try std.fmt.allocPrint(allocator, "{s}.db", .{name});
    defer allocator.free(filename);

    const path = try dir.realpathAlloc(allocator, filename);
    defer allocator.free(path);

    return try allocator.dupeZ(u8, path);
}

pub fn createProject(allocator: std.mem.Allocator, name: []const u8) !void {
    var dir = getProjectsDir(allocator);
    defer dir.close();

    const filename = try std.fmt.allocPrint(allocator, "{s}.db", .{name});
    defer allocator.free(filename);

    var file = try dir.createFile(filename, .{ .exclusive = true });
    file.close();

    const path = try getProjectPath(allocator, name);
    defer allocator.free(path);

    try db.initDatabase(path);

    std.log.info("Created project: {s}.db", .{name});
}

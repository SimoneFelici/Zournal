const std = @import("std");
const types = @import("types.zig");

pub fn getRootDir(allocator: std.mem.Allocator) std.fs.Dir {
    const app_data = std.fs.getAppDataDir(allocator, "Zournal") catch unreachable;
    defer allocator.free(app_data);
    return std.fs.cwd().openDir(app_data, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => {
            std.fs.cwd().makePath(app_data) catch unreachable;
            std.log.info("Created root folder {s}\n", .{app_data});
            return std.fs.cwd().openDir(app_data, .{ .iterate = true }) catch unreachable;
        },
        else => unreachable,
    };
}

pub fn listProjects(allocator: std.mem.Allocator) !std.ArrayList(types.ProjectEntry) {
    var root = getRootDir(allocator);
    defer root.close();

    var projects: std.ArrayList(types.ProjectEntry) = .{};
    var iter = root.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .directory) {
            const stat = root.statFile(entry.name) catch continue;
            const name = try allocator.dupe(u8, entry.name);
            try projects.append(allocator, .{ .name = name, .mtime = stat.mtime });
        }
    }

    std.mem.sort(types.ProjectEntry, projects.items, {}, compareByMtimeDesc);
    return projects;
}

fn compareByMtimeDesc(_: void, a: types.ProjectEntry, b: types.ProjectEntry) bool {
    return a.mtime > b.mtime;
}

// Thanks: @squeek502
// https://ziggit.dev/t/recursively-copy-directory-using-std/1697/2

pub fn importFolder(allocator: std.mem.Allocator, src_path: []const u8) !void {
    var root = getRootDir(allocator);
    defer root.close();

    const basename = std.fs.path.basename(src_path);
    var src_dir = try std.fs.cwd().openDir(src_path, .{ .iterate = true });
    defer src_dir.close();

    var dst_dir = try root.makeOpenPath(basename, .{});
    defer dst_dir.close();

    var walker = try src_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => try entry.dir.copyFile(entry.basename, dst_dir, entry.path, .{}),
            .directory => try dst_dir.makePath(entry.path),
            else => {},
        }
    }

    std.log.info("Imported project: {s}", .{basename});
}

pub fn createProject(allocator: std.mem.Allocator, name: []const u8) !void {
    var root = getRootDir(allocator);
    defer root.close();
    try root.makeDir(name);
    // TODO: inizializzare project.db con SQLite
    std.log.info("Created project: {s}", .{name});
}

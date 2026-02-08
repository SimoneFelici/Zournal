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

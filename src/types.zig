const std = @import("std");

pub const ProjectEntry = struct {
    name: []const u8,
    mtime: i128,
};

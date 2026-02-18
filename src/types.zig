const std = @import("std");

pub const ProjectEntry = struct {
    name: []const u8,
    mtime: i128,
};

pub const CaseEntry = struct {
    id: i64,
    name: []const u8,
};

pub const PersonEntry = struct {
    id: i64,
    name: []const u8,
};

pub const NoteEntry = struct {
    id: i64,
    title: []const u8,
    content: []const u8,
};

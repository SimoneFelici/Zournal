const std = @import("std");

pub const ProjectEntry = struct {
    name: []const u8,
    mtime: std.Io.Timestamp,
};

pub const CaseEntry = struct {
    id: i64,
    name: []const u8,
};

pub const PersonEntry = struct {
    id: i64,
    name: []const u8,
    initials: [2]u8 = .{ 0, 0 },
    initials_len: u2 = 0,

    pub fn computeInitials(self: *PersonEntry) void {
        var it = std.mem.splitScalar(u8, self.name, ' ');
        const first = it.next();
        const second = it.next();
        self.initials_len = 0;
        if (first) |f| {
            if (f.len > 0) {
                self.initials[self.initials_len] = std.ascii.toUpper(f[0]);
                self.initials_len += 1;
            }
            if (second) |s| {
                if (s.len > 0) {
                    self.initials[self.initials_len] = std.ascii.toUpper(s[0]);
                    self.initials_len += 1;
                }
            } else if (f.len > 1) {
                self.initials[self.initials_len] = std.ascii.toUpper(f[1]);
                self.initials_len += 1;
            }
        }
    }
};

pub const NoteEntry = struct {
    id: i64,
    title: []const u8,
    content: []const u8,
};

pub const RelationshipEntry = struct {
    id: i64,
    person_a_id: i64,
    person_b_id: i64,
    label: []const u8,
};

pub const NodePos = struct {
    person_id: i64,
    x: f32,
    y: f32,
};

pub const TimelineEvent = struct {
    id: i64,
    label: []const u8,
    content: []const u8,
    x: f32,
    y: f32,
};

pub const EventConnection = struct {
    id: i64,
    from_id: i64,
    to_id: i64,
    connection_type: []const u8,
};

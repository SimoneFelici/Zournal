const std = @import("std");
const dvui = @import("dvui");

pub const ProjectEntry = struct {
    name: []const u8,
    mtime: std.Io.Timestamp,
};

pub const CaseEntry = struct {
    id: i64,
    name: []const u8,
};

pub const AvatarColor = enum(u8) {
    gray,
    maroon,
    green,
    purple,
    navy,

    pub fn fill(self: AvatarColor) dvui.ColorOrGradient {
        switch (self) {
            inline else => |c| return @field(dvui.ColorOrGradient, @tagName(c)),
        }
    }
};

pub const PersonEntry = struct {
    id: i64,
    name: []const u8,
    initials: [2]u8 = .{ 0, 0 },
    initials_len: u2 = 0,
    color: AvatarColor = .gray,

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
    case_id: ?i64 = null,
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

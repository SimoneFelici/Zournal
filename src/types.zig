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
    red,
    green,
    purple,
    blue,

    pub fn fill(self: AvatarColor) dvui.ColorOrGradient {
        const dark = dvui.themeGet().dark;
        return switch (self) {
            .gray => if (dark) .gray else .silver,
            .red => if (dark) .maroon else .red,
            .green => if (dark) .green else .lime,
            .purple => if (dark) .purple else .fuchsia,
            .blue => if (dark) .navy else .cyan,
        };
    }
};

pub const PersonEntry = struct {
    id: i64,
    name: []const u8,
    initials: [8]u8 = @splat(0),
    initials_len: u8 = 0,
    color: AvatarColor = .gray,

    pub fn computeInitials(self: *PersonEntry) void {
        self.initials_len = 0;
        var words = std.mem.tokenizeScalar(u8, self.name, ' ');
        const first = words.next() orelse return;

        var it = (std.unicode.Utf8View.init(first) catch return).iterator();
        if (it.nextCodepointSlice()) |c| self.appendInitial(c);

        const next = if (words.next()) |w| firstChar(w) else it.nextCodepointSlice();
        if (next) |c| self.appendInitial(c);
    }

    fn firstChar(word: []const u8) ?[]const u8 {
        var it = (std.unicode.Utf8View.init(word) catch return null).iterator();
        return it.nextCodepointSlice();
    }

    fn appendInitial(self: *PersonEntry, c: []const u8) void {
        @memcpy(self.initials[self.initials_len..][0..c.len], c);
        if (c.len == 1) self.initials[self.initials_len] = std.ascii.toUpper(c[0]);
        self.initials_len += @intCast(c.len);
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

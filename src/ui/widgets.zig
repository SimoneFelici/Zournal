const std = @import("std");
const dvui = @import("dvui");
const types = @import("../types.zig");

// Uniform card width
pub fn personCardWidth(people: []const types.PersonEntry, min_w: f32, max_w: f32) f32 {
    var w: f32 = min_w;
    for (people) |p| {
        w = @max(w, dvui.themeGet().font_body.textSize(p.name).w + 16.0);
    }
    return @min(w, max_w);
}

// Text entry
pub fn syncText(te: *dvui.TextEntryWidget, stored: *[]const u8, allocator: std.mem.Allocator) void {
    if (te.textGet().len == 0 and stored.len > 0 and dvui.focusedWidgetId() != te.data().id) {
        te.textSet(stored.*, false);
    }
    const text = te.textGet();
    if (!std.mem.eql(u8, text, stored.*)) {
        stored.* = allocator.dupe(u8, text) catch unreachable;
    }
}

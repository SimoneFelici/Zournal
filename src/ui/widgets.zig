const std = @import("std");
const dvui = @import("dvui");

/// Text entry
pub fn syncText(te: *dvui.TextEntryWidget, stored: *[]const u8, allocator: std.mem.Allocator) void {
    if (te.textGet().len == 0 and stored.len > 0 and dvui.focusedWidgetId() != te.data().id) {
        te.textSet(stored.*, false);
    }
    const text = te.textGet();
    if (!std.mem.eql(u8, text, stored.*)) {
        stored.* = allocator.dupe(u8, text) catch unreachable;
    }
}

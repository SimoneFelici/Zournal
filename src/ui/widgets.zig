const std = @import("std");
const dvui = @import("dvui");

// Search toggle
pub fn searchToggle(src: std.builtin.SourceLocation) bool {
    const parent_id = dvui.parentGet().data().id;
    var open = dvui.dataGet(null, parent_id, "search_open", bool) orelse false;
    if (dvui.buttonIcon(src, "Search", dvui.entypo.magnifying_glass, .{ .draw_focus = false }, .{}, .{ .gravity_x = 0.5 })) {
        open = !open;
        dvui.dataSet(null, parent_id, "search_open", open);
    }
    return open;
}

// search entry
pub fn searchEntry(src: std.builtin.SourceLocation) []const u8 {
    var row = dvui.box(src, .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();

    var te = dvui.textEntry(@src(), .{}, .{ .gravity_x = 0.5, .min_size_content = .{ .w = 200, .h = 15 } });
    const query = te.textGet();
    te.deinit();
    return query;
}

// Search row
pub fn searchBox(src: std.builtin.SourceLocation) []const u8 {
    var row = dvui.box(src, .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();

    dvui.icon(@src(), "Search", dvui.entypo.magnifying_glass, .{}, .{ .gravity_y = 0.5 });

    var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
    const query = te.textGet();
    te.deinit();
    return query;
}

// Substring search
pub fn matches(text: []const u8, query: []const u8) bool {
    return query.len == 0 or std.ascii.indexOfIgnoreCase(text, query) != null;
}

pub fn fitText(text: []const u8, max_w: f32) []const u8 {
    const font = dvui.themeGet().font_body;
    if (font.textSize(text).w <= max_w) return text;
    var end: usize = text.len;
    while (end > 0) {
        end -= 1;
        while (end > 0 and (text[end] & 0xC0) == 0x80) end -= 1;
        if (font.textSize(text[0..end]).w <= max_w) return text[0..end];
    }
    return text[0..0];
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

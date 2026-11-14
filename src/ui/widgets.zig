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
    return query.len == 0 or std.ascii.findIgnoreCase(text, query) != null;
}

const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");

pub fn render(s: *state.ProjectViewState, allocator: std.mem.Allocator) !void {
    if (!s.cases_loaded)
        try s.loadCases(allocator);

    // New case
    {
        if (dvui.button(@src(), "New Case", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 1 })) {
            const count = s.db.countCases() catch 0;
            const case_name = std.fmt.allocPrint(allocator, "Case #{d}", .{count + 1}) catch unreachable;

            const id = s.db.createCase(allocator, case_name) catch |err| {
                std.log.err("Create case failed: {}", .{err});
                return;
            };

            const duped = allocator.dupe(u8, case_name) catch unreachable;
            s.cases.insert(allocator, 0, .{ .id = id, .name = duped }) catch unreachable;
        }
    }

    // Case list
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        for (s.cases.items, 0..) |case_entry, i| {
            if (dvui.button(@src(), case_entry.name, .{ .draw_focus = false }, .{
                .id_extra = i,
                .expand = .horizontal,
            })) {
                // TODO
                std.log.info("Selected case: {s}", .{case_entry.name});
            }
        }
    }
}

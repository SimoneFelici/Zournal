const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");

const COLS = 4;

pub fn render(s: *state.ProjectViewState, allocator: std.mem.Allocator) !void {
    if (!s.cases_loaded)
        try s.loadCases(allocator);

    // New case
    {
        if (dvui.buttonIcon(@src(), "New Case", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            const id = s.db.createCase() catch |err| {
                std.log.err("Create case failed: {}", .{err});
                return;
            };
            const name = std.fmt.allocPrint(allocator, "Case #{d}", .{id}) catch unreachable;
            s.cases.insert(allocator, 0, .{ .id = id, .name = name }) catch unreachable;
        }
    }

    // Case wall
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        var i: usize = 0;
        while (i < s.cases.items.len) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = i,
                .expand = .horizontal,
            });
            defer row.deinit();

            var col: usize = 0;
            while (col < COLS and i < s.cases.items.len) : ({
                col += 1;
                i += 1;
            }) {
                const case_entry = s.cases.items[i];
                if (dvui.button(@src(), case_entry.name, .{ .draw_focus = false }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                    .min_size_content = .{ .w = 120, .h = 80 },
                    .corner_radius = dvui.Rect.all(3),
                })) {
                    std.log.info("Selected case: {s}", .{case_entry.name});
                }
            }
        }
    }
}

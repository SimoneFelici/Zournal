const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const grid = @import("../ui/grid.zig");

const MIN_CARD_WIDTH: f32 = 140;

pub fn render(ctx: *AppContext, page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = ctx.allocator;

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
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < s.cases.items.len) : (row_idx += 1) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.cases.items.len) : ({
                c += 1;
                i += 1;
            }) {
                const case_entry = s.cases.items[i];
                if (dvui.button(@src(), case_entry.name, .{ .draw_focus = false }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                    .min_size_content = .{ .w = 120, .h = 80 },
                    .corner_radius = dvui.Rect.all(3),
                })) {
                    s.case_view = .{
                        .case_id = case_entry.id,
                        .case_name = case_entry.name,
                    };
                }
            }
            while (c < cols) : (c += 1) {
                var spacer = dvui.box(@src(), .{}, .{ .id_extra = c, .expand = .horizontal });
                defer spacer.deinit();
            }
        }
    }
}

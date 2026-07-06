const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");

const CARD_W: f32 = 200;
const CARD_H: f32 = 80;
const CARD_SLOT: f32 = CARD_W + 24;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    // Top bar
    var search_open = false;
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        search_open = widgets.searchToggle(@src());

        if (dvui.buttonIcon(@src(), "New Case", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            const id = s.db.createCase() catch |err| {
                std.log.err("Create case failed: {}", .{err});
                return;
            };
            const name = std.fmt.allocPrint(allocator, "Case #{d}", .{id}) catch unreachable;
            s.cases.insert(allocator, 0, .{ .id = id, .name = name }) catch unreachable;
        }
    }

    const query: []const u8 = if (search_open) widgets.searchEntry(@src()) else "";

    // Case wall
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, CARD_SLOT);

        var i: usize = 0;
        var row_idx: usize = 0;
        var shown: usize = 0;
        while (i < s.cases.items.len) : (row_idx += 1) {
            while (i < s.cases.items.len and !widgets.matches(s.cases.items[i].name, query)) i += 1;
            if (i >= s.cases.items.len) break;

            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.cases.items.len) : (i += 1) {
                const case_entry = s.cases.items[i];
                if (!widgets.matches(case_entry.name, query)) continue;
                c += 1;
                shown += 1;
                if (dvui.button(@src(), widgets.fitText(case_entry.name, CARD_W - 16), .{ .draw_focus = false }, .{ .id_extra = i, .min_size_content = .{ .w = CARD_W, .h = CARD_H }, .corners = dvui.CornerRect.round(3) })) {
                    s.case_view = .{
                        .case_id = case_entry.id,
                        .case_name = case_entry.name,
                    };
                }
            }
        }
    }
}

const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const widgets = @import("../ui/widgets.zig");

const CARD_W: f32 = 200;
const CARD_H: f32 = 80;
const CARD_SLOT: f32 = CARD_W + 24;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    // Top bar
    var query: []const u8 = "";
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        var search = dvui.textEntry(@src(), .{ .placeholder = "Search..." }, .{ .gravity_x = 0.5 });
        query = search.textGet();
        search.deinit();

        if (dvui.buttonIcon(@src(), "New Case", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .style = .highlight, .gravity_x = 1 })) {
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

        var flex = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal });
        defer flex.deinit();

        for (s.cases.items, 0..) |case_entry, i| {
            if (!widgets.matches(case_entry.name, query)) continue;
            if (dvui.button(@src(), case_entry.name, .{ .draw_focus = false }, .{
                .id_extra = i,
                .min_size_content = .{ .w = CARD_W, .h = CARD_H },
                .max_size_content = .{ .w = CARD_W, .h = CARD_H },
                .corners = .all(3),
            })) {
                s.case_view = state.CaseViewState.init(case_entry);
            }
        }
    }
}

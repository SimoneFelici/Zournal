const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
pub fn render(page: *state.PageState, allocator: std.mem.Allocator) !void {
    _ = allocator;
    var s = &page.project_view;
    var outer = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .both,
    });
    defer outer.deinit();

    // Sidebar
    {
        var sidebar = dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .vertical,
        });
        defer sidebar.deinit();
        {
            var tabs = dvui.tabs(@src(), .{ .dir = .vertical, .draw_focus = false }, .{ .expand = .both, .gravity_y = 0 });
            defer tabs.deinit();
            const tab_entries = [_]struct { tab: state.ProjectViewState.Tab, label: []const u8 }{
                .{ .tab = .cases, .label = "Cases" },
                .{ .tab = .timeline, .label = "Timeline" },
                .{ .tab = .people, .label = "People" },
                .{ .tab = .relationships, .label = "Relationships" },
                .{ .tab = .notes, .label = "Notes" },
            };
            for (tab_entries) |entry| {
                var tab = tabs.addTab(s.tab == entry.tab, .{ .expand = .horizontal });
                defer tab.deinit();
                dvui.labelNoFmt(@src(), entry.label, .{}, .{});
                if (tab.clicked()) {
                    s.tab = entry.tab;
                }
            }

            // Back
            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
                page.* = .{ .project_select = .{} };
            }
        }
    }

    // Content
    {
        var content = dvui.box(@src(), .{}, .{
            .expand = .both,
            .background = true,
            .style = .window,
            .role = .tab_panel,
        });
        defer content.deinit();
        switch (s.tab) {
            .cases => dvui.label(@src(), "Cases", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
            .timeline => dvui.label(@src(), "Timeline", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
            .people => dvui.label(@src(), "People", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
            .relationships => dvui.label(@src(), "Relationships", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
            .notes => dvui.label(@src(), "Notes", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
        }
    }
}

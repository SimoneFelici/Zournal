const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const cases = @import("cases.zig");
const people = @import("people.zig");
const notes = @import("notes.zig");
const case_view = @import("case_view.zig");
const person_view = @import("person_view.zig");
const relationships = @import("relationships.zig");

pub fn render(ctx: *AppContext, page: *state.PageState) !void {
    var s = &page.project_view;

    if (s.case_view != null) {
        try case_view.render(ctx, page);
        return;
    }

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
                switch (entry.tab) {
                    .cases => dvui.label(@src(), "Cases ({d})", .{s.cases.items.len}, .{}),
                    .people => dvui.label(@src(), "People ({d})", .{s.people.items.len}, .{}),
                    .notes => dvui.label(@src(), "Notes ({d})", .{s.notes.items.len}, .{}),
                    else => dvui.labelNoFmt(@src(), entry.label, .{}, .{}),
                }
                if (tab.clicked()) {
                    s.tab = entry.tab;
                    s.person_view = null;
                }
            }

            // Back
            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
                s.db.close();
                page.* = .{ .project_select = .{} };
                return;
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
            .cases => try cases.render(ctx, page),
            .people => if (s.person_view != null)
                try person_view.render(ctx, s.db, &s.person_view)
            else
                try people.render(ctx, page),
            .notes => try notes.render(ctx, page),
            .timeline => dvui.label(@src(), "Timeline", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
            .relationships => try relationships.render(ctx, page),
        }
    }
}

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

pub fn render(ctx: *AppContext, page: *state.PageState) !dvui.App.Result {
    var s = &page.project_view;

    if (s.case_view != null) {
        try case_view.render(ctx, page);
        return .ok;
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
                .{ .tab = .people, .label = "People" },
                .{ .tab = .relationships, .label = "Relationships" },
                .{ .tab = .notes, .label = "Notes" },
            };

            for (tab_entries) |entry| {
                var tab = tabs.addTab(s.tab == entry.tab, .{ .process_events = true }, .{ .expand = .horizontal });
                defer tab.deinit();
                switch (entry.tab) {
                    .cases => dvui.label(@src(), "Cases ({d})", .{s.cases.items.len}, .{}),
                    .people => dvui.label(@src(), "People ({d})", .{s.people.items.len}, .{}),
                    .notes => dvui.label(@src(), "Notes ({d})", .{s.notes.items.len}, .{}),
                    .relationships => dvui.label(@src(), "Relationships ({d})", .{s.relationships.relationships.items.len}, .{}),
                }
                if (tab.clicked()) {
                    s.tab = entry.tab;
                    s.person_view = null;
                }
            }

            // Exit
            if (dvui.button(@src(), "Exit", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill = .red, .gravity_y = 1 })) {
                s.db.close();
                return .close;
            }

            // Back
            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
                s.deinit();
                page.* = .{ .project_select = state.ProjectSelectState.init(ctx.allocator) };
                return .ok;
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
            .cases => try cases.render(page),
            .people => if (s.person_view != null)
                try person_view.render(s.db, &s.person_view, s.allocator())
            else
                try people.render(page),
            .notes => try notes.render(page),
            .relationships => try relationships.render(page),
        }
    }
    return .ok;
}

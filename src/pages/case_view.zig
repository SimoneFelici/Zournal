const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");
const notes_view = @import("../ui/notes_view.zig");
const person_view = @import("person_view.zig");
const timeline = @import("timeline.zig");

const CARD_W_PEOPLE: f32 = 140;
const CARD_SLOT_PEOPLE: f32 = CARD_W_PEOPLE + 12;
const AVATAR_SIZE: f32 = 60;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    var cv = &s.case_view.?;

    const allocator = s.allocator();
    try cv.load(s.db, allocator);

    var outer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
    defer outer.deinit();

    // Sidebar
    {
        var sidebar = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .vertical });
        defer sidebar.deinit();

        {
            var name_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer name_row.deinit();
            dvui.label(@src(), "{s}", .{cv.case_name}, .{ .gravity_y = 0.5 });
            if (dvui.buttonIcon(@src(), "Rename", dvui.entypo.edit, .{ .draw_focus = false }, .{}, .{})) {
                cv.rename_dialog = !cv.rename_dialog;
                cv.delete_case_confirm = false;
            }
            if (dvui.buttonIcon(@src(), "Delete Case", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red })) {
                cv.delete_case_confirm = !cv.delete_case_confirm;
                cv.rename_dialog = false;
            }
        }

        if (cv.rename_dialog) {
            var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
            const current = te.textGet();
            if (current.len == 0 and cv.case_name.len > 0 and dvui.focusedWidgetId() != te.data().id) {
                te.textSet(cv.case_name, false);
            }
            const new_name = te.textGet();
            const enter = te.enter_pressed;
            te.deinit();

            if (enter or dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue, .expand = .horizontal })) {
                if (new_name.len > 0) {
                    s.db.renameCase(cv.case_id, new_name) catch |err| {
                        std.log.err("Rename case failed: {}", .{err});
                    };
                    const duped = allocator.dupe(u8, new_name) catch unreachable;
                    cv.case_name = duped;
                    for (s.cases.items) |*c| {
                        if (c.id == cv.case_id) {
                            c.name = duped;
                            break;
                        }
                    }
                    cv.rename_dialog = false;
                }
            }
        }

        if (cv.delete_case_confirm) {
            dvui.labelNoFmt(@src(), "Are you sure?", .{}, .{ .gravity_x = 0.5 });

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{ .expand = .horizontal })) {
                cv.delete_case_confirm = false;
            }

            if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill = .red })) {
                s.db.deleteCase(cv.case_id) catch |err| {
                    std.log.err("Delete case failed: {}", .{err});
                    return;
                };
                for (s.cases.items, 0..) |c, ci| {
                    if (c.id == cv.case_id) {
                        _ = s.cases.orderedRemove(ci);
                        break;
                    }
                }
                s.case_view = null;
                s.notes.reload(s.db, allocator);
                return;
            }
        }

        {
            var tabs = dvui.tabs(@src(), .{ .dir = .vertical, .draw_focus = false }, .{ .expand = .both, .gravity_y = 0 });
            defer tabs.deinit();

            const tab_entries = [_]struct { tab: state.CaseViewState.Tab, label: []const u8 }{
                .{ .tab = .people, .label = "People" },
                .{ .tab = .notes, .label = "Notes" },
                .{ .tab = .timeline, .label = "Timeline" },
            };

            for (tab_entries) |entry| {
                var tab = tabs.addTab(cv.tab == entry.tab, .{ .process_events = true }, .{ .expand = .horizontal });
                defer tab.deinit();
                switch (entry.tab) {
                    .people => dvui.label(@src(), "People ({d})", .{cv.people.items.len}, .{}),
                    .notes => dvui.label(@src(), "Notes ({d})", .{cv.notes.notes.items.len}, .{}),
                    else => dvui.labelNoFmt(@src(), entry.label, .{}, .{}),
                }
                if (tab.clicked()) {
                    cv.tab = entry.tab;
                    if (cv.person_view) |*pv| pv.notes.flushOpen(s.db);
                    cv.person_view = null;
                    cv.notes.reload(s.db, allocator);
                }
            }

            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
                s.db.updateCaseAccess(cv.case_id) catch {};
                cv.flushNotes(s.db);
                s.case_view = null;
                s.notes.reload(s.db, allocator);
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

        switch (cv.tab) {
            .people => if (cv.person_view != null) {
                try person_view.render(s, &cv.person_view);
                if (cv.person_view == null) cv.notes.reload(s.db, allocator);
            } else {
                try renderPeople(s, cv);
            },
            .notes => try notes_view.render(&cv.notes, s.db, allocator),
            .timeline => try timeline.render(s, cv),
        }
    }
}

fn renderPeople(s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    const allocator = s.allocator();

    var grid_search_open = false;
    {
        var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer btn_row.deinit();

        if (dvui.button(@src(), "Import", .{ .draw_focus = false }, .{})) {
            cv.import_person_dialog = !cv.import_person_dialog;
            cv.new_person_dialog = false;
        }

        grid_search_open = widgets.searchToggle(@src());

        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            cv.new_person_dialog = !cv.new_person_dialog;
            cv.import_person_dialog = false;
        }
    }

    if (cv.new_person_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const name = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            cv.new_person_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (name.len > 0) {
                const id = s.db.createPersonInCase(name, cv.case_id) catch |err| {
                    std.log.err("Create person in case failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, name) catch unreachable;
                var new_person = types.PersonEntry{ .id = id, .name = duped };
                new_person.computeInitials();
                cv.people.append(allocator, new_person) catch unreachable;
                s.people.append(allocator, new_person) catch unreachable;
                cv.new_person_dialog = false;
            }
        }
    }

    if (cv.import_person_dialog) {
        var show = true;
        var fw = dvui.floatingWindow(@src(), .{}, .{
            .min_size_content = .{ .w = 280, .h = 360 },
        });
        defer fw.deinit();

        fw.dragAreaSet(dvui.windowHeader("Import Person", "", &show));

        if (!show) {
            cv.import_person_dialog = false;
            return;
        }

        const query = widgets.searchBox(@src());

        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        for (s.people.items, 0..) |person, i| {
            const in_case = for (cv.people.items) |cp| {
                if (cp.id == person.id) break true;
            } else false;
            if (in_case) continue;
            if (query.len > 0 and std.ascii.indexOfIgnoreCase(person.name, query) == null) continue;

            if (dvui.button(@src(), person.name, .{ .draw_focus = false }, .{
                .id_extra = i,
                .expand = .horizontal,
            })) {
                s.db.linkPersonToCase(person.id, cv.case_id) catch |err| {
                    std.log.err("Link person to case failed: {}", .{err});
                    continue;
                };
                cv.people.append(allocator, person) catch unreachable;
            }
        }
    }

    const grid_query: []const u8 = if (grid_search_open) widgets.searchEntry(@src()) else "";

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    const cols = grid.colsFor(scroll.data().rect.w, CARD_SLOT_PEOPLE);

    var i: usize = 0;
    var row_idx: usize = 0;
    var shown: usize = 0;
    while (i < cv.people.items.len) : (row_idx += 1) {
        while (i < cv.people.items.len and !widgets.matches(cv.people.items[i].name, grid_query)) i += 1;
        if (i >= cv.people.items.len) break;
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .id_extra = row_idx,
            .expand = .horizontal,
        });
        defer row.deinit();

        var c: usize = 0;
        while (c < cols and i < cv.people.items.len) : (i += 1) {
            const person = cv.people.items[i];
            if (!widgets.matches(person.name, grid_query)) continue;
            c += 1;
            shown += 1;
            const idx = i;

            var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = idx,
                .min_size_content = .{ .w = CARD_W_PEOPLE },
            });
            defer card.deinit();

            const avatar = person.initials[0..person.initials_len];

            if (dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .id_extra = idx, .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = dvui.CornerRect.round(AVATAR_SIZE) })) {
                cv.person_view = state.PersonViewState.init(person, cv.case_id);
            }

            dvui.labelNoFmt(@src(), widgets.fitText(person.name, CARD_W_PEOPLE - 8.0), .{}, .{
                .id_extra = idx,
                .gravity_x = 0.5,
            });
        }
    }
}

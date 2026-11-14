const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const widgets = @import("../ui/widgets.zig");
const person_view = @import("person_view.zig");
const timeline = @import("timeline.zig");
const notes_view = @import("notes.zig");

const CARD_W_PEOPLE: f32 = 140;
const AVATAR_SIZE: f32 = 60;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    var cv = &s.case_view.?;

    const allocator = s.allocator();
    try cv.load(s.db, allocator);

    var outer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both, .background = true });
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
            }
            if (dvui.buttonIcon(@src(), "Delete Case", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .style = .err })) {
                dvui.dialog(@src(), .{ .s = s, .case_id = cv.case_id }, .{
                    .title = "Delete Case?",
                    .message = "This case will be deleted.",
                    .ok_label = "Delete",
                    .cancel_label = "Cancel",
                    .default = .cancel,
                    .callafterFn = deleteCase,
                });
            }
        }

        if (cv.rename_dialog) {
            var te = dvui.textEntry(@src(), .{ .text_initial = cv.case_name }, .{ .expand = .horizontal });
            const new_name = te.textGet();
            const enter = te.enter_pressed;
            te.deinit();

            if (enter or dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .style = .highlight, .expand = .horizontal })) {
                if (new_name.len > 0) {
                    s.db.renameCase(cv.case_id, new_name) catch |err| {
                        std.log.err("Rename case failed: {}", .{err});
                    };
                    const duped = try allocator.dupe(u8, new_name);
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

        {
            var tabs = dvui.tabs(@src(), .{ .dir = .vertical, .draw_focus = false }, .{ .expand = .both, .gravity_y = 0 });
            defer tabs.deinit();

            const tab_entries = [_]struct { tab: state.CaseViewState.Tab, label: []const u8 }{
                .{ .tab = .people, .label = "People" },
                .{ .tab = .notes, .label = "Notes" },
                .{ .tab = .timeline, .label = "Timeline" },
            };

            for (tab_entries) |entry| {
                var tab = tabs.addTab(cv.tab == entry.tab, .{}, .{ .expand = .horizontal });
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

            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .{ .color = dvui.themeGet().color(.err, .fill) }, .gravity_y = 1 })) {
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

    var grid_query: []const u8 = "";
    {
        var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer btn_row.deinit();

        if (dvui.button(@src(), "Import", .{ .draw_focus = false }, .{})) {
            cv.import_person_dialog = !cv.import_person_dialog;
            cv.new_person_dialog = false;
        }

        var search = dvui.textEntry(@src(), .{ .placeholder = "Search..." }, .{ .gravity_x = 0.5 });
        grid_query = search.textGet();
        search.deinit();

        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .style = .highlight, .gravity_x = 1 })) {
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

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .style = .highlight }) or enter) {
            if (name.len > 0) {
                const id = s.db.createPersonInCase(name, cv.case_id) catch |err| {
                    std.log.err("Create person in case failed: {}", .{err});
                    return;
                };
                const duped = try allocator.dupe(u8, name);
                var new_person = types.PersonEntry{ .id = id, .name = duped };
                new_person.computeInitials();
                try cv.people.append(allocator, new_person);
                try s.people.append(allocator, new_person);
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

        var search = dvui.textEntry(@src(), .{ .placeholder = "Search..." }, .{ .expand = .horizontal });
        const query = search.textGet();
        search.deinit();

        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        for (s.people.items, 0..) |person, i| {
            const in_case = for (cv.people.items) |cp| {
                if (cp.id == person.id) break true;
            } else false;
            if (in_case) continue;
            if (!widgets.matches(person.name, query)) continue;

            if (dvui.button(@src(), person.name, .{ .draw_focus = false }, .{
                .id_extra = i,
                .expand = .horizontal,
            })) {
                s.db.linkPersonToCase(person.id, cv.case_id) catch |err| {
                    std.log.err("Link person to case failed: {}", .{err});
                    continue;
                };
                try cv.people.append(allocator, person);
            }
        }
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    var flex = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal });
    defer flex.deinit();

    for (cv.people.items, 0..) |person, i| {
        if (!widgets.matches(person.name, grid_query)) continue;

        var card = dvui.box(@src(), .{ .dir = .vertical }, .{
            .id_extra = i,
            .min_size_content = .{ .w = CARD_W_PEOPLE },
        });
        defer card.deinit();

        if (dvui.button(@src(), person.initials[0..person.initials_len], .{ .draw_focus = false }, .{
            .gravity_x = 0.5,
            .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE },
            .corners = .all(AVATAR_SIZE),
            .color_fill = person.color.fill(),
        })) {
            cv.person_view = state.PersonViewState.init(person, cv.case_id);
        }

        dvui.labelNoFmt(@src(), person.name, .{}, .{
            .gravity_x = 0.5,
            .max_size_content = .width(CARD_W_PEOPLE - 8.0),
        });
    }
}

// Delete Case Dialog
fn deleteCase(id: dvui.Id, response: dvui.enums.DialogResponse) !void {
    if (response != .ok) return;
    const s = dvui.dataGet(null, id, "s", *state.ProjectViewState) orelse return;
    const case_id = dvui.dataGet(null, id, "case_id", i64) orelse return;

    s.db.deleteCase(case_id) catch |err| {
        std.log.err("Delete case failed: {}", .{err});
        return;
    };
    for (s.cases.items, 0..) |c, ci| {
        if (c.id == case_id) {
            _ = s.cases.orderedRemove(ci);
            break;
        }
    }
    s.case_view = null;
    s.notes.reload(s.db, s.allocator());
}

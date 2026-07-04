const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");
const person_view = @import("person_view.zig");
const timeline = @import("timeline.zig");

const MIN_CARD_WIDTH_PEOPLE: f32 = 100;
const MIN_CARD_WIDTH_NOTES: f32 = 180;
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
                    .notes => dvui.label(@src(), "Notes ({d})", .{cv.notes.items.len}, .{}),
                    else => dvui.labelNoFmt(@src(), entry.label, .{}, .{}),
                }
                if (tab.clicked()) {
                    cv.tab = entry.tab;
                    cv.person_view = null;
                }
            }

            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
                s.db.updateCaseAccess(cv.case_id) catch {};
                s.case_view = null;
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
            .people => if (cv.person_view != null)
                try person_view.render(s, &cv.person_view)
            else
                try renderPeople(s, cv),
            .notes => try renderNotes(s, cv),
            .timeline => try timeline.render(s, cv),
        }
    }
}

fn renderPeople(s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    const allocator = s.allocator();

    {
        var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer btn_row.deinit();

        if (dvui.button(@src(), "Import", .{ .draw_focus = false }, .{})) {
            cv.import_person_dialog = !cv.import_person_dialog;
            cv.new_person_dialog = false;
        }

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

        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        var any = false;
        for (s.people.items, 0..) |person, i| {
            const in_case = for (cv.people.items) |cp| {
                if (cp.id == person.id) break true;
            } else false;
            if (in_case) continue;
            any = true;

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

        if (!any) {
            dvui.label(@src(), "No people to import", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 });
        }
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH_PEOPLE);

    var i: usize = 0;
    var row_idx: usize = 0;
    while (i < cv.people.items.len) : (row_idx += 1) {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .id_extra = row_idx,
            .expand = .horizontal,
        });
        defer row.deinit();

        var c: usize = 0;
        while (c < cols and i < cv.people.items.len) : ({
            c += 1;
            i += 1;
        }) {
            const person = cv.people.items[i];
            const idx = i;

            var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = idx,
                .expand = .horizontal,
            });
            defer card.deinit();

            const avatar = person.initials[0..person.initials_len];

            if (dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .id_extra = idx, .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = dvui.CornerRect.round(AVATAR_SIZE) })) {
                cv.person_view = .{
                    .person_id = person.id,
                    .person_name = person.name,
                    .person_initials = person.initials,
                    .person_initials_len = person.initials_len,
                };
            }

            dvui.labelNoFmt(@src(), person.name, .{}, .{
                .id_extra = idx,
                .gravity_x = 0.5,
            });
        }
        while (c < cols) : (c += 1) {
            var spacer = dvui.box(@src(), .{}, .{ .id_extra = c, .expand = .horizontal });
            defer spacer.deinit();
        }
    }
}

fn renderNotes(s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    const allocator = s.allocator();

    if (dvui.buttonIcon(@src(), "New Note", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
        cv.new_note_dialog = !cv.new_note_dialog;
    }

    if (cv.new_note_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            cv.new_note_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (title.len > 0) {
                const id = s.db.createNoteForCase(title, cv.case_id) catch |err| {
                    std.log.err("Create note for case failed: {}", .{err});
                    return;
                };
                const duped_title = allocator.dupe(u8, title) catch unreachable;
                const duped_content = allocator.dupe(u8, "") catch unreachable;
                cv.notes.insert(allocator, 0, .{
                    .id = id,
                    .title = duped_title,
                    .content = duped_content,
                }) catch unreachable;
                cv.new_note_dialog = false;
                cv.open_note_id = id;
            }
        }
    }

    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH_NOTES);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < cv.notes.items.len) : (row_idx += 1) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < cv.notes.items.len) : ({
                c += 1;
                i += 1;
            }) {
                var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                });
                defer card.deinit();

                if (dvui.button(@src(), cv.notes.items[i].title, .{ .draw_focus = false }, .{ .id_extra = i, .expand = .horizontal, .min_size_content = .{ .w = 140, .h = 80 }, .corners = dvui.CornerRect.round(3) })) {
                    cv.open_note_id = cv.notes.items[i].id;
                }
            }
            while (c < cols) : (c += 1) {
                var spacer = dvui.box(@src(), .{}, .{ .id_extra = c, .expand = .horizontal });
                defer spacer.deinit();
            }
        }
    }

    if (cv.open_note_id) |note_id| {
        const note_idx = for (cv.notes.items, 0..) |n, idx| {
            if (n.id == note_id) break idx;
        } else null;

        if (note_idx) |idx| {
            var show = true;
            var fw = dvui.floatingWindow(@src(), .{}, .{
                .min_size_content = .{ .w = 400, .h = 300 },
                .max_size_content = .{ .w = 600, .h = 500 },
            });
            defer fw.deinit();

            fw.dragAreaSet(dvui.windowHeader("Edit Note", "", &show));

            if (!show) {
                const note = cv.notes.items[idx];
                s.db.updateNoteTitle(note.id, note.title) catch |err| {
                    std.log.err("Save note title failed: {}", .{err});
                };
                s.db.updateNoteContent(note.id, note.content) catch |err| {
                    std.log.err("Save note failed: {}", .{err});
                };
                cv.open_note_id = null;
                return;
            }

            // Title + delete
            {
                var top_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer top_row.deinit();

                {
                    var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                    defer te.deinit();
                    widgets.syncText(te, &cv.notes.items[idx].title, allocator);
                }

                if (dvui.buttonIcon(@src(), "Delete Note", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red, .gravity_y = 0.5 })) {
                    const note = cv.notes.items[idx];
                    s.db.deleteNote(note.id) catch |err| {
                        std.log.err("Delete note failed: {}", .{err});
                        return;
                    };
                    _ = cv.notes.orderedRemove(idx);
                    cv.open_note_id = null;
                    return;
                }
            }

            // Content
            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 380, .h = 250 },
                });
                defer te.deinit();
                widgets.syncText(te, &cv.notes.items[idx].content, allocator);
            }
        } else {
            cv.open_note_id = null;
        }
    }
}

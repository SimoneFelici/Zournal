const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const types = @import("../types.zig");
const grid = @import("../ui/grid.zig");
const people_page = @import("people.zig");

const MIN_CARD_WIDTH_PEOPLE: f32 = 100;
const MIN_CARD_WIDTH_NOTES: f32 = 180;
const AVATAR_SIZE: f32 = 60;

pub fn render(ctx: *AppContext, page: *state.PageState) !void {
    var s = &page.project_view;
    var cv = &s.case_view.?;

    try cv.load(s.db, ctx.allocator);

    var outer = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
    defer outer.deinit();

    // Sidebar
    {
        var sidebar = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .vertical });
        defer sidebar.deinit();

        dvui.label(@src(), "{s}", .{cv.case_name}, .{ .expand = .horizontal, .gravity_x = 0.5 });

        {
            var tabs = dvui.tabs(@src(), .{ .dir = .vertical, .draw_focus = false }, .{ .expand = .both, .gravity_y = 0 });
            defer tabs.deinit();

            const tab_entries = [_]struct { tab: state.CaseViewState.Tab, label: []const u8 }{
                .{ .tab = .people, .label = "People" },
                .{ .tab = .notes, .label = "Notes" },
                .{ .tab = .timeline, .label = "Timeline" },
            };

            for (tab_entries) |entry| {
                var tab = tabs.addTab(cv.tab == entry.tab, .{ .expand = .horizontal });
                defer tab.deinit();
                switch (entry.tab) {
                    .people => dvui.label(@src(), "People ({d})", .{cv.people.items.len}, .{}),
                    .notes => dvui.label(@src(), "Notes ({d})", .{cv.notes.items.len}, .{}),
                    else => dvui.labelNoFmt(@src(), entry.label, .{}, .{}),
                }
                if (tab.clicked()) cv.tab = entry.tab;
            }

            if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .expand = .horizontal, .color_fill_hover = .red, .gravity_y = 1 })) {
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
            .people => try renderPeople(ctx, s, cv),
            .notes => try renderNotes(ctx, s, cv),
            .timeline => dvui.label(@src(), "Timeline", .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 }),
        }
    }
}

fn renderPeople(ctx: *AppContext, s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    const allocator = ctx.allocator;

    if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
        cv.new_person_dialog = !cv.new_person_dialog;
    }

    if (cv.new_person_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const name = te.textGet();
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            cv.new_person_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue })) {
            if (name.len > 0) {
                const id = s.db.createPersonInCase(name, cv.case_id) catch |err| {
                    std.log.err("Create person in case failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, name) catch unreachable;
                var new_person = types.PersonEntry{ .id = id, .name = duped };
                people_page.computeInitials(&new_person);
                cv.people.append(allocator, new_person) catch unreachable;
                s.people.append(allocator, new_person) catch unreachable;
                cv.new_person_dialog = false;
            }
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

            if (dvui.button(@src(), avatar, .{ .draw_focus = false }, .{
                .id_extra = idx,
                .gravity_x = 0.5,
                .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE },
                .corner_radius = dvui.Rect.all(AVATAR_SIZE),
            })) {
                std.log.info("Selected person: {s}", .{person.name});
            }

            dvui.labelNoFmt(@src(), person.name, .{}, .{
                .id_extra = idx,
                .gravity_x = 0.5,
            });
        }
    }
}

fn renderNotes(ctx: *AppContext, s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    const allocator = ctx.allocator;

    if (dvui.buttonIcon(@src(), "New Note", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
        cv.new_note_dialog = !cv.new_note_dialog;
    }

    if (cv.new_note_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            cv.new_note_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue })) {
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

                if (dvui.button(@src(), cv.notes.items[i].title, .{ .draw_focus = false }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                    .min_size_content = .{ .w = 140, .h = 80 },
                    .corner_radius = dvui.Rect.all(3),
                })) {
                    cv.open_note_id = cv.notes.items[i].id;
                }
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

            fw.dragAreaSet(dvui.windowHeader(cv.notes.items[idx].title, "", &show));

            if (!show) {
                const note = cv.notes.items[idx];
                s.db.updateNoteContent(note.id, note.content) catch |err| {
                    std.log.err("Save note failed: {}", .{err});
                };
                cv.open_note_id = null;
                return;
            }

            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 380, .h = 250 },
                });
                defer te.deinit();

                const current = te.textGet();
                if (current.len == 0 and cv.notes.items[idx].content.len > 0) {
                    te.textSet(cv.notes.items[idx].content, false);
                }

                const text = te.textGet();
                if (text.len > 0 or cv.notes.items[idx].content.len > 0) {
                    if (!std.mem.eql(u8, text, cv.notes.items[idx].content)) {
                        const duped = allocator.dupe(u8, text) catch unreachable;
                        cv.notes.items[idx].content = duped;
                    }
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 0 })) {
                    const note = cv.notes.items[idx];
                    s.db.updateNoteContent(note.id, note.content) catch |err| {
                        std.log.err("Save note failed: {}", .{err});
                    };
                }

                if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                    const note = cv.notes.items[idx];
                    s.db.deleteNote(note.id) catch |err| {
                        std.log.err("Delete note failed: {}", .{err});
                        return;
                    };
                    _ = cv.notes.orderedRemove(idx);
                    cv.open_note_id = null;
                }
            }
        } else {
            cv.open_note_id = null;
        }
    }
}

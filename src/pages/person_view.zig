const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const db_utils = @import("../db_utils.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");

const AVATAR_SIZE: f32 = 80;
const MIN_CARD_WIDTH: f32 = 180;

fn syncPersonName(s: *state.ProjectViewState, person_id: i64, name: []const u8) void {
    for (s.people.items) |*p| {
        if (p.id == person_id) {
            p.name = name;
            p.computeInitials();
        }
    }
    if (s.case_view) |*cv| {
        for (cv.people.items) |*p| {
            if (p.id == person_id) {
                p.name = name;
                p.computeInitials();
            }
        }
    }
}

fn removePersonFromState(s: *state.ProjectViewState, person_id: i64) void {
    var i: usize = 0;
    while (i < s.people.items.len) {
        if (s.people.items[i].id == person_id) {
            _ = s.people.orderedRemove(i);
        } else i += 1;
    }

    if (s.case_view) |*cv| {
        i = 0;
        while (i < cv.people.items.len) {
            if (cv.people.items[i].id == person_id) {
                _ = cv.people.orderedRemove(i);
            } else i += 1;
        }
    }

    var r = &s.relationships;
    i = 0;
    while (i < r.relationships.items.len) {
        const rel = r.relationships.items[i];
        if (rel.person_a_id == person_id or rel.person_b_id == person_id) {
            _ = r.relationships.orderedRemove(i);
        } else i += 1;
    }
    i = 0;
    while (i < r.positions.items.len) {
        if (r.positions.items[i].person_id == person_id) {
            _ = r.positions.orderedRemove(i);
        } else i += 1;
    }
    if (r.selected_id != null and r.selected_id.? == person_id) r.selected_id = null;
    if (r.connect_target_id != null and r.connect_target_id.? == person_id) r.connect_target_id = null;
    if (r.dragging_id != null and r.dragging_id.? == person_id) r.dragging_id = null;
}

pub fn render(s: *state.ProjectViewState, person_view: *?state.PersonViewState) !void {
    var pv = &person_view.*.?;
    const db = s.db;
    const allocator = s.allocator();

    try pv.load(db, allocator);

    // Top bar: back (left) + new note (right)
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .color_fill_hover = .red })) {
            person_view.* = null;
            return;
        }

        if (dvui.buttonIcon(@src(), "New Note", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            pv.new_note_dialog = !pv.new_note_dialog;
        }
    }

    if (pv.new_note_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            pv.new_note_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (title.len > 0) {
                const id = db.createPersonNote(pv.person_id, title) catch |err| {
                    std.log.err("Create person note failed: {}", .{err});
                    return;
                };
                const duped_title = allocator.dupe(u8, title) catch unreachable;
                const duped_content = allocator.dupe(u8, "") catch unreachable;
                pv.notes.insert(allocator, 0, .{
                    .id = id,
                    .title = duped_title,
                    .content = duped_content,
                }) catch unreachable;
                pv.new_note_dialog = false;
                pv.open_note_id = id;
            }
        }
    }

    // Avatar
    {
        const avatar = pv.person_initials[0..pv.person_initials_len];
        _ = dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = dvui.CornerRect.round(AVATAR_SIZE) });

        var name_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5 });
        defer name_row.deinit();

        dvui.labelNoFmt(@src(), pv.person_name, .{}, .{ .gravity_y = 0.5 });

        if (dvui.buttonIcon(@src(), "Edit Name", dvui.entypo.edit, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5 })) {
            pv.edit_name_dialog = !pv.edit_name_dialog;
            pv.delete_person_confirm = false;
        }

        if (dvui.buttonIcon(@src(), "Delete Person", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5, .color_fill = .red })) {
            pv.delete_person_confirm = !pv.delete_person_confirm;
            pv.edit_name_dialog = false;
        }
    }

    // Rename person dialog
    if (pv.edit_name_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const current = te.textGet();
        if (current.len == 0 and pv.person_name.len > 0 and dvui.focusedWidgetId() != te.data().id) {
            te.textSet(pv.person_name, false);
        }
        const new_name = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            pv.edit_name_dialog = false;
        }

        if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (new_name.len > 0) {
                db.updatePerson(pv.person_id, new_name) catch |err| {
                    std.log.err("Update person failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, new_name) catch unreachable;
                pv.person_name = duped;

                var tmp = types.PersonEntry{ .id = pv.person_id, .name = duped };
                tmp.computeInitials();
                pv.person_initials = tmp.initials;
                pv.person_initials_len = tmp.initials_len;

                syncPersonName(s, pv.person_id, duped);
                pv.edit_name_dialog = false;
            }
        }
    }

    // Delete person dialog
    if (pv.delete_person_confirm) {
        var confirm_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5 });
        defer confirm_box.deinit();

        dvui.labelNoFmt(@src(), "Delete this person and all their notes?", .{}, .{ .gravity_y = 0.5 });

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            pv.delete_person_confirm = false;
        }

        if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill = .red })) {
            const person_id = pv.person_id;
            db.deletePerson(person_id) catch |err| {
                std.log.err("Delete person failed: {}", .{err});
                return;
            };
            removePersonFromState(s, person_id);
            person_view.* = null;
            return;
        }
    }

    // Notes grid
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < pv.notes.items.len) : (row_idx += 1) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < pv.notes.items.len) : ({
                c += 1;
                i += 1;
            }) {
                var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                });
                defer card.deinit();

                if (dvui.button(@src(), pv.notes.items[i].title, .{ .draw_focus = false }, .{ .id_extra = i, .expand = .horizontal, .min_size_content = .{ .w = 140, .h = 80 }, .corners = dvui.CornerRect.round(3) })) {
                    pv.open_note_id = pv.notes.items[i].id;
                }
            }
            while (c < cols) : (c += 1) {
                var spacer = dvui.box(@src(), .{}, .{ .id_extra = c, .expand = .horizontal });
                defer spacer.deinit();
            }
        }
    }

    if (pv.open_note_id) |note_id| {
        const note_idx = for (pv.notes.items, 0..) |n, idx| {
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
                db.updatePersonNoteTitle(note_id, pv.notes.items[idx].title) catch |err| {
                    std.log.err("Save person note title failed: {}", .{err});
                };
                db.updatePersonNoteContent(note_id, pv.notes.items[idx].content) catch |err| {
                    std.log.err("Save person note failed: {}", .{err});
                };
                pv.open_note_id = null;
                return;
            }

            // Title + delete
            {
                var top_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer top_row.deinit();

                {
                    var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                    defer te.deinit();
                    widgets.syncText(te, &pv.notes.items[idx].title, allocator);
                }

                if (dvui.buttonIcon(@src(), "Delete Note", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red, .gravity_y = 0.5 })) {
                    db.deletePersonNote(note_id) catch |err| {
                        std.log.err("Delete person note failed: {}", .{err});
                        return;
                    };
                    _ = pv.notes.orderedRemove(idx);
                    pv.open_note_id = null;
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
                widgets.syncText(te, &pv.notes.items[idx].content, allocator);
            }
        } else {
            pv.open_note_id = null;
        }
    }
}

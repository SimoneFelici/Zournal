const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const db_utils = @import("../db_utils.zig");
const grid = @import("../ui/grid.zig");

const AVATAR_SIZE: f32 = 80;
const MIN_CARD_WIDTH: f32 = 180;

pub fn render(db: db_utils.Database, person_view: *?state.PersonViewState, allocator: std.mem.Allocator) !void {
    var pv = &person_view.*.?;

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

    // Avatar + name centered
    {
        const avatar = pv.person_initials[0..pv.person_initials_len];
        _ = dvui.button(@src(), avatar, .{ .draw_focus = false }, .{
            .gravity_x = 0.5,
            .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE },
            .corner_radius = dvui.Rect.all(AVATAR_SIZE),
        });
        dvui.labelNoFmt(@src(), pv.person_name, .{}, .{ .gravity_x = 0.5 });
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

                if (dvui.button(@src(), pv.notes.items[i].title, .{ .draw_focus = false }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                    .min_size_content = .{ .w = 140, .h = 80 },
                    .corner_radius = dvui.Rect.all(3),
                })) {
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

            fw.dragAreaSet(dvui.windowHeader(pv.notes.items[idx].title, "", &show));

            if (!show) {
                db.updatePersonNoteContent(note_id, pv.notes.items[idx].content) catch |err| {
                    std.log.err("Save person note failed: {}", .{err});
                };
                pv.open_note_id = null;
                return;
            }

            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 380, .h = 250 },
                });
                defer te.deinit();

                const current = te.textGet();
                if (current.len == 0 and pv.notes.items[idx].content.len > 0 and dvui.focusedWidgetId() != te.data().id) {
                    te.textSet(pv.notes.items[idx].content, false);
                }

                const text = te.textGet();
                if (text.len > 0 or pv.notes.items[idx].content.len > 0) {
                    if (!std.mem.eql(u8, text, pv.notes.items[idx].content)) {
                        const duped = allocator.dupe(u8, text) catch unreachable;
                        pv.notes.items[idx].content = duped;
                    }
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 0 })) {
                    db.updatePersonNoteContent(note_id, pv.notes.items[idx].content) catch |err| {
                        std.log.err("Save person note failed: {}", .{err});
                    };
                }

                if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                    db.deletePersonNote(note_id) catch |err| {
                        std.log.err("Delete person note failed: {}", .{err});
                        return;
                    };
                    _ = pv.notes.orderedRemove(idx);
                    pv.open_note_id = null;
                }
            }
        } else {
            pv.open_note_id = null;
        }
    }
}

const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const grid = @import("../ui/grid.zig");

const MIN_CARD_WIDTH: f32 = 180;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    {
        if (dvui.buttonIcon(@src(), "New Note", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            s.new_note_dialog = !s.new_note_dialog;
        }
    }

    if (s.new_note_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            s.new_note_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (title.len > 0) {
                const id = s.db.createNote(title) catch |err| {
                    std.log.err("Create note failed: {}", .{err});
                    return;
                };
                const duped_title = allocator.dupe(u8, title) catch unreachable;
                const duped_content = allocator.dupe(u8, "") catch unreachable;
                s.notes.insert(allocator, 0, .{
                    .id = id,
                    .title = duped_title,
                    .content = duped_content,
                }) catch unreachable;
                s.new_note_dialog = false;
                s.open_note_id = id;
            }
        }
    }

    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < s.notes.items.len) : (row_idx += 1) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.notes.items.len) : ({
                c += 1;
                i += 1;
            }) {
                const note = s.notes.items[i];

                {
                    var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                        .id_extra = i,
                        .expand = .horizontal,
                    });
                    defer card.deinit();

                    if (dvui.button(@src(), note.title, .{ .draw_focus = false }, .{
                        .id_extra = i,
                        .expand = .horizontal,
                        .min_size_content = .{ .w = 140, .h = 80 },
                        .corner_radius = dvui.Rect.all(3),
                    })) {
                        s.open_note_id = note.id;
                    }
                }
            }
            while (c < cols) : (c += 1) {
                var spacer = dvui.box(@src(), .{}, .{ .id_extra = c, .expand = .horizontal });
                defer spacer.deinit();
            }
        }
    }

    if (s.open_note_id) |note_id| {
        const note_idx = for (s.notes.items, 0..) |n, idx| {
            if (n.id == note_id) break idx;
        } else null;

        if (note_idx) |idx| {
            var show = true;
            var fw = dvui.floatingWindow(@src(), .{}, .{
                .min_size_content = .{ .w = 400, .h = 300 },
                .max_size_content = .{ .w = 600, .h = 500 },
            });
            defer fw.deinit();

            fw.dragAreaSet(dvui.windowHeader(s.notes.items[idx].title, "", &show));

            if (!show) {
                const note = s.notes.items[idx];
                s.db.updateNoteContent(note.id, note.content) catch |err| {
                    std.log.err("Save note failed: {}", .{err});
                };
                s.open_note_id = null;
                return;
            }

            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 380, .h = 250 },
                });
                defer te.deinit();

                const current = te.textGet();
                if (current.len == 0 and s.notes.items[idx].content.len > 0 and dvui.focusedWidgetId() != te.data().id) {
                    te.textSet(s.notes.items[idx].content, false);
                }

                const text = te.textGet();
                if (text.len > 0 or s.notes.items[idx].content.len > 0) {
                    if (!std.mem.eql(u8, text, s.notes.items[idx].content)) {
                        const duped = allocator.dupe(u8, text) catch unreachable;
                        s.notes.items[idx].content = duped;
                    }
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .horizontal,
                });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 0 })) {
                    const note = s.notes.items[idx];
                    s.db.updateNoteContent(note.id, note.content) catch |err| {
                        std.log.err("Save note failed: {}", .{err});
                    };
                }

                if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                    const note = s.notes.items[idx];
                    s.db.deleteNote(note.id) catch |err| {
                        std.log.err("Delete note failed: {}", .{err});
                        return;
                    };
                    _ = s.notes.orderedRemove(idx);
                    s.open_note_id = null;
                }
            }
        } else {
            s.open_note_id = null;
        }
    }
}

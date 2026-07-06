const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");

const CARD_W: f32 = 200;
const CARD_H: f32 = 80;
const CARD_SLOT: f32 = CARD_W + 24;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    var search_open = false;
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        search_open = widgets.searchToggle(@src());

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
                s.open_notes.append(allocator, id) catch unreachable;
            }
        }
    }

    const query: []const u8 = if (search_open) widgets.searchEntry(@src()) else "";

    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, CARD_SLOT);

        var i: usize = 0;
        var row_idx: usize = 0;
        var shown: usize = 0;
        while (i < s.notes.items.len) : (row_idx += 1) {
            while (i < s.notes.items.len and !widgets.matches(s.notes.items[i].title, query)) i += 1;
            if (i >= s.notes.items.len) break;
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.notes.items.len) : (i += 1) {
                const note = s.notes.items[i];
                if (!widgets.matches(note.title, query)) continue;
                c += 1;
                shown += 1;

                {
                    var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                        .id_extra = i,
                    });
                    defer card.deinit();

                    if (dvui.button(@src(), widgets.fitText(note.title, CARD_W - 16), .{ .draw_focus = false }, .{ .id_extra = i, .min_size_content = .{ .w = CARD_W, .h = CARD_H }, .corners = dvui.CornerRect.round(3) })) {
                        const nid = note.id;
                        const already = for (s.open_notes.items) |oid| {
                            if (oid == nid) break true;
                        } else false;
                        if (!already) s.open_notes.append(allocator, nid) catch unreachable;
                    }
                }
            }
        }
    }

    var oi: usize = 0;
    while (oi < s.open_notes.items.len) {
        const note_id = s.open_notes.items[oi];
        const note_idx = for (s.notes.items, 0..) |n, idx| {
            if (n.id == note_id) break idx;
        } else null;

        if (note_idx) |idx| {
            var show = true;
            var fw = dvui.floatingWindow(@src(), .{}, .{
                .id_extra = @as(usize, @intCast(note_id)),
                .min_size_content = .{ .w = 400, .h = 300 },
                .max_size_content = .{ .w = 600, .h = 500 },
            });
            defer fw.deinit();

            fw.dragAreaSet(dvui.windowHeader("Edit Note", "", &show));

            if (!show) {
                const note = s.notes.items[idx];
                s.db.updateNoteTitle(note.id, note.title) catch |err| {
                    std.log.err("Save note title failed: {}", .{err});
                };
                s.db.updateNoteContent(note.id, note.content) catch |err| {
                    std.log.err("Save note failed: {}", .{err});
                };
                _ = s.open_notes.orderedRemove(oi);
                continue;
            }

            // Title + delete
            {
                var top_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer top_row.deinit();

                {
                    var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                    defer te.deinit();
                    widgets.syncText(te, &s.notes.items[idx].title, allocator);
                }

                if (dvui.buttonIcon(@src(), "Delete Note", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red, .gravity_y = 0.5 })) {
                    s.db.deleteNote(note_id) catch |err| {
                        std.log.err("Delete note failed: {}", .{err});
                        return;
                    };
                    _ = s.notes.orderedRemove(idx);
                    _ = s.open_notes.orderedRemove(oi);
                    continue;
                }
            }

            // Content
            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 380, .h = 250 },
                });
                defer te.deinit();
                widgets.syncText(te, &s.notes.items[idx].content, allocator);
            }
            oi += 1;
        } else {
            _ = s.open_notes.orderedRemove(oi);
        }
    }
}

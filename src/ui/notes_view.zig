const std = @import("std");
const dvui = @import("dvui");
const types = @import("../types.zig");
const db_utils = @import("../db_utils.zig");
const grid = @import("grid.zig");
const widgets = @import("widgets.zig");

pub const NoteScope = db_utils.NoteScope;

const CARD_W: f32 = 200;
const CARD_H: f32 = 80;
const CARD_SLOT: f32 = CARD_W + 24;

pub const NotesState = struct {
    scope: NoteScope,

    notes: std.ArrayList(types.NoteEntry) = .empty,
    open_notes: std.ArrayList(i64) = .empty,
    new_note_dialog: bool = false,
    loaded: bool = false,

    pub fn load(self: *NotesState, db: db_utils.Database, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.notes = try db.listNotes(self.scope, allocator);
        self.loaded = true;
    }

    pub fn flushOpen(self: *NotesState, db: db_utils.Database) void {
        for (self.open_notes.items) |note_id| {
            for (self.notes.items) |n| {
                if (n.id != note_id) continue;
                db.saveNote(n.id, n.title, n.content) catch |err| {
                    std.log.err("Save note {d} failed: {}", .{ n.id, err });
                };
                break;
            }
        }
    }

    pub fn reload(self: *NotesState, db: db_utils.Database, allocator: std.mem.Allocator) void {
        self.flushOpen(db);
        self.notes = db.listNotes(self.scope, allocator) catch |err| {
            std.log.err("Reload notes failed: {}", .{err});
            return;
        };
        self.open_notes.clearRetainingCapacity();
        self.loaded = true;
    }

    fn scopeCaseId(self: *const NotesState) ?i64 {
        return switch (self.scope) {
            .case => |id| id,
            .person => |p| p.case_id,
            .project => null,
        };
    }

    fn openNote(self: *NotesState, allocator: std.mem.Allocator, note_id: i64) void {
        for (self.open_notes.items) |oid| {
            if (oid == note_id) return;
        }
        self.open_notes.append(allocator, note_id) catch unreachable;
    }
};

pub fn render(
    ns: *NotesState,
    db: db_utils.Database,
    allocator: std.mem.Allocator,
) !void {
    try ns.load(db, allocator);

    var search_open = false;
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        search_open = widgets.searchToggle(@src());

        if (dvui.buttonIcon(@src(), "New Note", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            ns.new_note_dialog = !ns.new_note_dialog;
        }
    }

    if (ns.new_note_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            ns.new_note_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (title.len > 0) {
                const id = db.createNote(ns.scope, title) catch |err| {
                    std.log.err("Create note failed: {}", .{err});
                    return;
                };
                const duped_title = allocator.dupe(u8, title) catch unreachable;
                const duped_content = allocator.dupe(u8, "") catch unreachable;
                ns.notes.insert(allocator, 0, .{
                    .id = id,
                    .case_id = ns.scopeCaseId(),
                    .title = duped_title,
                    .content = duped_content,
                }) catch unreachable;
                ns.new_note_dialog = false;
                ns.openNote(allocator, id);
            }
        }
    }

    const query: []const u8 = if (search_open) widgets.searchEntry(@src()) else "";

    // Notes grid
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, CARD_SLOT);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < ns.notes.items.len) : (row_idx += 1) {
            while (i < ns.notes.items.len and !widgets.matches(ns.notes.items[i].title, query)) i += 1;
            if (i >= ns.notes.items.len) break;
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < ns.notes.items.len) : (i += 1) {
                const note = ns.notes.items[i];
                if (!widgets.matches(note.title, query)) continue;
                c += 1;

                const key: usize = @intCast(note.id);

                var card = dvui.box(@src(), .{ .dir = .vertical }, .{ .id_extra = key });
                defer card.deinit();

                if (dvui.button(@src(), widgets.fitText(note.title, CARD_W - 16), .{ .draw_focus = false }, .{ .id_extra = key, .min_size_content = .{ .w = CARD_W, .h = CARD_H }, .corners = dvui.CornerRect.round(3) })) {
                    ns.openNote(allocator, note.id);
                }
            }
        }
    }

    // Edit windows
    var oi: usize = 0;
    while (oi < ns.open_notes.items.len) {
        const note_id = ns.open_notes.items[oi];
        const note_idx = for (ns.notes.items, 0..) |n, idx| {
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
                db.saveNote(note_id, ns.notes.items[idx].title, ns.notes.items[idx].content) catch |err| {
                    std.log.err("Save note failed: {}", .{err});
                };
                _ = ns.open_notes.orderedRemove(oi);
                continue;
            }

            // Title + delete
            {
                var top_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer top_row.deinit();

                {
                    var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                    defer te.deinit();
                    widgets.syncText(te, &ns.notes.items[idx].title, allocator);
                }

                if (ns.scopeCaseId()) |scope_case| {
                    const is_global = ns.notes.items[idx].case_id == null;
                    const label = if (is_global) "Global" else "Local";
                    if (dvui.button(@src(), label, .{ .draw_focus = false }, .{ .gravity_y = 0.5 })) {
                        const target: ?i64 = if (is_global) scope_case else null;
                        if (db.setNoteCase(note_id, target)) {
                            ns.notes.items[idx].case_id = target;
                        } else |err| {
                            std.log.err("Set note case failed: {}", .{err});
                        }
                    }
                }

                if (dvui.buttonIcon(@src(), "Delete Note", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red, .gravity_y = 0.5 })) {
                    db.deleteNote(note_id) catch |err| {
                        std.log.err("Delete note failed: {}", .{err});
                        return;
                    };
                    _ = ns.notes.orderedRemove(idx);
                    _ = ns.open_notes.orderedRemove(oi);
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
                widgets.syncText(te, &ns.notes.items[idx].content, allocator);
            }
            oi += 1;
        } else {
            _ = ns.open_notes.orderedRemove(oi);
        }
    }
}

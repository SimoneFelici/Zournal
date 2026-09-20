const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const notes_view = @import("../ui/notes_view.zig");

const AVATAR_SIZE: f32 = 80;

fn findPerson(list: []types.PersonEntry, person_id: i64) ?*types.PersonEntry {
    for (list) |*p| {
        if (p.id == person_id) return p;
    }
    return null;
}

fn syncPersonName(s: *state.ProjectViewState, person_id: i64, name: []const u8) void {
    if (findPerson(s.people.items, person_id)) |p| {
        p.name = name;
        p.computeInitials();
    }
    if (s.case_view) |*cv| {
        if (findPerson(cv.people.items, person_id)) |p| {
            p.name = name;
            p.computeInitials();
        }
    }
}

fn personColor(s: *state.ProjectViewState, person_id: i64) types.AvatarColor {
    const p = findPerson(s.people.items, person_id) orelse return .gray;
    return p.color;
}

fn syncPersonColor(s: *state.ProjectViewState, person_id: i64, color: types.AvatarColor) void {
    if (findPerson(s.people.items, person_id)) |p| p.color = color;
    if (s.case_view) |*cv| {
        if (findPerson(cv.people.items, person_id)) |p| p.color = color;
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

    // Top bar
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .color_fill_hover = .red })) {
            pv.notes.flushOpen(db);
            person_view.* = null;
            return;
        }
    }

    // Avatar + color + name + rename + delete
    {
        const avatar = pv.person_initials[0..pv.person_initials_len];
        const current_color = personColor(s, pv.person_id);

        _ = dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = dvui.CornerRect.round(AVATAR_SIZE), .color_fill = current_color.fill() });

        var name_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5 });
        defer name_row.deinit();

        var picked = current_color;
        var changed = false;

        {
            var dd: dvui.DropdownWidget = undefined;
            dd.init(@src(), .{
                .selected_index = @intFromEnum(picked),
                .label = @tagName(picked),
            }, .{ .gravity_y = 0.5 });
            defer dd.deinit();

            if (dd.dropped()) {
                inline for (@typeInfo(types.AvatarColor).@"enum".fields) |e| {
                    const c: types.AvatarColor = @field(types.AvatarColor, e.name);

                    var mi = dd.addChoice();
                    defer mi.deinit();

                    var sw = dvui.box(@src(), .{}, .{
                        .min_size_content = .{ .w = 70, .h = 15 },
                        .background = true,
                        .color_fill = c.fill(),
                        .expand = .both,
                    });
                    sw.deinit();

                    if (mi.activeRect()) |_| {
                        dd.close();
                        picked = c;
                        changed = true;
                    }
                }
            }
        }

        if (changed) {
            try db.updatePersonColor(pv.person_id, picked);
            syncPersonColor(s, pv.person_id, picked);
        }

        dvui.labelNoFmt(@src(), pv.person_name, .{}, .{ .gravity_y = 0.5 });
        // ... resto invariato

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

        dvui.labelNoFmt(@src(), "Delete this person?", .{}, .{ .gravity_y = 0.5 });

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
            pv.notes.flushOpen(db);
            person_view.* = null;
            return;
        }
    }

    try notes_view.render(&pv.notes, db, allocator);
}

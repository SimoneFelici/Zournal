const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const notes_view = @import("notes.zig");

const AVATAR_SIZE: f32 = 80;

fn colorDropdown(src: std.builtin.SourceLocation, current: types.AvatarColor, opts: dvui.Options) ?types.AvatarColor {
    var result: ?types.AvatarColor = null;

    var dd: dvui.DropdownWidget = undefined;
    dd.init(src, .{
        .selected_index = @backingInt(current),
        .label = @tagName(current),
    }, opts);
    defer dd.deinit();

    if (dd.dropped()) {
        for (std.enums.values(types.AvatarColor)) |c| {
            var mi = dd.addChoice();
            defer mi.deinit();

            var sw = dvui.box(@src(), .{}, .{
                .min_size_content = .{ .w = 70, .h = 15 },
                .background = true,
                .color_fill = c.fill(),
                .expand = .both,
            });
            sw.deinit();

            if (mi.activeRect() != null) {
                dd.close();
                result = c;
            }
        }
    }
    return result;
}

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
}

pub fn render(s: *state.ProjectViewState, person_view: *?state.PersonViewState) !void {
    var pv = &person_view.*.?;
    const person = findPerson(s.people.items, pv.person_id) orelse {
        person_view.* = null;
        return;
    };
    const db = s.db;
    const allocator = s.allocator();

    // Top bar
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        if (dvui.button(@src(), "Back", .{ .draw_focus = false }, .{ .color_fill_hover = .{ .color = dvui.themeGet().color(.err, .fill) } })) {
            pv.notes.flushOpen(db);
            person_view.* = null;
            return;
        }
    }

    // Avatar + color + name + rename + delete
    {
        const avatar = person.initials[0..person.initials_len];
        const current_color = person.color;

        _ = dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = .all(AVATAR_SIZE), .color_fill = current_color.fill() });

        var name_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .gravity_x = 0.5 });
        defer name_row.deinit();

        if (colorDropdown(@src(), current_color, .{ .gravity_y = 0.5 })) |c| {
            try db.updatePersonColor(pv.person_id, c);
            syncPersonColor(s, pv.person_id, c);
        }

        dvui.labelNoFmt(@src(), person.name, .{}, .{ .gravity_y = 0.5 });

        if (dvui.buttonIcon(@src(), "Edit Name", dvui.entypo.edit, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5 })) {
            pv.edit_name_dialog = !pv.edit_name_dialog;
        }

        if (dvui.buttonIcon(@src(), "Delete Person", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5, .style = .err })) {
            dvui.dialog(@src(), .{ .s = s, .pv = person_view, .person_id = pv.person_id }, .{
                .title = "Delete Person?",
                .message = "This person will be deleted.",
                .ok_label = "Delete",
                .cancel_label = "Cancel",
                .default = .cancel,
                .callafterFn = deletePerson,
            });
        }
    }

    // Rename person dialog
    if (pv.edit_name_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{ .text_initial = person.name }, .{ .expand = .horizontal });
        const new_name = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            pv.edit_name_dialog = false;
        }

        if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .style = .highlight }) or enter) {
            if (new_name.len > 0) {
                db.updatePerson(pv.person_id, new_name) catch |err| {
                    std.log.err("Update person failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, new_name) catch unreachable;
                syncPersonName(s, pv.person_id, duped);
                pv.edit_name_dialog = false;
            }
        }
    }

    try notes_view.render(&pv.notes, db, allocator);
}

// Delete Person Dialog
fn deletePerson(id: dvui.Id, response: dvui.enums.DialogResponse) !void {
    if (response != .ok) return;
    const s = dvui.dataGet(null, id, "s", *state.ProjectViewState) orelse return;
    const pv = dvui.dataGet(null, id, "pv", *?state.PersonViewState) orelse return;
    const person_id = dvui.dataGet(null, id, "person_id", i64) orelse return;

    s.db.deletePerson(person_id) catch |err| {
        std.log.err("Delete person failed: {}", .{err});
        return;
    };
    removePersonFromState(s, person_id);
    pv.* = null;

    s.notes.reload(s.db, s.allocator());
    if (s.case_view) |*cv| cv.notes.reload(s.db, s.allocator());
}

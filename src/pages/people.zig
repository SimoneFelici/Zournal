const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const types = @import("../types.zig");
const grid = @import("../ui/grid.zig");

const MIN_CARD_WIDTH: f32 = 100;
const AVATAR_SIZE: f32 = 60;

pub fn computeInitials(entry: *types.PersonEntry) void {
    var it = std.mem.splitScalar(u8, entry.name, ' ');
    const first = it.next();
    const second = it.next();
    entry.initials_len = 0;
    if (first) |f| {
        if (f.len > 0) {
            entry.initials[entry.initials_len] = std.ascii.toUpper(f[0]);
            entry.initials_len += 1;
        }
        if (second) |s| {
            if (s.len > 0) {
                entry.initials[entry.initials_len] = std.ascii.toUpper(s[0]);
                entry.initials_len += 1;
            }
        } else if (f.len > 1) {
            entry.initials[entry.initials_len] = std.ascii.toUpper(f[1]);
            entry.initials_len += 1;
        }
    }
}

pub fn render(ctx: *AppContext, page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = ctx.allocator;

    {
        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            s.new_person_dialog = !s.new_person_dialog;
        }
    }

    if (s.new_person_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const name = te.getText();
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            s.new_person_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue })) {
            if (name.len > 0) {
                const id = s.db.createPerson(name) catch |err| {
                    std.log.err("Create person failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, name) catch unreachable;
                var new_person = types.PersonEntry{ .id = id, .name = duped };
                computeInitials(&new_person);
                s.people.append(allocator, new_person) catch unreachable;
                s.new_person_dialog = false;
            }
        }
    }

    // People wall
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, MIN_CARD_WIDTH);

        var i: usize = 0;
        var row_idx: usize = 0;
        while (i < s.people.items.len) : (row_idx += 1) {
            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.people.items.len) : ({
                c += 1;
                i += 1;
            }) {
                const person = s.people.items[i];
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
}

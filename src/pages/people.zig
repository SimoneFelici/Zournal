const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");

const COLS = 6;
const AVATAR_SIZE: f32 = 60;

fn initials(name: []const u8, buf: *[2]u8) []const u8 {
    var it = std.mem.splitScalar(u8, name, ' ');

    const first = it.next();
    const second = it.next();

    var len: usize = 0;

    if (first) |f| {
        if (f.len > 0) {
            buf[len] = std.ascii.toUpper(f[0]);
            len += 1;
        }

        if (second) |s| {
            if (s.len > 0) {
                buf[len] = std.ascii.toUpper(s[0]);
                len += 1;
            }
        } else if (f.len > 1) {
            buf[len] = std.ascii.toUpper(f[1]);
            len += 1;
        }
    }

    return buf[0..len];
}

pub fn render(s: *state.ProjectViewState, allocator: std.mem.Allocator) !void {
    if (!s.people_loaded)
        try s.loadPeople(allocator);

    {
        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            s.new_person_dialog = !s.new_person_dialog;
        }
    }

    if (s.new_person_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
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
                s.people.append(allocator, .{ .id = id, .name = duped }) catch unreachable;
                s.new_person_dialog = false;
            }
        }
    }

    // People wall
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        var i: usize = 0;
        while (i < s.people.items.len) {
            {
                var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .id_extra = i,
                    .expand = .horizontal,
                });
                defer row.deinit();

                var col: usize = 0;
                while (col < COLS and i < s.people.items.len) : ({
                    col += 1;
                    i += 1;
                }) {
                    const person = s.people.items[i];
                    const idx = i;

                    {
                        var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                            .id_extra = idx,
                            .expand = .horizontal,
                        });
                        defer card.deinit();

                        var avatar_buf: [2]u8 = undefined;
                        const avatar = initials(person.name, &avatar_buf);

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
    }
}

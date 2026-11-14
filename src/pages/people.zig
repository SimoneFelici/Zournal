const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const types = @import("../types.zig");
const widgets = @import("../ui/widgets.zig");

const CARD_W: f32 = 140;
const CARD_SLOT: f32 = CARD_W + 12;
const AVATAR_SIZE: f32 = 60;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    var query: []const u8 = "";
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        var search = dvui.textEntry(@src(), .{ .placeholder = "Search..." }, .{ .gravity_x = 0.5 });
        query = search.textGet();
        search.deinit();

        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .style = .highlight, .gravity_x = 1 })) {
            s.new_person_dialog = !s.new_person_dialog;
        }
    }

    if (s.new_person_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const name = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            s.new_person_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .style = .highlight }) or enter) {
            if (name.len > 0) {
                const id = s.db.createPerson(name) catch |err| {
                    std.log.err("Create person failed: {}", .{err});
                    return;
                };
                const duped = allocator.dupe(u8, name) catch unreachable;
                var new_person = types.PersonEntry{ .id = id, .name = duped };
                new_person.computeInitials();
                s.people.append(allocator, new_person) catch unreachable;
                s.new_person_dialog = false;
            }
        }
    }

    // Icons Grid
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        var flex = dvui.flexbox(@src(), .{ .justify_content = .start }, .{ .expand = .horizontal });
        defer flex.deinit();

        for (s.people.items, 0..) |person, i| {
            if (!widgets.matches(person.name, query)) continue;

            var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = i,
                .min_size_content = .{ .w = CARD_W },
            });
            defer card.deinit();

            if (dvui.button(@src(), person.initials[0..person.initials_len], .{ .draw_focus = false }, .{
                .gravity_x = 0.5,
                .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE },
                .corners = .all(AVATAR_SIZE),
                .color_fill = person.color.fill(),
            })) {
                s.person_view = state.PersonViewState.init(person, null);
            }

            dvui.labelNoFmt(@src(), person.name, .{}, .{
                .gravity_x = 0.5,
                .max_size_content = .width(CARD_W - 8.0),
            });
        }
    }
}

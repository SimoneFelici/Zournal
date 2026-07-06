const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const types = @import("../types.zig");
const grid = @import("../ui/grid.zig");
const widgets = @import("../ui/widgets.zig");

const CARD_W: f32 = 140;
const CARD_SLOT: f32 = CARD_W + 12;
const AVATAR_SIZE: f32 = 60;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    const allocator = s.allocator();

    var search_open = false;
    {
        var top_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_bar.deinit();

        search_open = widgets.searchToggle(@src());

        if (dvui.buttonIcon(@src(), "New Person", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
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

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
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

    const query: []const u8 = if (search_open) widgets.searchEntry(@src()) else "";

    {
        var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
        defer scroll.deinit();

        const cols = grid.colsFor(scroll.data().rect.w, CARD_SLOT);

        var i: usize = 0;
        var row_idx: usize = 0;
        var shown: usize = 0;
        while (i < s.people.items.len) : (row_idx += 1) {
            while (i < s.people.items.len and !widgets.matches(s.people.items[i].name, query)) i += 1;
            if (i >= s.people.items.len) break;

            var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .id_extra = row_idx,
                .expand = .horizontal,
            });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols and i < s.people.items.len) : (i += 1) {
                const person = s.people.items[i];
                if (!widgets.matches(person.name, query)) continue;
                c += 1;
                shown += 1;
                const idx = i;

                var card = dvui.box(@src(), .{ .dir = .vertical }, .{
                    .id_extra = idx,
                    .min_size_content = .{ .w = CARD_W },
                });
                defer card.deinit();

                const avatar = person.initials[0..person.initials_len];

                if (dvui.button(@src(), avatar, .{ .draw_focus = false }, .{ .id_extra = idx, .gravity_x = 0.5, .min_size_content = .{ .w = AVATAR_SIZE, .h = AVATAR_SIZE }, .corners = dvui.CornerRect.round(AVATAR_SIZE) })) {
                    s.person_view = .{
                        .person_id = person.id,
                        .person_name = person.name,
                        .person_initials = person.initials,
                        .person_initials_len = person.initials_len,
                    };
                }

                dvui.labelNoFmt(@src(), widgets.fitText(person.name, CARD_W - 8.0), .{}, .{
                    .id_extra = idx,
                    .gravity_x = 0.5,
                });
            }
        }
    }
}

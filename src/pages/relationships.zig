const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");

const NODE_SIZE: f32 = 60;
const HALF: f32 = NODE_SIZE / 2;
const NODE_W: f32 = NODE_SIZE + 40;

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    var rs = &s.relationships;
    const allocator = s.allocator();

    try rs.load(s.db, s.people.items, allocator);

    {
        var canvas = dvui.box(@src(), .{}, .{ .expand = .both });
        defer canvas.deinit();

        const canvas_rs = canvas.data().contentRectScale();

        // Edges
        for (rs.relationships.items, 0..) |rel, ri| {
            const pos_a = posFor(rs.positions.items, rel.person_a_id) orelse continue;
            const pos_b = posFor(rs.positions.items, rel.person_b_id) orelse continue;

            const pt_a = canvas_rs.pointToPhysical(.{ .x = pos_a.x + HALF, .y = pos_a.y + HALF });
            const pt_b = canvas_rs.pointToPhysical(.{ .x = pos_b.x + HALF, .y = pos_b.y + HALF });

            dvui.Path.stroke(.{ .points = &.{ pt_a, pt_b } }, .{
                .thickness = 2.0 * canvas_rs.s,
                .color = dvui.Color.blue,
                .closed = false,
            });

            if (rel.label.len > 0) {
                const mx = (pos_a.x + pos_b.x) / 2 + HALF - 40;
                const my = (pos_a.y + pos_b.y) / 2 + HALF - 10;
                var lbox = dvui.box(@src(), .{}, .{
                    .id_extra = ri,
                    .rect = dvui.Rect{ .x = mx, .y = my, .w = 100, .h = 28 },
                });
                defer lbox.deinit();
                dvui.labelNoFmt(@src(), rel.label, .{}, .{ .gravity_x = 0.5 });
            }
        }

        // Nodes
        const evts = dvui.events();
        for (s.people.items, 0..) |person, i| {
            const pos_idx = for (rs.positions.items, 0..) |p, pi| {
                if (p.person_id == person.id) break pi;
            } else continue;
            var pos = &rs.positions.items[pos_idx];

            const is_selected = rs.selected_id != null and rs.selected_id.? == person.id;
            const avatar = person.initials[0..person.initials_len];

            var node = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = i,
                .rect = dvui.Rect{ .x = pos.x - 20, .y = pos.y, .w = NODE_W },
            });

            {
                var circle = dvui.box(@src(), .{}, .{
                    .gravity_x = 0.5,
                    .min_size_content = .{ .w = NODE_SIZE, .h = NODE_SIZE },
                    .background = true,
                    .style = .control,
                    .corners = dvui.CornerRect.round(NODE_SIZE),
                    .color_fill = if (is_selected) dvui.Color.blue else null,
                });
                defer circle.deinit();
                dvui.labelNoFmt(@src(), avatar, .{}, .{ .gravity_x = 0.5, .gravity_y = 0.5 });
            }

            dvui.labelNoFmt(@src(), person.name, .{}, .{ .gravity_x = 0.5 });

            for (evts) |*e| {
                if (!node.matchEvent(e)) continue;
                switch (e.evt) {
                    .mouse => |me| switch (me.action) {
                        .press => {
                            if (me.button == .left) {
                                e.handle(@src(), node.data());
                                dvui.captureMouse(node.data(), e.num);
                                dvui.dragPreStart(me.button, me.p, .{ .cursor = .hand });
                                rs.dragging_id = null;
                            }
                        },
                        .release => {
                            if (me.button == .left and dvui.captured(node.data().id)) {
                                e.handle(@src(), node.data());
                                dvui.captureMouse(null, e.num);
                                dvui.dragEnd();
                                if (rs.dragging_id != person.id) {
                                    handleClick(rs, person.id);
                                } else {
                                    s.db.saveNodePosition(person.id, pos.x, pos.y) catch |err| {
                                        std.log.err("Save position failed: {}", .{err});
                                    };
                                }
                                rs.dragging_id = null;
                            }
                        },
                        .motion => {
                            if (dvui.captured(node.data().id)) {
                                if (dvui.dragging(me.p, null)) |dps| {
                                    e.handle(@src(), node.data());
                                    const dp = dps.scale(1 / canvas_rs.s, dvui.Point);
                                    pos.x += dp.x;
                                    pos.y += dp.y;
                                    const cw = canvas_rs.r.w / canvas_rs.s;
                                    const ch = canvas_rs.r.h / canvas_rs.s;
                                    pos.x = @max(20.0, @min(pos.x, cw - NODE_W + 20.0));
                                    pos.y = @max(0.0, @min(pos.y, ch - NODE_SIZE - 24.0));
                                    rs.dragging_id = person.id;
                                }
                            }
                        },
                        .position => dvui.cursorSet(.hand),
                        else => {},
                    },
                    else => {},
                }
            }

            node.deinit();
        }
    }

    // New relationship dialog
    if (rs.connect_target_id != null and rs.selected_id != null) {
        const sel_name = for (s.people.items) |p| {
            if (p.id == rs.selected_id.?) break p.name;
        } else "?";
        const tgt_name = for (s.people.items) |p| {
            if (p.id == rs.connect_target_id.?) break p.name;
        } else "?";

        var show = true;
        var fw = dvui.floatingWindow(@src(), .{}, .{
            .min_size_content = .{ .w = 320, .h = 110 },
        });
        defer fw.deinit();

        fw.dragAreaSet(dvui.windowHeader("New Relationship", "", &show));

        if (!show) {
            rs.connect_target_id = null;
            rs.selected_id = null;
            return;
        }

        dvui.label(@src(), "{s}  <->  {s}", .{ sel_name, tgt_name }, .{ .gravity_x = 0.5 });

        {
            var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer dialog_box.deinit();

            var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
            const label_text = te.textGet();
            const enter = te.enter_pressed;
            te.deinit();

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
                rs.connect_target_id = null;
                rs.selected_id = null;
            }

            if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
                if (label_text.len > 0) {
                    const id = s.db.createRelationship(rs.selected_id.?, rs.connect_target_id.?, label_text) catch |err| {
                        std.log.err("Create relationship failed: {}", .{err});
                        return;
                    };
                    const duped = allocator.dupe(u8, label_text) catch unreachable;
                    rs.relationships.append(allocator, .{
                        .id = id,
                        .person_a_id = rs.selected_id.?,
                        .person_b_id = rs.connect_target_id.?,
                        .label = duped,
                    }) catch unreachable;
                    rs.connect_target_id = null;
                    rs.selected_id = null;
                }
            }
        }
    }

    // Delete relationship dialog
    if (rs.confirm_delete_conn_id) |conn_id| {
        var show = true;
        var fw = dvui.floatingWindow(@src(), .{}, .{
            .min_size_content = .{ .w = 260, .h = 90 },
        });
        defer fw.deinit();

        fw.dragAreaSet(dvui.windowHeader("Delete Relationship?", "", &show));

        if (!show) {
            rs.confirm_delete_conn_id = null;
            return;
        }

        {
            var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer btn_row.deinit();

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{ .gravity_x = 0 })) {
                rs.confirm_delete_conn_id = null;
            }

            if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                s.db.deleteRelationship(conn_id) catch |err| {
                    std.log.err("Delete relationship failed: {}", .{err});
                };
                for (rs.relationships.items, 0..) |r, ri| {
                    if (r.id == conn_id) {
                        _ = rs.relationships.orderedRemove(ri);
                        break;
                    }
                }
                rs.confirm_delete_conn_id = null;
                rs.selected_id = null;
            }
        }
    }
}

fn handleClick(rs: *state.RelationshipsState, person_id: i64) void {
    if (rs.selected_id == null) {
        rs.selected_id = person_id;
    } else if (rs.selected_id.? == person_id) {
        rs.selected_id = null;
    } else if (existingRelConn(rs.relationships.items, rs.selected_id.?, person_id)) |conn_id| {
        rs.confirm_delete_conn_id = conn_id;
        rs.selected_id = null;
    } else {
        rs.connect_target_id = person_id;
    }
}

fn existingRelConn(relationships: []const types.RelationshipEntry, a: i64, b: i64) ?i64 {
    for (relationships) |r| {
        if ((r.person_a_id == a and r.person_b_id == b) or
            (r.person_a_id == b and r.person_b_id == a)) return r.id;
    }
    return null;
}

fn posFor(positions: []types.NodePos, person_id: i64) ?types.NodePos {
    for (positions) |p| {
        if (p.person_id == person_id) return p;
    }
    return null;
}

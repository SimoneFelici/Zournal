const std = @import("std");
const dvui = @import("dvui");
const AppContext = @import("../context.zig").AppContext;
const state = @import("../states.zig");
const types = @import("../types.zig");

const CHAR_W: f32 = 8.0;
const NODE_MIN_W: f32 = 80.0;
const NODE_MAX_W: f32 = 180.0;
const NODE_HALF_H: f32 = 15.0;

fn nodeWidth(label: []const u8) f32 {
    return @max(NODE_MIN_W, @min(NODE_MAX_W, @as(f32, @floatFromInt(label.len)) * CHAR_W + 20.0));
}

pub fn render(s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    var ts = &cv.timeline;
    const allocator = s.allocator();
    try ts.load(s.db, cv.case_id, allocator);

    // Top bar
    {
        var top = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top.deinit();

        if (dvui.buttonIcon(@src(), "New Event", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            ts.new_event_dialog = !ts.new_event_dialog;
        }
    }

    if (ts.new_event_dialog) {
        var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer dialog_box.deinit();

        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const title = te.textGet();
        const enter = te.enter_pressed;
        te.deinit();

        if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
            ts.new_event_dialog = false;
        }

        if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
            if (title.len > 0) {
                const n = ts.events.items.len;
                const nx = 50.0 + @as(f32, @floatFromInt(n % 4)) * (NODE_MAX_W + 40.0);
                const ny = 50.0 + @as(f32, @floatFromInt(n / 4)) * 80.0;
                const id = s.db.createTimelineEvent(cv.case_id, title, nx, ny) catch |err| {
                    std.log.err("Create timeline event failed: {}", .{err});
                    return;
                };
                const duped_label = allocator.dupe(u8, title) catch unreachable;
                const duped_content = allocator.dupe(u8, "") catch unreachable;
                ts.events.append(allocator, .{
                    .id = id,
                    .label = duped_label,
                    .content = duped_content,
                    .x = nx,
                    .y = ny,
                }) catch unreachable;
                ts.new_event_dialog = false;
                ts.editing_id = id;
            }
        }
    }

    // Canvas
    {
        var canvas = dvui.box(@src(), .{}, .{ .expand = .both });
        defer canvas.deinit();

        const canvas_rs = canvas.data().contentRectScale();

        // Edges
        for (ts.connections.items, 0..) |conn, ci| {
            const evt_a = eventFor(ts.events.items, conn.from_id) orelse continue;
            const evt_b = eventFor(ts.events.items, conn.to_id) orelse continue;

            const w_a = nodeWidth(evt_a.label);
            const w_b = nodeWidth(evt_b.label);

            const pt_a = canvas_rs.pointToPhysical(.{ .x = evt_a.x + w_a / 2.0, .y = evt_a.y + NODE_HALF_H });
            const pt_b = canvas_rs.pointToPhysical(.{ .x = evt_b.x + w_b / 2.0, .y = evt_b.y + NODE_HALF_H });

            dvui.Path.stroke(.{ .points = &.{ pt_a, pt_b } }, .{
                .thickness = 2.0 * canvas_rs.s,
                .color = dvui.Color.blue,
                .closed = false,
            });

            if (conn.connection_type.len > 0) {
                const lx = (evt_a.x + w_a / 2.0 + evt_b.x + w_b / 2.0) / 2.0 - 50.0;
                const ly = (evt_a.y + evt_b.y) / 2.0 + NODE_HALF_H - 14.0;
                var lbox = dvui.box(@src(), .{}, .{
                    .id_extra = ci,
                    .rect = dvui.Rect{ .x = lx, .y = ly, .w = 100.0, .h = 28.0 },
                });
                defer lbox.deinit();
                dvui.labelNoFmt(@src(), conn.connection_type, .{}, .{ .gravity_x = 0.5 });
            }
        }

        // Nodes
        const evts = dvui.events();
        for (ts.events.items, 0..) |*evt, i| {
            const is_selected = ts.selected_id != null and ts.selected_id.? == evt.id;
            const nw = nodeWidth(evt.label);

            var node = dvui.box(@src(), .{ .dir = .vertical }, .{
                .id_extra = i,
                .rect = dvui.Rect{ .x = evt.x, .y = evt.y, .w = nw },
                .background = true,
                .style = .control,
                .corner_radius = dvui.Rect.all(4),
                .color_fill = if (is_selected) dvui.Color.blue else null,
            });

            dvui.labelNoFmt(@src(), evt.label, .{}, .{ .gravity_x = 0.5 });

            for (evts) |*e| {
                if (!node.matchEvent(e)) continue;
                switch (e.evt) {
                    .mouse => |me| switch (me.action) {
                        .press => {
                            if (me.button == .left) {
                                e.handle(@src(), node.data());
                                dvui.captureMouse(node.data(), e.num);
                                dvui.dragPreStart(me.p, .{ .cursor = .hand });
                                ts.dragging_id = null;
                            }
                        },
                        .release => {
                            if (me.button == .left and dvui.captured(node.data().id)) {
                                e.handle(@src(), node.data());
                                dvui.captureMouse(null, e.num);
                                dvui.dragEnd();
                                if (ts.dragging_id != evt.id) {
                                    handleClick(ts, evt.id);
                                } else {
                                    s.db.updateTimelineEventPosition(evt.id, evt.x, evt.y) catch |err| {
                                        std.log.err("Save event position failed: {}", .{err});
                                    };
                                }
                                ts.dragging_id = null;
                            }
                        },
                        .motion => {
                            if (dvui.captured(node.data().id)) {
                                if (dvui.dragging(me.p, null)) |dps| {
                                    e.handle(@src(), node.data());
                                    const dp = dps.scale(1.0 / canvas_rs.s, dvui.Point);
                                    evt.x += dp.x;
                                    evt.y += dp.y;
                                    const cw = canvas_rs.r.w / canvas_rs.s;
                                    const ch = canvas_rs.r.h / canvas_rs.s;
                                    evt.x = @max(0.0, @min(evt.x, cw - nw));
                                    evt.y = @max(0.0, @min(evt.y, ch - NODE_HALF_H * 2.0 - 10.0));
                                    ts.dragging_id = evt.id;
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

    // New connection dialog
    if (ts.connect_target_id != null and ts.selected_id != null) {
        const sel_label = for (ts.events.items) |e| {
            if (e.id == ts.selected_id.?) break e.label;
        } else "?";
        const tgt_label = for (ts.events.items) |e| {
            if (e.id == ts.connect_target_id.?) break e.label;
        } else "?";

        var show = true;
        var fw = dvui.floatingWindow(@src(), .{}, .{
            .min_size_content = .{ .w = 320, .h = 110 },
        });
        defer fw.deinit();

        fw.dragAreaSet(dvui.windowHeader("New Connection", "", &show));

        if (!show) {
            ts.connect_target_id = null;
            ts.selected_id = null;
            return;
        }

        dvui.label(@src(), "{s}  ->  {s}", .{ sel_label, tgt_label }, .{ .gravity_x = 0.5 });

        {
            var dialog_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer dialog_box.deinit();

            var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
            const conn_type = te.textGet();
            const enter = te.enter_pressed;
            te.deinit();

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{})) {
                ts.connect_target_id = null;
                ts.selected_id = null;
            }

            if (dvui.button(@src(), "Connect", .{ .draw_focus = false }, .{ .color_fill = .blue }) or enter) {
                const id = s.db.createEventConnection(ts.selected_id.?, ts.connect_target_id.?, conn_type) catch |err| {
                    std.log.err("Create connection failed: {}", .{err});
                    return;
                };
                const duped_type = allocator.dupe(u8, conn_type) catch unreachable;
                ts.connections.append(allocator, .{
                    .id = id,
                    .from_id = ts.selected_id.?,
                    .to_id = ts.connect_target_id.?,
                    .connection_type = duped_type,
                }) catch unreachable;
                ts.connect_target_id = null;
                ts.selected_id = null;
            }
        }
    }

    // Delete connection dialog
    if (ts.confirm_delete_conn_id) |conn_id| {
        var show = true;
        var fw = dvui.floatingWindow(@src(), .{}, .{
            .min_size_content = .{ .w = 260, .h = 90 },
        });
        defer fw.deinit();

        fw.dragAreaSet(dvui.windowHeader("Delete Connection?", "", &show));

        if (!show) {
            ts.confirm_delete_conn_id = null;
            return;
        }

        {
            var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            defer btn_row.deinit();

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{ .gravity_x = 0 })) {
                ts.confirm_delete_conn_id = null;
            }

            if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                s.db.deleteEventConnection(conn_id) catch |err| {
                    std.log.err("Delete connection failed: {}", .{err});
                };
                for (ts.connections.items, 0..) |c, ci| {
                    if (c.id == conn_id) {
                        _ = ts.connections.orderedRemove(ci);
                        break;
                    }
                }
                ts.confirm_delete_conn_id = null;
                ts.selected_id = null;
            }
        }
    }

    // Edit event dialog
    if (ts.editing_id) |eid| {
        const evt_idx = for (ts.events.items, 0..) |e, idx| {
            if (e.id == eid) break idx;
        } else null;

        if (evt_idx) |idx| {
            var show = true;
            var fw = dvui.floatingWindow(@src(), .{}, .{
                .min_size_content = .{ .w = 420, .h = 360 },
            });
            defer fw.deinit();

            fw.dragAreaSet(dvui.windowHeader("Edit Event", "", &show));

            if (!show) {
                const evt = ts.events.items[idx];
                s.db.updateTimelineEventLabel(evt.id, evt.label) catch |err| {
                    std.log.err("Save event label failed: {}", .{err});
                };
                s.db.updateTimelineEventContent(evt.id, evt.content) catch |err| {
                    std.log.err("Save event content failed: {}", .{err});
                };
                ts.editing_id = null;
                ts.selected_id = null;
                return;
            }

            {
                var te_title = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                const current_title = te_title.textGet();
                if (current_title.len == 0 and ts.events.items[idx].label.len > 0 and dvui.focusedWidgetId() != te_title.data().id) {
                    te_title.textSet(ts.events.items[idx].label, false);
                }
                const new_title = te_title.textGet();
                if (!std.mem.eql(u8, new_title, ts.events.items[idx].label)) {
                    ts.events.items[idx].label = allocator.dupe(u8, new_title) catch unreachable;
                }
                te_title.deinit();
            }

            {
                var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
                    .expand = .both,
                    .min_size_content = .{ .w = 400, .h = 240 },
                });
                defer te.deinit();

                const current = te.textGet();
                if (current.len == 0 and ts.events.items[idx].content.len > 0 and dvui.focusedWidgetId() != te.data().id) {
                    te.textSet(ts.events.items[idx].content, false);
                }
                const text = te.textGet();
                if (!std.mem.eql(u8, text, ts.events.items[idx].content)) {
                    ts.events.items[idx].content = allocator.dupe(u8, text) catch unreachable;
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Save", .{ .draw_focus = false }, .{ .color_fill = .blue })) {
                    const evt = ts.events.items[idx];
                    s.db.updateTimelineEventLabel(evt.id, evt.label) catch |err| {
                        std.log.err("Save event label failed: {}", .{err});
                    };
                    s.db.updateTimelineEventContent(evt.id, evt.content) catch |err| {
                        std.log.err("Save event content failed: {}", .{err});
                    };
                }

                if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
                    s.db.deleteTimelineEvent(eid) catch |err| {
                        std.log.err("Delete event failed: {}", .{err});
                        return;
                    };
                    _ = ts.events.orderedRemove(idx);
                    var ci: usize = 0;
                    while (ci < ts.connections.items.len) {
                        const conn = ts.connections.items[ci];
                        if (conn.from_id == eid or conn.to_id == eid) {
                            _ = ts.connections.orderedRemove(ci);
                        } else {
                            ci += 1;
                        }
                    }
                    ts.editing_id = null;
                    ts.selected_id = null;
                }
            }
        } else {
            ts.editing_id = null;
        }
    }
}

fn handleClick(ts: *state.TimelineState, event_id: i64) void {
    if (ts.selected_id == null) {
        ts.selected_id = event_id;
    } else if (ts.selected_id.? == event_id) {
        ts.editing_id = event_id;
    } else if (existingEventConn(ts.connections.items, ts.selected_id.?, event_id)) |conn_id| {
        ts.confirm_delete_conn_id = conn_id;
        ts.selected_id = null;
    } else {
        ts.connect_target_id = event_id;
    }
}

fn existingEventConn(connections: []const types.EventConnection, a: i64, b: i64) ?i64 {
    for (connections) |c| {
        if ((c.from_id == a and c.to_id == b) or (c.from_id == b and c.to_id == a)) return c.id;
    }
    return null;
}

fn eventFor(events: []const types.TimelineEvent, event_id: i64) ?types.TimelineEvent {
    for (events) |e| {
        if (e.id == event_id) return e;
    }
    return null;
}

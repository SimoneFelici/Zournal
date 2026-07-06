const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const types = @import("../types.zig");
const widgets = @import("../ui/widgets.zig");

const NODE_MIN_W: f32 = 80.0;
const NODE_MAX_W: f32 = 220.0;
const NODE_HALF_H: f32 = 15.0;
const NODE_PAD_W: f32 = 30.0;

pub fn render(s: *state.ProjectViewState, cv: *state.CaseViewState) !void {
    var ts = &cv.timeline;
    try ts.load(s.db, cv.case_id, s.allocator());

    // Top bar
    {
        var top = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top.deinit();

        if (dvui.buttonIcon(@src(), "New Event", dvui.entypo.plus, .{ .draw_focus = false }, .{}, .{ .color_fill = .blue, .gravity_x = 1 })) {
            ts.new_event_dialog = !ts.new_event_dialog;
        }
    }

    if (renderNewEventDialog(s, cv, ts)) return;

    renderCanvas(s, ts);

    if (renderConnectDialog(s, ts)) return;
    if (renderDeleteConnDialog(s, ts)) return;
    renderEditDialog(s, ts);
}

fn renderNewEventDialog(s: *state.ProjectViewState, cv: *state.CaseViewState, ts: *state.TimelineState) bool {
    if (!ts.new_event_dialog) return false;
    const allocator = s.allocator();

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
                return true;
            };
            ts.events.append(allocator, .{
                .id = id,
                .label = allocator.dupe(u8, title) catch unreachable,
                .content = allocator.dupe(u8, "") catch unreachable,
                .x = nx,
                .y = ny,
            }) catch unreachable;
            ts.new_event_dialog = false;
            ts.editing_id = id;
        }
    }
    return false;
}

fn renderConnectDialog(s: *state.ProjectViewState, ts: *state.TimelineState) bool {
    if (ts.connect_target_id == null or ts.selected_id == null) return false;
    const allocator = s.allocator();

    const sel_label = if (eventFor(ts.events.items, ts.selected_id.?)) |e| e.label else "?";
    const tgt_label = if (eventFor(ts.events.items, ts.connect_target_id.?)) |e| e.label else "?";

    var show = true;
    var fw = dvui.floatingWindow(@src(), .{}, .{
        .min_size_content = .{ .w = 320, .h = 110 },
    });
    defer fw.deinit();

    fw.dragAreaSet(dvui.windowHeader("New Connection", "", &show));

    if (!show) {
        ts.connect_target_id = null;
        ts.selected_id = null;
        return true;
    }

    dvui.label(@src(), "{s}  ->  {s}", .{ sel_label, tgt_label }, .{ .gravity_x = 0.5 });

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
            return true;
        };
        ts.connections.append(allocator, .{
            .id = id,
            .from_id = ts.selected_id.?,
            .to_id = ts.connect_target_id.?,
            .connection_type = allocator.dupe(u8, conn_type) catch unreachable,
        }) catch unreachable;
        ts.connect_target_id = null;
        ts.selected_id = null;
    }
    return false;
}

fn renderDeleteConnDialog(s: *state.ProjectViewState, ts: *state.TimelineState) bool {
    const conn_id = ts.confirm_delete_conn_id orelse return false;

    var show = true;
    var fw = dvui.floatingWindow(@src(), .{}, .{
        .min_size_content = .{ .w = 260, .h = 90 },
    });
    defer fw.deinit();

    fw.dragAreaSet(dvui.windowHeader("Delete Connection?", "", &show));

    if (!show) {
        ts.confirm_delete_conn_id = null;
        return true;
    }

    var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer btn_row.deinit();

    if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{ .gravity_x = 0 })) {
        ts.confirm_delete_conn_id = null;
    }

    if (dvui.button(@src(), "Delete", .{ .draw_focus = false }, .{ .color_fill_hover = .red, .gravity_x = 1 })) {
        s.db.deleteEventConnection(conn_id) catch |err| {
            std.log.err("Delete connection failed: {}", .{err});
        };
        removeConnectionById(ts, conn_id);
        ts.confirm_delete_conn_id = null;
        ts.selected_id = null;
    }
    return false;
}

fn renderEditDialog(s: *state.ProjectViewState, ts: *state.TimelineState) void {
    const eid = ts.editing_id orelse return;
    const idx = eventIndex(ts.events.items, eid) orelse {
        ts.editing_id = null;
        return;
    };
    const allocator = s.allocator();

    var show = true;
    var fw = dvui.floatingWindow(@src(), .{}, .{
        .id_extra = @as(usize, @intCast(eid)),
        .min_size_content = .{ .w = 420, .h = 360 },
    });
    defer fw.deinit();

    fw.dragAreaSet(dvui.windowHeader("Edit Event", "", &show));

    if (!show) {
        saveEvent(s, ts.events.items[idx]);
        ts.editing_id = null;
        ts.selected_id = null;
        return;
    }

    // Title + delete
    {
        var top_row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer top_row.deinit();

        {
            var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
            defer te.deinit();
            widgets.syncText(te, &ts.events.items[idx].label, allocator);
        }

        if (dvui.buttonIcon(@src(), "Delete Event", dvui.entypo.trash, .{ .draw_focus = false }, .{}, .{ .color_fill = .red, .gravity_y = 0.5 })) {
            s.db.deleteTimelineEvent(eid) catch |err| {
                std.log.err("Delete event failed: {}", .{err});
                return;
            };
            _ = ts.events.orderedRemove(idx);
            removeConnectionsFor(ts, eid);
            ts.editing_id = null;
            ts.selected_id = null;
            return;
        }
    }

    // Content
    {
        var te = dvui.textEntry(@src(), .{ .multiline = true }, .{
            .expand = .both,
            .min_size_content = .{ .w = 400, .h = 240 },
        });
        defer te.deinit();
        widgets.syncText(te, &ts.events.items[idx].content, allocator);
    }
}

fn renderCanvas(s: *state.ProjectViewState, ts: *state.TimelineState) void {
    var canvas = dvui.box(@src(), .{}, .{ .expand = .both });
    defer canvas.deinit();

    const canvas_rs = canvas.data().contentRectScale();

    renderEdges(ts, canvas_rs);

    const evts = dvui.events();
    for (ts.events.items, 0..) |*evt, i| {
        renderNode(s, ts, evt, i, canvas_rs, evts);
    }
}

fn renderEdges(ts: *state.TimelineState, canvas_rs: dvui.RectScale) void {
    for (ts.connections.items, 0..) |conn, ci| {
        const evt_a = eventFor(ts.events.items, conn.from_id) orelse continue;
        const evt_b = eventFor(ts.events.items, conn.to_id) orelse continue;

        const cx_a = evt_a.x + nodeWidth(evt_a.label) / 2.0;
        const cx_b = evt_b.x + nodeWidth(evt_b.label) / 2.0;

        const pt_a = canvas_rs.pointToPhysical(.{ .x = cx_a, .y = evt_a.y + NODE_HALF_H });
        const pt_b = canvas_rs.pointToPhysical(.{ .x = cx_b, .y = evt_b.y + NODE_HALF_H });

        dvui.Path.stroke(.{ .points = &.{ pt_a, pt_b } }, .{
            .thickness = 2.0 * canvas_rs.s,
            .color = dvui.Color.blue,
            .closed = false,
        });

        if (conn.connection_type.len > 0) {
            const lw = dvui.themeGet().font_body.textSize(conn.connection_type).w + 24.0;
            var lbox = dvui.box(@src(), .{}, .{
                .id_extra = ci,
                .rect = dvui.Rect{
                    .x = (cx_a + cx_b) / 2.0 - lw / 2.0,
                    .y = (evt_a.y + evt_b.y) / 2.0 + NODE_HALF_H - 14.0,
                    .w = lw,
                    .h = 28.0,
                },
            });
            defer lbox.deinit();
            dvui.labelNoFmt(@src(), conn.connection_type, .{}, .{ .gravity_x = 0.5 });
        }
    }
}

fn renderNode(s: *state.ProjectViewState, ts: *state.TimelineState, evt: *types.TimelineEvent, i: usize, canvas_rs: dvui.RectScale, evts: []dvui.Event) void {
    const nw = nodeWidth(evt.label);
    const is_selected = ts.selected_id != null and ts.selected_id.? == evt.id;

    var node = dvui.box(@src(), .{ .dir = .vertical }, .{
        .id_extra = i,
        .rect = dvui.Rect{ .x = evt.x, .y = evt.y, .w = nw },
        .background = true,
        .style = .control,
        .corners = dvui.CornerRect.round(4),
        .color_fill = if (is_selected) dvui.Color.blue else null,
    });
    defer node.deinit();

    dvui.labelNoFmt(@src(), evt.label, .{}, .{ .gravity_x = 0.5 });

    for (evts) |*e| {
        if (!node.matchEvent(e)) continue;
        const me = switch (e.evt) {
            .mouse => |m| m,
            else => continue,
        };
        switch (me.action) {
            .press => if (me.button == .left) {
                e.handle(@src(), node.data());
                dvui.captureMouse(node.data(), e.num);
                dvui.dragPreStart(me.button, me.p, .{ .cursor = .hand });
                ts.dragging_id = null;
            },
            .release => if (me.button == .left and dvui.captured(node.data().id)) {
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
            },
            .motion => if (dvui.captured(node.data().id)) {
                if (dvui.dragging(me.p, null)) |dps| {
                    e.handle(@src(), node.data());
                    const dp = dps.scale(1.0 / canvas_rs.s, dvui.Point);
                    const cw = canvas_rs.r.w / canvas_rs.s;
                    const ch = canvas_rs.r.h / canvas_rs.s;
                    evt.x = @max(0.0, @min(evt.x + dp.x, cw - nw));
                    evt.y = @max(0.0, @min(evt.y + dp.y, ch - NODE_HALF_H * 2.0 - 10.0));
                    ts.dragging_id = evt.id;
                }
            },
            .position => dvui.cursorSet(.hand),
            else => {},
        }
    }
}

fn nodeWidth(label: []const u8) f32 {
    const text_w = dvui.themeGet().font_body.textSize(label).w;
    return @max(NODE_MIN_W, @min(NODE_MAX_W, text_w + NODE_PAD_W));
}

fn saveEvent(s: *state.ProjectViewState, evt: types.TimelineEvent) void {
    s.db.updateTimelineEventLabel(evt.id, evt.label) catch |err| {
        std.log.err("Save event label failed: {}", .{err});
    };
    s.db.updateTimelineEventContent(evt.id, evt.content) catch |err| {
        std.log.err("Save event content failed: {}", .{err});
    };
}

fn removeConnectionById(ts: *state.TimelineState, conn_id: i64) void {
    for (ts.connections.items, 0..) |c, ci| {
        if (c.id == conn_id) {
            _ = ts.connections.orderedRemove(ci);
            return;
        }
    }
}

fn removeConnectionsFor(ts: *state.TimelineState, event_id: i64) void {
    var ci: usize = 0;
    while (ci < ts.connections.items.len) {
        const conn = ts.connections.items[ci];
        if (conn.from_id == event_id or conn.to_id == event_id) {
            _ = ts.connections.orderedRemove(ci);
        } else {
            ci += 1;
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

fn eventIndex(events: []const types.TimelineEvent, event_id: i64) ?usize {
    for (events, 0..) |e, idx| {
        if (e.id == event_id) return idx;
    }
    return null;
}

fn eventFor(events: []const types.TimelineEvent, event_id: i64) ?types.TimelineEvent {
    for (events) |e| {
        if (e.id == event_id) return e;
    }
    return null;
}

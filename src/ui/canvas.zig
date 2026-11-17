const std = @import("std");
const dvui = @import("dvui");

pub const SIZE: dvui.Size = .{ .w = 3000, .h = 3000 };
pub const MARGIN: f32 = 100;

const MIN_ZOOM: f32 = 0.25;
const MAX_ZOOM: f32 = 4.0;
const ZOOM_STEP: f32 = 1.0025;

pub const Canvas = struct {
    scale: *f32,
    area: *dvui.ScrollAreaWidget,
    scaler: *dvui.ScaleWidget,
    box: *dvui.BoxWidget,

    pub fn rectScale(self: *const Canvas) dvui.RectScale {
        return self.box.data().contentRectScale();
    }

    pub fn end(self: *Canvas) void {
        const container = &self.area.scroll.?;
        const si = self.area.si;
        const container_id = container.data().id;
        const scroll_rs = container.screenRectScale(.{});
        const data_rs = self.rectScale();

        var zoom: f32 = 1.0;
        var zoom_p: dvui.Point.Physical = .{};

        for (dvui.events()) |*e| {
            if (!container.matchEvent(e)) continue;
            const me = switch (e.evt) {
                .mouse => |m| m,
                else => continue,
            };
            switch (me.action) {
                .press => if (me.button.pointer()) {
                    e.handle(@src(), container.data());
                    dvui.captureMouse(container.data(), e.num);
                    dvui.dragPreStart(me.button, me.p, .{ .cursor = .arrow_all });
                },
                .release => if (me.button.pointer() and dvui.captured(container_id)) {
                    e.handle(@src(), container.data());
                    dvui.captureMouse(null, e.num);
                    dvui.dragEnd(me.button);
                },
                .motion => if (dvui.captured(container_id)) {
                    if (dvui.dragging(me, null)) |dps| {
                        e.handle(@src(), container.data());
                        si.scrollByOffset(.horizontal, -dps.x / scroll_rs.s);
                        si.scrollByOffset(.vertical, -dps.y / scroll_rs.s);
                        dvui.refresh(null, @src(), container_id);
                    }
                },
                .wheel_y => |wy| {
                    e.handle(@src(), container.data());
                    zoom *= @exp(@log(ZOOM_STEP) * wy);
                    zoom_p = me.p;
                },
                else => {},
            }
        }

        self.box.deinit();
        self.scaler.deinit();
        self.area.deinit();

        if (zoom != 1.0) {
            const under_mouse = data_rs.pointFromPhysical(zoom_p);
            const old = self.scale.*;
            self.scale.* = std.math.clamp(old * zoom, MIN_ZOOM, MAX_ZOOM);
            const moved_to = data_rs.pointToPhysical(under_mouse.scale(self.scale.* / old, dvui.Point));
            const diff = scroll_rs.pointFromPhysical(moved_to).diff(scroll_rs.pointFromPhysical(zoom_p));
            si.virtual_size = .{
                .w = (SIZE.w + 2 * MARGIN) * self.scale.*,
                .h = (SIZE.h + 2 * MARGIN) * self.scale.*,
            };
            si.scrollByOffset(.horizontal, diff.x);
            si.scrollByOffset(.vertical, diff.y);
            dvui.refresh(null, @src(), container_id);
        }
    }
};

pub fn begin(src: std.builtin.SourceLocation) Canvas {
    const area = dvui.scrollArea(src, .{ .horizontal = .auto, .vertical_bar = .hide, .horizontal_bar = .hide }, .{ .expand = .both, .style = .content });
    const scale = dvui.dataGetPtrDefault(null, area.data().id, "scale", f32, 1.0);
    const scaler = dvui.scale(@src(), .{ .scale = scale }, .{});
    const box = dvui.box(@src(), .{}, .{ .min_size_content = SIZE, .margin = .all(MARGIN), .background = true, .style = .window, .corners = .all(3) });
    return .{ .scale = scale, .area = area, .scaler = scaler, .box = box };
}

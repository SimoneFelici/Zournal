const std = @import("std");
const dvui = @import("dvui");
const state = @import("states.zig");
const project_select = @import("pages/project_select.zig");
// const project_view = @import("pages/project_view.zig");

var gpa: std.heap.DebugAllocator(.{}) = .init;
const app_allocator = gpa.allocator();
var page: state.PageState = .{ .project_select = .{} };

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800.0, .h = 600.0 },
            .min_size = .{ .w = 500.0, .h = 350.0 },
            .title = "Zournal",
        },
    },
    .frameFn = frame,
    .initFn = null,
};
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
    .log_level = .info,
};

pub fn frame() !dvui.App.Result {
    dvui.label(@src(), "{d:0>3.0} fps", .{dvui.FPS()}, .{ .gravity_x = 1.0 });

    switch (page) {
        .project_select => try project_select.render(&page, app_allocator),
        // .project_view => try project_view.render(&page, app_allocator),
    }

    return .ok;
}

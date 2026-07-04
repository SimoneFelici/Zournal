const std = @import("std");
const builtin = @import("builtin");
const AppContext = @import("context.zig").AppContext;
const state = @import("states.zig");
const dvui = @import("dvui");
const project_select = @import("pages/project_select.zig");
const project_view = @import("pages/project_view.zig");
const SDLBackend = @import("sdl-backend");

var gpa: std.heap.DebugAllocator(.{}) = .init;
var io_threaded: std.Io.Threaded = .init_single_threaded;

var app_ctx: AppContext = undefined;
var page: state.PageState = undefined;

fn processEnviron() std.process.Environ {
    return switch (builtin.os.tag) {
        .windows => .{ .block = .global },
        else => .{ .block = .{ .slice = std.mem.sliceTo(std.c.environ, null) } },
    };
}

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800.0, .h = 600.0 },
            .title = "Zournal",
            .window_init_options = .{
                .theme = dvui.Theme.builtin.adwaita_dark,
            },
        },
    },
    .frameFn = AppFrame,
    .initFn = AppInit,
    .deinitFn = AppDeinit,
};

fn AppDeinit() void {
    switch (page) {
        .project_select => page.project_select.deinit(),
        .project_view => page.project_view.deinit(),
    }

    app_ctx.environ_map.deinit();

    _ = gpa.deinit();
}

fn AppInit(win: *dvui.Window) !void {
    _ = win;

    const allocator = gpa.allocator();
    const environ_map = try processEnviron().createMap(allocator);

    app_ctx = .{
        .allocator = allocator,
        .io = io_threaded.io(),
        .environ_map = environ_map,
    };
    page = .{ .project_select = state.ProjectSelectState.init(allocator) };
}

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
    .log_level = .info,
};

pub fn AppFrame() !dvui.App.Result {
    return switch (page) {
        .project_select => try project_select.render(&app_ctx, &page),
        .project_view => try project_view.render(&app_ctx, &page),
    };
}

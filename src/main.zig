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
var page: state.PageState = .{ .project_select = .{} };

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
            .min_size = .{ .w = 500.0, .h = 350.0 },
            .title = "Zournal",
        },
    },
    .frameFn = AppFrame,
    .initFn = AppInit,
};

fn AppInit(win: *dvui.Window) !void {
    const sdl_backend: *SDLBackend = @ptrCast(@alignCast(win.backend.impl));
    _ = SDLBackend.c.SDL_MaximizeWindow(sdl_backend.window);

    const allocator = gpa.allocator();
    const environ_map = try processEnviron().createMap(allocator);

    app_ctx = .{
        .allocator = allocator,
        .io = io_threaded.io(),
        .environ_map = environ_map,
    };
}

pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
    .log_level = .info,
};

pub fn AppFrame() !dvui.App.Result {
    switch (page) {
        .project_select => try project_select.render(&app_ctx, &page),
        .project_view => try project_view.render(&app_ctx, &page),
    }
    return .ok;
}

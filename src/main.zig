const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

const PageState = union(enum) {
    project_select: ProjectSelectState,
    // project_view: ProjectViewState,
};

const ProjectSelectState = struct {
    projects: std.ArrayList([]const u8) = .{},
    loaded: bool = false,

    fn load(self: *ProjectSelectState, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        var root = getRootDir(allocator);
        defer root.close();
        var iter = root.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                const name = try allocator.dupe(u8, entry.name);
                try self.projects.append(allocator, name);
            }
        }
        self.loaded = true;
    }

    fn invalidate(self: *ProjectSelectState, allocator: std.mem.Allocator) void {
        for (self.projects.items) |name| {
            allocator.free(name);
        }
        self.projects.clearRetainingCapacity();
        self.loaded = false;
    }
};

var app_allocator: std.mem.Allocator = std.heap.page_allocator;
var page: PageState = .{ .project_select = .{} };

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

fn getRootDir(allocator: std.mem.Allocator) std.fs.Dir {
    const app_data = std.fs.getAppDataDir(allocator, "Zournal") catch unreachable;
    defer allocator.free(app_data);
    return std.fs.cwd().openDir(app_data, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => {
            std.fs.cwd().makePath(app_data) catch unreachable;
            std.log.info("Created root folder {s}\n", .{app_data});
            return std.fs.cwd().openDir(app_data, .{ .iterate = true }) catch unreachable;
        },
        else => unreachable,
    };
}

pub fn frame() !dvui.App.Result {
    dvui.label(@src(), "{d:0>3.0} fps", .{dvui.FPS()}, .{ .gravity_x = 1.0 });
    switch (page) {
        .project_select => {
            var state = &page.project_select;
            try state.load(app_allocator);

            var outer = dvui.box(@src(), .{}, .{
                .expand = .both,
            });
            defer outer.deinit();

            var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
                .gravity_x = 0.5,
                .gravity_y = 0.5,
                .min_size_content = .{ .w = 450, .h = 0 },
            });
            defer main_box.deinit();

            {
                var scroll = dvui.scrollArea(@src(), .{}, .{
                    .expand = .horizontal,
                    .max_size_content = .{ .w = 9999, .h = 250 },
                });
                defer scroll.deinit();

                for (state.projects.items, 0..) |name, i| {
                    if (dvui.button(@src(), name, .{}, .{
                        .id_extra = i,
                        .expand = .horizontal,
                    })) {
                        std.log.info("Selected: {s}", .{name});
                    }
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .horizontal,
                });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Import", .{}, .{ .color_fill = .green })) {
                    // TODO
                }

                var spacer = dvui.box(@src(), .{}, .{ .expand = .horizontal });
                spacer.deinit();

                if (dvui.button(@src(), "New Project", .{}, .{ .color_fill = .blue })) {
                    // TODO
                }
            }
        },
    }
    return .ok;
}

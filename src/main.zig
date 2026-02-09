const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");
const c = @cImport({
    @cInclude("sqlite3.h");
});

const types = @import("types.zig");
const fs = @import("fs_utils.zig");

const PageState = union(enum) {
    project_select: ProjectSelectState,
    // project_view: ProjectViewState,
};

const ProjectSelectState = struct {
    projects: std.ArrayList(types.ProjectEntry) = .{},
    loaded: bool = false,
    new_project_dialog: bool = false,

    fn fetchProjects(self: *ProjectSelectState, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.projects = try fs.listProjects(allocator);
        self.loaded = true;
    }
};

var gpa: std.heap.DebugAllocator(.{}) = .init;
const app_allocator = gpa.allocator();
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

pub fn frame() !dvui.App.Result {
    dvui.label(@src(), "{d:0>3.0} fps", .{dvui.FPS()}, .{ .gravity_x = 1.0 });
    switch (page) {
        .project_select => {
            var state = &page.project_select;
            if (!state.loaded)
                try state.fetchProjects(app_allocator);

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

                for (state.projects.items, 0..) |entry, i| {
                    if (dvui.button(@src(), entry.name, .{}, .{
                        .id_extra = i,
                        .expand = .horizontal,
                    })) {
                        std.log.info("Selected: {s}", .{entry.name});
                    }
                }
            }

            {
                var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
                    .expand = .horizontal,
                });
                defer btn_row.deinit();

                if (dvui.button(@src(), "Import", .{}, .{ .color_fill = .green })) {
                    if (try dvui.native_dialogs.Native.folderSelect(app_allocator, .{ .title = "Import" })) |path| {
                        defer app_allocator.free(path);
                        std.log.info("Importing folder: {s}", .{path});
                        fs.importFolder(app_allocator, path) catch |err| {
                            std.log.err("Import failed: {}", .{err});
                        };
                        const name = app_allocator.dupe(u8, std.fs.path.basename(path)) catch unreachable;
                        state.projects.insert(app_allocator, 0, .{
                            .name = name,
                            .mtime = std.time.nanoTimestamp(),
                        }) catch unreachable;
                    }
                }

                var spacer = dvui.box(@src(), .{}, .{ .expand = .horizontal });
                spacer.deinit();

                if (!state.new_project_dialog) {
                    if (dvui.button(@src(), "New Project", .{}, .{ .color_fill = .blue })) {
                        state.new_project_dialog = true;
                    }
                }
            }

            if (state.new_project_dialog) {
                var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
                const name = te.getText();
                te.deinit();

                {
                    var dialog_btns = dvui.box(@src(), .{ .dir = .horizontal }, .{
                        .expand = .horizontal,
                    });
                    defer dialog_btns.deinit();

                    if (dvui.button(@src(), "Create", .{}, .{ .color_fill = .blue })) {
                        if (name.len > 0) {
                            fs.createProject(app_allocator, name) catch |err| {
                                std.log.err("Create project failed: {}", .{err});
                            };
                            const duped = app_allocator.dupe(u8, name) catch unreachable;
                            state.projects.insert(app_allocator, 0, .{
                                .name = duped,
                                .mtime = std.time.nanoTimestamp(),
                            }) catch unreachable;
                        }
                        state.new_project_dialog = false;
                    }

                    var spacer2 = dvui.box(@src(), .{}, .{ .expand = .horizontal });
                    spacer2.deinit();

                    if (dvui.button(@src(), "Cancel", .{}, .{})) {
                        state.new_project_dialog = false;
                    }
                }
            }
        },
    }
    return .ok;
}

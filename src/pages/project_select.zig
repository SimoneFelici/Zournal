const std = @import("std");
const dvui = @import("dvui");
const state = @import("../states.zig");
const fs = @import("../fs_utils.zig");
const db_utils = @import("../db_utils.zig");

pub fn render(page: *state.PageState, allocator: std.mem.Allocator) !void {
    var s = &page.project_select;

    if (!s.loaded)
        try s.fetchProjects(allocator);

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

    // Project List
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .horizontal,
            .max_size_content = .{ .w = 9999, .h = 250 },
            .corner_radius = dvui.Rect.all(3),
        });
        defer scroll.deinit();

        for (s.projects.items, 0..) |entry, i| {
            if (dvui.button(@src(), entry.name, .{ .draw_focus = false }, .{
                .id_extra = i,
                .expand = .horizontal,
                .corner_radius = dvui.Rect.all(2),
            })) {
                const db_path = fs.getProjectPath(allocator, entry.name) catch |err| {
                    std.log.err("Failed to get DB path: {}", .{err});
                    continue;
                };
                defer allocator.free(db_path);

                const database = db_utils.Database.open(db_path) catch |err| {
                    std.log.err("Failed to open DB: {}", .{err});
                    continue;
                };

                page.* = .{ .project_view = .{ .name = entry.name, .db = database } };
                return;
            }
        }
    }

    // Import and New
    {
        var btn_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer btn_row.deinit();

        if (dvui.button(@src(), "Import", .{ .draw_focus = false }, .{ .color_fill = .green, .gravity_x = 0 })) {
            if (try dvui.native_dialogs.Native.openMultiple(allocator, .{ .title = "Import .db files" })) |paths| {
                defer allocator.free(paths);
                for (paths) |path| {
                    fs.importProject(allocator, path) catch |err| {
                        std.log.err("Import failed: {}", .{err});
                        continue;
                    };
                    const stem = std.fs.path.stem(path);
                    const name = allocator.dupe(u8, stem) catch unreachable;
                    s.projects.insert(allocator, 0, .{
                        .name = name,
                        .mtime = std.time.nanoTimestamp(),
                    }) catch unreachable;
                }
            }
        }

        if (!s.new_project_dialog) {
            if (dvui.button(@src(), "New Project", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 1 })) {
                s.new_project_dialog = true;
            }
        }
    }

    // New Project Dialog
    if (s.new_project_dialog) {
        var te = dvui.textEntry(@src(), .{}, .{ .expand = .horizontal });
        const name = te.getText();
        te.deinit();

        {
            var dialog_btns = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
            });
            defer dialog_btns.deinit();

            if (dvui.button(@src(), "Cancel", .{ .draw_focus = false }, .{ .gravity_x = 0 })) {
                s.new_project_dialog = false;
            }

            if (dvui.button(@src(), "Create", .{ .draw_focus = false }, .{ .color_fill = .blue, .gravity_x = 1 })) {
                if (name.len > 0) {
                    fs.createProject(allocator, name) catch |err| {
                        if (err == error.PathAlreadyExists) {
                            dvui.dialog(@src(), .{}, .{
                                .title = "Error",
                                .message = "Project already exists.",
                            });
                        } else {
                            std.log.err("Create project failed: {}", .{err});
                        }
                        return;
                    };
                    const duped = allocator.dupe(u8, name) catch unreachable;
                    s.projects.insert(allocator, 0, .{
                        .name = duped,
                        .mtime = std.time.nanoTimestamp(),
                    }) catch unreachable;
                    s.new_project_dialog = false;
                }
            }
        }
    }
}

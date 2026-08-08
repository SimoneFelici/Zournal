const std = @import("std");
const state = @import("../states.zig");
const notes_view = @import("../ui/notes_view.zig");

pub fn render(page: *state.PageState) !void {
    var s = &page.project_view;
    try notes_view.render(&s.notes, s.db, s.allocator());
}

const std = @import("std");
const state = @import("states.zig");

pub const AppContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: std.process.Environ.Map,
    page: state.PageState,
};

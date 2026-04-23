const std = @import("std");

pub const AppContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: std.process.Environ.Map,
};

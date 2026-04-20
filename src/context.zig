const std = @include("std");

pub const AppContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
};

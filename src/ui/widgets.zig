const std = @import("std");

// Substring search
pub fn matches(text: []const u8, query: []const u8) bool {
    return query.len == 0 or std.ascii.findIgnoreCase(text, query) != null;
}

const std = @import("std");

pub fn colsFor(available_width: f32, min_item_width: f32) usize {
    if (available_width <= 0 or min_item_width <= 0) return 1;
    const n: usize = @intFromFloat(@floor(available_width / min_item_width));
    return @max(1, n);
}

const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

const schema = @embedFile("db/Zournal.sql");

pub fn initDatabase(path: []const u8) !void {
    var db: ?*c.sqlite3 = null;
    if (c.sqlite3_open(path.ptr, &db) != c.SQLITE_OK) {
        return error.DatabaseOpenFailed;
    }
    defer _ = c.sqlite3_close(db);

    if (c.sqlite3_exec(db, schema.ptr, null, null, null) != c.SQLITE_OK) {
        return error.SchemaInitFailed;
    }
}

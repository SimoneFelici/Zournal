const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});
const zqlite = @import("zqlite");
const types = @import("types.zig");

const schema = @embedFile("db/Zournal.sql");

pub const Database = struct {
    handle: *c.sqlite3,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Database {
        const c_path = try allocator.dupeZ(u8, path);
        defer allocator.free(c_path);

        var db: ?*c.sqlite3 = null;
        if (c.sqlite3_open(c_path.ptr, &db) != c.SQLITE_OK) {
            return error.DatabaseOpenFailed;
        }

        if (c.sqlite3_exec(db, "PRAGMA foreign_keys = ON;", null, null, null) != c.SQLITE_OK) {
            _ = c.sqlite3_close(db);
            return error.DatabaseConfigFailed;
        }

        return .{ .handle = db.? };
    }

    pub fn close(self: Database) void {
        _ = c.sqlite3_close(self.handle);
    }

    pub fn initSchema(self: Database) !void {
        if (c.sqlite3_exec(self.handle, schema.ptr, null, null, null) != c.SQLITE_OK) {
            return error.SchemaInitFailed;
        }
    }

    pub fn listCases(self: Database, allocator: std.mem.Allocator) !std.ArrayList(types.CaseEntry) {
        var stmt: ?*c.sqlite3_stmt = null;
        const sql = "SELECT id, c_name FROM Cases ORDER BY last_access DESC";

        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) {
            return error.QueryFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        var cases: std.ArrayList(types.CaseEntry) = .{};
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const id = c.sqlite3_column_int64(stmt, 0);
            const name_ptr = c.sqlite3_column_text(stmt, 1);
            const name_len: usize = @intCast(c.sqlite3_column_bytes(stmt, 1));

            if (name_ptr == null) continue;

            const name = try allocator.dupe(u8, name_ptr[0..name_len]);
            try cases.append(allocator, .{ .id = id, .name = name });
        }

        return cases;
    }

    pub fn createCase(self: Database, allocator: std.mem.Allocator, name: []const u8) !i64 {
        var stmt: ?*c.sqlite3_stmt = null;
        const sql = "INSERT INTO Cases (c_name) VALUES (?)";

        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) {
            return error.QueryFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        const c_name = try allocator.dupeZ(u8, name);
        defer allocator.free(c_name);

        if (c.sqlite3_bind_text(stmt, 1, c_name.ptr, @intCast(name.len), null) != c.SQLITE_OK) {
            return error.BindFailed;
        }

        if (c.sqlite3_step(stmt) != c.SQLITE_DONE) {
            return error.InsertFailed;
        }

        return c.sqlite3_last_insert_rowid(self.handle);
    }

    pub fn countCases(self: Database) !i64 {
        var stmt: ?*c.sqlite3_stmt = null;
        const sql = "SELECT COUNT(*) FROM Cases";

        if (c.sqlite3_prepare_v2(self.handle, sql, -1, &stmt, null) != c.SQLITE_OK) {
            return error.QueryFailed;
        }
        defer _ = c.sqlite3_finalize(stmt);

        if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            return c.sqlite3_column_int64(stmt, 0);
        }
        return 0;
    }
};

pub fn initDatabase(allocator: std.mem.Allocator, path: []const u8) !void {
    var db = try Database.open(allocator, path);
    defer db.close();
    try db.initSchema();
}

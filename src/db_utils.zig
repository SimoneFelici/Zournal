const std = @import("std");
const zqlite = @import("zqlite");
const types = @import("types.zig");

const schema = @embedFile("db/Zournal.sql");

pub const Database = struct {
    conn: zqlite.Conn,

    // Project
    pub fn open(path: [:0]const u8) !Database {
        const conn = zqlite.open(path, zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode) catch return error.DatabaseOpenFailed;
        conn.execNoArgs("PRAGMA foreign_keys = ON") catch return error.DatabaseConfigFailed;
        return .{ .conn = conn };
    }

    pub fn close(self: Database) void {
        self.conn.close();
    }

    pub fn initSchema(self: Database) !void {
        self.conn.execNoArgs(schema) catch return error.SchemaInitFailed;
    }

    // Cases
    pub fn listCases(self: Database, allocator: std.mem.Allocator) !std.ArrayList(types.CaseEntry) {
        var cases: std.ArrayList(types.CaseEntry) = .{};

        var rows = self.conn.rows("SELECT id, c_name FROM Cases ORDER BY last_access DESC", .{}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const name = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            cases.append(allocator, .{ .id = id, .name = name }) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return cases;
    }

    pub fn createCase(self: Database) !i64 {
        self.conn.exec("INSERT INTO Cases (c_name) VALUES ('')", .{}) catch return error.InsertFailed;
        return self.conn.lastInsertedRowId();
    }

    // People
    pub fn listPeople(self: Database, allocator: std.mem.Allocator) !std.ArrayList(types.PersonEntry) {
        var people: std.ArrayList(types.PersonEntry) = .{};

        var rows = self.conn.rows("SELECT id, p_name FROM People ORDER BY p_name ASC", .{}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const name = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            people.append(allocator, .{ .id = id, .name = name }) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return people;
    }

    pub fn createPerson(self: Database, name: []const u8) !i64 {
        self.conn.exec("INSERT INTO People (p_name) VALUES (?)", .{name}) catch return error.InsertFailed;
        return self.conn.lastInsertedRowId();
    }

    pub fn updatePerson(self: Database, id: i64, name: []const u8) !void {
        self.conn.exec("UPDATE People SET p_name = ? WHERE id = ?", .{ name, id }) catch return error.UpdateFailed;
    }

    pub fn deletePerson(self: Database, id: i64) !void {
        self.conn.exec("DELETE FROM People WHERE id = ?", .{id}) catch return error.DeleteFailed;
    }
};

pub fn initDatabase(path: [:0]const u8) !void {
    var db = try Database.open(path);
    defer db.close();
    try db.initSchema();
}

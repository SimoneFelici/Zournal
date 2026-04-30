const std = @import("std");
const zqlite = @import("zqlite");
const types = @import("types.zig");

const schema = @embedFile("db/Zournal.sql");

pub const Database = struct {
    conn: zqlite.Conn,

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
        var cases: std.ArrayList(types.CaseEntry) = .empty;

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
        var people: std.ArrayList(types.PersonEntry) = .empty;

        var rows = self.conn.rows("SELECT id, p_name FROM People ORDER BY p_name ASC", .{}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const name = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            var entry = types.PersonEntry{ .id = id, .name = name };
            entry.computeInitials();
            people.append(allocator, entry) catch return error.OutOfMemory;
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

    // People (case-scoped)
    pub fn listPeopleForCase(self: Database, case_id: i64, allocator: std.mem.Allocator) !std.ArrayList(types.PersonEntry) {
        var people: std.ArrayList(types.PersonEntry) = .empty;

        var rows = self.conn.rows(
            "SELECT p.id, p.p_name FROM People p JOIN People_Cases pc ON pc.people_id = p.id WHERE pc.case_id = ? ORDER BY p.p_name ASC",
            .{case_id},
        ) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const name = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            var entry = types.PersonEntry{ .id = id, .name = name };
            entry.computeInitials();
            people.append(allocator, entry) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return people;
    }

    pub fn createPersonInCase(self: Database, name: []const u8, case_id: i64) !i64 {
        self.conn.exec("INSERT INTO People (p_name) VALUES (?)", .{name}) catch return error.InsertFailed;
        const id = self.conn.lastInsertedRowId();
        self.conn.exec("INSERT INTO People_Cases (people_id, case_id) VALUES (?, ?)", .{ id, case_id }) catch return error.InsertFailed;
        return id;
    }

    pub fn linkPersonToCase(self: Database, person_id: i64, case_id: i64) !void {
        self.conn.exec("INSERT OR IGNORE INTO People_Cases (people_id, case_id) VALUES (?, ?)", .{ person_id, case_id }) catch return error.InsertFailed;
    }

    // Notes
    pub fn listNotes(self: Database, allocator: std.mem.Allocator) !std.ArrayList(types.NoteEntry) {
        var notes: std.ArrayList(types.NoteEntry) = .empty;

        var rows = self.conn.rows("SELECT id, title, content FROM Notes ORDER BY id DESC", .{}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const title = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            const content = allocator.dupe(u8, row.text(2)) catch return error.OutOfMemory;
            notes.append(allocator, .{ .id = id, .title = title, .content = content }) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return notes;
    }

    pub fn createNote(self: Database, title: []const u8) !i64 {
        self.conn.exec("INSERT INTO Notes (title, content) VALUES (?, '')", .{title}) catch return error.InsertFailed;
        return self.conn.lastInsertedRowId();
    }

    pub fn listNotesForCase(self: Database, case_id: i64, allocator: std.mem.Allocator) !std.ArrayList(types.NoteEntry) {
        var notes: std.ArrayList(types.NoteEntry) = .empty;

        var rows = self.conn.rows("SELECT id, title, content FROM Notes WHERE case_id = ? ORDER BY id DESC", .{case_id}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const title = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            const content = allocator.dupe(u8, row.text(2)) catch return error.OutOfMemory;
            notes.append(allocator, .{ .id = id, .title = title, .content = content }) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return notes;
    }

    pub fn createNoteForCase(self: Database, title: []const u8, case_id: i64) !i64 {
        self.conn.exec("INSERT INTO Notes (title, content, case_id) VALUES (?, '', ?)", .{ title, case_id }) catch return error.InsertFailed;
        return self.conn.lastInsertedRowId();
    }

    pub fn updateNoteTitle(self: Database, id: i64, title: []const u8) !void {
        self.conn.exec("UPDATE Notes SET title = ? WHERE id = ?", .{ title, id }) catch return error.UpdateFailed;
    }

    pub fn updateNoteContent(self: Database, id: i64, content: []const u8) !void {
        self.conn.exec("UPDATE Notes SET content = ? WHERE id = ?", .{ content, id }) catch return error.UpdateFailed;
    }

    pub fn deleteNote(self: Database, id: i64) !void {
        self.conn.exec("DELETE FROM Notes WHERE id = ?", .{id}) catch return error.DeleteFailed;
    }

    // Person notes
    pub fn listPersonNotes(self: Database, person_id: i64, allocator: std.mem.Allocator) !std.ArrayList(types.NoteEntry) {
        var notes: std.ArrayList(types.NoteEntry) = .empty;

        var rows = self.conn.rows("SELECT id, title, content FROM Person_Notes WHERE person_id = ? ORDER BY id DESC", .{person_id}) catch return error.QueryFailed;
        defer rows.deinit();

        while (rows.next()) |row| {
            const id = row.int(0);
            const title = allocator.dupe(u8, row.text(1)) catch return error.OutOfMemory;
            const content = allocator.dupe(u8, row.text(2)) catch return error.OutOfMemory;
            notes.append(allocator, .{ .id = id, .title = title, .content = content }) catch return error.OutOfMemory;
        }
        if (rows.err) |err| return err;

        return notes;
    }

    pub fn createPersonNote(self: Database, person_id: i64, title: []const u8) !i64 {
        self.conn.exec("INSERT INTO Person_Notes (person_id, title, content) VALUES (?, ?, '')", .{ person_id, title }) catch return error.InsertFailed;
        return self.conn.lastInsertedRowId();
    }

    pub fn updatePersonNoteContent(self: Database, id: i64, content: []const u8) !void {
        self.conn.exec("UPDATE Person_Notes SET content = ? WHERE id = ?", .{ content, id }) catch return error.UpdateFailed;
    }

    pub fn deletePersonNote(self: Database, id: i64) !void {
        self.conn.exec("DELETE FROM Person_Notes WHERE id = ?", .{id}) catch return error.DeleteFailed;
    }
};

pub fn initDatabase(path: [:0]const u8) !void {
    var db = try Database.open(path);
    defer db.close();
    try db.initSchema();
}

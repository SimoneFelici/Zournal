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

    // Notes
    pub fn listNotes(self: Database, allocator: std.mem.Allocator) !std.ArrayList(types.NoteEntry) {
        var notes: std.ArrayList(types.NoteEntry) = .{};

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

    pub fn updateNoteTitle(self: Database, id: i64, title: []const u8) !void {
        self.conn.exec("UPDATE Notes SET title = ? WHERE id = ?", .{ title, id }) catch return error.UpdateFailed;
    }

    pub fn updateNoteContent(self: Database, id: i64, content: []const u8) !void {
        self.conn.exec("UPDATE Notes SET content = ? WHERE id = ?", .{ content, id }) catch return error.UpdateFailed;
    }

    pub fn deleteNote(self: Database, id: i64) !void {
        self.conn.exec("DELETE FROM Notes WHERE id = ?", .{id}) catch return error.DeleteFailed;
    }

    pub fn linkNotePerson(self: Database, note_id: i64, person_id: i64) !void {
        self.conn.exec("INSERT OR IGNORE INTO Note_People (note_id, person_id) VALUES (?, ?)", .{ note_id, person_id }) catch return error.InsertFailed;
    }

    pub fn unlinkAllNotePeople(self: Database, note_id: i64) !void {
        self.conn.exec("DELETE FROM Note_People WHERE note_id = ?", .{note_id}) catch return error.DeleteFailed;
    }

    pub fn syncNoteMentions(self: Database, allocator: std.mem.Allocator, note_id: i64, content: []const u8) !void {
        self.unlinkAllNotePeople(note_id) catch return;

        var people = self.listPeople(allocator) catch return;
        defer {
            for (people.items) |p| allocator.free(p.name);
            people.deinit(allocator);
        }

        // Scan content for @mentions
        var i: usize = 0;
        while (i < content.len) {
            if (content[i] == '@') {
                const rest = content[i + 1 ..];
                // Try to match against known people names
                for (people.items) |person| {
                    if (rest.len >= person.name.len and
                        std.ascii.eqlIgnoreCase(rest[0..person.name.len], person.name))
                    {
                        self.linkNotePerson(note_id, person.id) catch {};
                        break;
                    }
                }
            }
            i += 1;
        }
    }
};

pub fn initDatabase(path: [:0]const u8) !void {
    var db = try Database.open(path);
    defer db.close();
    try db.initSchema();
}

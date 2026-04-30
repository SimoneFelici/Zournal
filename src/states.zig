const std = @import("std");
const types = @import("types.zig");
const fs = @import("fs_utils.zig");
const db_utils = @import("db_utils.zig");
const AppContext = @import("context.zig").AppContext;

pub const PageState = union(enum) {
    project_select: ProjectSelectState,
    project_view: ProjectViewState,
};

pub const ProjectSelectState = struct {
    projects: std.ArrayList(types.ProjectEntry) = .empty,
    loaded: bool = false,
    new_project_dialog: bool = false,

    pub fn fetchProjects(self: *ProjectSelectState, ctx: *const AppContext) !void {
        if (self.loaded) return;
        self.projects = try fs.listProjects(ctx);
        self.loaded = true;
    }
};

pub const ProjectViewState = struct {
    name: []const u8,
    tab: Tab = .cases,
    db: db_utils.Database,
    cases: std.ArrayList(types.CaseEntry) = .empty,
    people: std.ArrayList(types.PersonEntry) = .empty,
    notes: std.ArrayList(types.NoteEntry) = .empty,
    new_person_dialog: bool = false,
    new_note_dialog: bool = false,
    open_note_id: ?i64 = null,
    case_view: ?CaseViewState = null,
    person_view: ?PersonViewState = null,

    pub const Tab = enum {
        cases,
        timeline,
        people,
        relationships,
        notes,
    };

    pub fn loadAll(self: *ProjectViewState, allocator: std.mem.Allocator) !void {
        self.cases = try self.db.listCases(allocator);
        self.people = try self.db.listPeople(allocator);
        self.notes = try self.db.listNotes(allocator);
    }
};

pub const PersonViewState = struct {
    person_id: i64,
    person_name: []const u8,
    person_initials: [2]u8 = .{ 0, 0 },
    person_initials_len: u2 = 0,
    notes: std.ArrayList(types.NoteEntry) = .empty,
    open_note_id: ?i64 = null,
    new_note_dialog: bool = false,
    loaded: bool = false,

    pub fn load(self: *PersonViewState, db: db_utils.Database, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.notes = try db.listPersonNotes(self.person_id, allocator);
        self.loaded = true;
    }
};

pub const CaseViewState = struct {
    case_id: i64,
    case_name: []const u8,
    tab: Tab = .people,
    people: std.ArrayList(types.PersonEntry) = .empty,
    notes: std.ArrayList(types.NoteEntry) = .empty,
    new_person_dialog: bool = false,
    import_person_dialog: bool = false,
    new_note_dialog: bool = false,
    open_note_id: ?i64 = null,
    person_view: ?PersonViewState = null,
    loaded: bool = false,

    pub const Tab = enum { people, notes, timeline };

    pub fn load(self: *CaseViewState, db: db_utils.Database, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.people = try db.listPeopleForCase(self.case_id, allocator);
        self.notes = try db.listNotesForCase(self.case_id, allocator);
        self.loaded = true;
    }
};

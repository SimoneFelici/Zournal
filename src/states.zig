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
    arena: std.heap.ArenaAllocator,

    projects: std.ArrayList(types.ProjectEntry) = .empty,
    loaded: bool = false,
    new_project_dialog: bool = false,

    pub fn init(parent_allocator: std.mem.Allocator) ProjectSelectState {
        return .{
            .arena = std.heap.ArenaAllocator.init(parent_allocator),
        };
    }

    pub fn allocator(self: *ProjectSelectState) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn deinit(self: *ProjectSelectState) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn fetchProjects(self: *ProjectSelectState, ctx: *const AppContext) !void {
        if (self.loaded) return;

        var arena_ctx = ctx.*;
        arena_ctx.allocator = self.allocator();

        self.projects = try fs.listProjects(&arena_ctx);
        self.loaded = true;
    }
};

pub const ProjectViewState = struct {
    arena: std.heap.ArenaAllocator,

    name: []const u8,
    tab: Tab = .cases,
    db: db_utils.Database,

    cases: std.ArrayList(types.CaseEntry) = .empty,
    people: std.ArrayList(types.PersonEntry) = .empty,
    notes: std.ArrayList(types.NoteEntry) = .empty,

    new_person_dialog: bool = false,
    new_note_dialog: bool = false,
    open_notes: std.ArrayList(i64) = .empty,

    case_view: ?CaseViewState = null,
    person_view: ?PersonViewState = null,
    relationships: RelationshipsState = .{},

    pub const Tab = enum {
        cases,
        people,
        relationships,
        notes,
    };

    pub fn init(
        parent_allocator: std.mem.Allocator,
        project_name: []const u8,
        db: db_utils.Database,
    ) !ProjectViewState {
        var self: ProjectViewState = .{
            .arena = std.heap.ArenaAllocator.init(parent_allocator),
            .name = undefined,
            .db = db,
        };

        errdefer self.arena.deinit();

        self.name = try self.allocator().dupe(u8, project_name);

        return self;
    }

    pub fn allocator(self: *ProjectViewState) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn deinit(self: *ProjectViewState) void {
        self.db.close();
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn loadAll(self: *ProjectViewState) !void {
        const a = self.allocator();

        self.cases = try self.db.listCases(a);
        self.people = try self.db.listPeople(a);
        self.notes = try self.db.listNotes(a);
        try self.relationships.load(self.db, self.people.items, a);
    }
};

pub const PersonViewState = struct {
    person_id: i64,
    person_name: []const u8,
    person_initials: [2]u8 = .{ 0, 0 },
    person_initials_len: u2 = 0,
    notes: std.ArrayList(types.NoteEntry) = .empty,
    open_notes: std.ArrayList(i64) = .empty,
    new_note_dialog: bool = false,
    edit_name_dialog: bool = false,
    delete_person_confirm: bool = false,
    loaded: bool = false,

    pub fn load(self: *PersonViewState, db: db_utils.Database, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.notes = try db.listPersonNotes(self.person_id, allocator);
        self.loaded = true;
    }
};

pub const RelationshipsState = struct {
    relationships: std.ArrayList(types.RelationshipEntry) = .empty,
    positions: std.ArrayList(types.NodePos) = .empty,
    selected_id: ?i64 = null,
    connect_target_id: ?i64 = null,
    dragging_id: ?i64 = null,
    confirm_delete_conn_id: ?i64 = null,
    loaded: bool = false,

    pub fn load(self: *RelationshipsState, db: db_utils.Database, people: []const types.PersonEntry, allocator: std.mem.Allocator) !void {
        if (!self.loaded) {
            self.relationships = try db.listRelationships(allocator);
            self.positions = try db.listNodePositions(allocator);
            self.loaded = true;
        }
        for (people, 0..) |person, i| {
            const has = for (self.positions.items) |p| {
                if (p.person_id == person.id) break true;
            } else false;
            if (!has) {
                const n = @as(f32, @floatFromInt(if (people.len > 0) people.len else 1));
                const angle = @as(f32, @floatFromInt(i)) * 2.0 * std.math.pi / n;
                const x = 250.0 + 200.0 * @cos(angle);
                const y = 250.0 + 200.0 * @sin(angle);
                self.positions.append(allocator, .{ .person_id = person.id, .x = x, .y = y }) catch return error.OutOfMemory;
            }
        }
    }
};

pub const TimelineState = struct {
    events: std.ArrayList(types.TimelineEvent) = .empty,
    connections: std.ArrayList(types.EventConnection) = .empty,
    selected_id: ?i64 = null,
    connect_target_id: ?i64 = null,
    dragging_id: ?i64 = null,
    editing_id: ?i64 = null,
    confirm_delete_conn_id: ?i64 = null,
    new_event_dialog: bool = false,
    loaded: bool = false,

    pub fn load(self: *TimelineState, db: db_utils.Database, case_id: i64, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.events = try db.listTimelineEventsForCase(case_id, allocator);
        self.connections = try db.listEventConnectionsForCase(case_id, allocator);
        self.loaded = true;
    }
};

pub const CaseViewState = struct {
    case_id: i64,
    case_name: []const u8,
    tab: Tab = .people,
    people: std.ArrayList(types.PersonEntry) = .empty,
    notes: std.ArrayList(types.NoteEntry) = .empty,
    timeline: TimelineState = .{},
    new_person_dialog: bool = false,
    import_person_dialog: bool = false,
    new_note_dialog: bool = false,
    rename_dialog: bool = false,
    delete_case_confirm: bool = false,
    open_notes: std.ArrayList(i64) = .empty,
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

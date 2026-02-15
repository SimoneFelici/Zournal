const std = @import("std");
const types = @import("types.zig");
const fs = @import("fs_utils.zig");
const db_utils = @import("db_utils.zig");

pub const PageState = union(enum) {
    project_select: ProjectSelectState,
    project_view: ProjectViewState,
};

pub const ProjectSelectState = struct {
    projects: std.ArrayList(types.ProjectEntry) = .{},
    loaded: bool = false,
    new_project_dialog: bool = false,

    pub fn fetchProjects(self: *ProjectSelectState, allocator: std.mem.Allocator) !void {
        if (self.loaded) return;
        self.projects = try fs.listProjects(allocator);
        self.loaded = true;
    }
};

pub const ProjectViewState = struct {
    name: []const u8,
    tab: Tab = .cases,
    db: db_utils.Database,
    cases: std.ArrayList(types.CaseEntry) = .{},
    cases_loaded: bool = false,
    people: std.ArrayList(types.PersonEntry) = .{},
    people_loaded: bool = false,
    new_person_dialog: bool = false,

    pub const Tab = enum {
        cases,
        timeline,
        people,
        relationships,
        notes,
    };

    pub fn loadCases(self: *ProjectViewState, allocator: std.mem.Allocator) !void {
        if (self.cases_loaded) return;
        self.cases = try self.db.listCases(allocator);
        self.cases_loaded = true;
    }

    pub fn loadPeople(self: *ProjectViewState, allocator: std.mem.Allocator) !void {
        if (self.people_loaded) return;
        self.people = try self.db.listPeople(allocator);
        self.people_loaded = true;
    }
};

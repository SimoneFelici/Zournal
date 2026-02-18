CREATE TABLE IF NOT EXISTS "Cases" (
	"id" INTEGER NOT NULL UNIQUE,
	"c_name" TEXT NOT NULL UNIQUE DEFAULT '',
	"last_access" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now')),
	PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "People" (
	"id" INTEGER NOT NULL UNIQUE,
	"p_name" TEXT NOT NULL,
	PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "Relationships_Types" (
	"id" INTEGER NOT NULL UNIQUE,
	"rel_name" TEXT NOT NULL UNIQUE,
	PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "People_Cases" (
	"id" INTEGER NOT NULL UNIQUE,
	"people_id" INTEGER NOT NULL,
	"case_id" INTEGER NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY ("case_id") REFERENCES "Cases"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("people_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "People_Cases_index_0"
ON "People_Cases" ("people_id", "case_id");

CREATE TABLE IF NOT EXISTS "Relationships" (
	"id" INTEGER NOT NULL UNIQUE,
	"person1_id" INTEGER NOT NULL,
	"person2_id" INTEGER NOT NULL,
	"type_id" INTEGER NOT NULL,
	"is_mutual" INTEGER NOT NULL CHECK ("is_mutual" IN (0, 1)),
	PRIMARY KEY("id"),
	FOREIGN KEY ("person1_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("person2_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("type_id") REFERENCES "Relationships_Types"("id")
		ON UPDATE NO ACTION ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS "Relationships_unique"
ON "Relationships" ("person1_id", "person2_id", "type_id");

CREATE INDEX IF NOT EXISTS "Relationships_person1"
ON "Relationships" ("person1_id");

CREATE INDEX IF NOT EXISTS "Relationships_person2"
ON "Relationships" ("person2_id");

CREATE TABLE IF NOT EXISTS "Notes" (
	"id" INTEGER NOT NULL UNIQUE,
	"case_id" INTEGER,
	"title" TEXT NOT NULL DEFAULT 'Untitled',
	"content" TEXT NOT NULL DEFAULT '',
	PRIMARY KEY("id"),
	FOREIGN KEY ("case_id") REFERENCES "Cases"("id")
		ON UPDATE NO ACTION ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS "Notes_case"
ON "Notes" ("case_id");

CREATE TABLE IF NOT EXISTS "Note_People" (
	"id" INTEGER NOT NULL UNIQUE,
	"note_id" INTEGER NOT NULL,
	"person_id" INTEGER NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY ("note_id") REFERENCES "Notes"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("person_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "Note_People_index_0"
ON "Note_People" ("note_id", "person_id");

CREATE TABLE IF NOT EXISTS "Timeline_Events" (
	"id" INTEGER NOT NULL UNIQUE,
	"case_id" INTEGER NOT NULL,
	"label" TEXT,
	"content" TEXT NOT NULL,
	"position_x" REAL NOT NULL,
	"position_y" REAL NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY ("case_id") REFERENCES "Cases"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "Timeline_Events_case"
ON "Timeline_Events" ("case_id");

CREATE TABLE IF NOT EXISTS "Event_People" (
	"id" INTEGER NOT NULL UNIQUE,
	"event_id" INTEGER NOT NULL,
	"person_id" INTEGER NOT NULL,
	PRIMARY KEY("id"),
	FOREIGN KEY ("event_id") REFERENCES "Timeline_Events"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("person_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "Event_People_index_0"
ON "Event_People" ("event_id", "person_id");

CREATE TABLE IF NOT EXISTS "Event_Connections" (
	"id" INTEGER NOT NULL UNIQUE,
	"from_id" INTEGER NOT NULL,
	"to_id" INTEGER NOT NULL,
	"connection_type" TEXT,
	PRIMARY KEY("id"),
	FOREIGN KEY ("from_id") REFERENCES "Timeline_Events"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("to_id") REFERENCES "Timeline_Events"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "Event_Connections_unique"
ON "Event_Connections" ("from_id", "to_id");

CREATE INDEX IF NOT EXISTS "Event_Connections_from"
ON "Event_Connections" ("from_id");

CREATE INDEX IF NOT EXISTS "Event_Connections_to"
ON "Event_Connections" ("to_id");

CREATE TRIGGER IF NOT EXISTS "auto_case_name"
AFTER INSERT ON "Cases"
WHEN NEW.c_name = ''
BEGIN
    UPDATE Cases SET c_name = 'Case #' || NEW.id WHERE id = NEW.id;
END;

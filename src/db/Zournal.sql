CREATE TABLE IF NOT EXISTS "Cases" (
	"id" INTEGER NOT NULL UNIQUE,
	"c_name" TEXT NOT NULL UNIQUE DEFAULT '',
	"last_access" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now')),
	PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "People" (
	"id" INTEGER NOT NULL UNIQUE,
	"p_name" TEXT NOT NULL,
	"color" INTEGER NOT NULL DEFAULT 0,
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

CREATE TABLE IF NOT EXISTS "Notes" (
	"id" INTEGER NOT NULL UNIQUE,
	"case_id" INTEGER,
	"title" TEXT NOT NULL DEFAULT 'Untitled',
	"content" TEXT NOT NULL DEFAULT '',
	"created_at" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now')),
	"updated_at" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now')),
	PRIMARY KEY("id"),
	FOREIGN KEY ("case_id") REFERENCES "Cases"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "Notes_case"
ON "Notes" ("case_id");

CREATE INDEX IF NOT EXISTS "Notes_updated"
ON "Notes" ("updated_at" DESC);

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

CREATE INDEX IF NOT EXISTS "Note_People_person"
ON "Note_People" ("person_id");

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

CREATE TABLE IF NOT EXISTS "Person_Relationships" (
	"id" INTEGER NOT NULL UNIQUE,
	"person_a_id" INTEGER NOT NULL,
	"person_b_id" INTEGER NOT NULL,
	"label" TEXT NOT NULL DEFAULT '',
	PRIMARY KEY("id"),
	FOREIGN KEY ("person_a_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE,
	FOREIGN KEY ("person_b_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "Person_Relationships_unique"
ON "Person_Relationships" ("person_a_id", "person_b_id");

CREATE TABLE IF NOT EXISTS "Person_Positions" (
	"person_id" INTEGER NOT NULL UNIQUE,
	"x" REAL NOT NULL DEFAULT 0,
	"y" REAL NOT NULL DEFAULT 0,
	PRIMARY KEY("person_id"),
	FOREIGN KEY ("person_id") REFERENCES "People"("id")
		ON UPDATE NO ACTION ON DELETE CASCADE
);

CREATE TRIGGER IF NOT EXISTS "auto_case_name"
AFTER INSERT ON "Cases"
WHEN NEW.c_name = ''
BEGIN
    UPDATE Cases SET c_name = 'Case #' || NEW.id WHERE id = NEW.id;
END;

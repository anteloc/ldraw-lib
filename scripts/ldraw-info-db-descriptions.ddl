PRAGMA trusted_schema = ON;
PRAGMA foreign_keys = ON;


-- ============================================================
-- Drop existing triggers
-- ============================================================

DROP TRIGGER IF EXISTS MODELS_DESCRIPTIONS_AI;
DROP TRIGGER IF EXISTS MODELS_DESCRIPTIONS_AD;
DROP TRIGGER IF EXISTS MODELS_DESCRIPTIONS_AU;

DROP TRIGGER IF EXISTS SUBMODELS_DESCRIPTIONS_AI;
DROP TRIGGER IF EXISTS SUBMODELS_DESCRIPTIONS_AD;
DROP TRIGGER IF EXISTS SUBMODELS_DESCRIPTIONS_AU;

DROP TRIGGER IF EXISTS PARTS_DESCRIPTIONS_AI;
DROP TRIGGER IF EXISTS PARTS_DESCRIPTIONS_AD;
DROP TRIGGER IF EXISTS PARTS_DESCRIPTIONS_AU;


-- ============================================================
-- Drop existing FTS5 virtual tables
-- ============================================================

DROP TABLE IF EXISTS MODELS_DESCRIPTIONS_FTS;
DROP TABLE IF EXISTS SUBMODELS_DESCRIPTIONS_FTS;
DROP TABLE IF EXISTS PARTS_DESCRIPTIONS_FTS;


-- ============================================================
-- Drop existing relational tables
--
-- SUBMODELS_DESCRIPTIONS must be dropped before
-- MODELS_DESCRIPTIONS because of the foreign key.
-- ============================================================

DROP TABLE IF EXISTS SUBMODELS_DESCRIPTIONS;
DROP TABLE IF EXISTS MODELS_DESCRIPTIONS;
DROP TABLE IF EXISTS PARTS_DESCRIPTIONS;


-- ============================================================
-- Authoritative relational tables
-- ============================================================

CREATE TABLE MODELS_DESCRIPTIONS (
    alias       VARCHAR NOT NULL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE SUBMODELS_DESCRIPTIONS (
    submodel    VARCHAR NOT NULL,
    alias       VARCHAR NOT NULL,
    description TEXT NOT NULL,

    PRIMARY KEY (submodel, alias),

    FOREIGN KEY (alias)
        REFERENCES MODELS_DESCRIPTIONS(alias)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE PARTS_DESCRIPTIONS (
    alias       VARCHAR NOT NULL PRIMARY KEY,
    description TEXT NOT NULL
);


-- ============================================================
-- FTS5 external-content indexes
--
-- Identifier columns are UNINDEXED so they are returned as
-- metadata but do not participate in MATCH.
--
-- Only "description" is full-text indexed.
-- ============================================================

CREATE VIRTUAL TABLE MODELS_DESCRIPTIONS_FTS USING fts5(
    alias UNINDEXED,
    description,
    content='MODELS_DESCRIPTIONS',
    content_rowid='rowid'
);

CREATE VIRTUAL TABLE SUBMODELS_DESCRIPTIONS_FTS USING fts5(
    submodel UNINDEXED,
    alias UNINDEXED,
    description,
    content='SUBMODELS_DESCRIPTIONS',
    content_rowid='rowid'
);

CREATE VIRTUAL TABLE PARTS_DESCRIPTIONS_FTS USING fts5(
    alias UNINDEXED,
    description,
    content='PARTS_DESCRIPTIONS',
    content_rowid='rowid'
);


-- ============================================================
-- MODELS_DESCRIPTIONS synchronization triggers
-- ============================================================

CREATE TRIGGER MODELS_DESCRIPTIONS_AI
AFTER INSERT ON MODELS_DESCRIPTIONS
BEGIN
    INSERT INTO MODELS_DESCRIPTIONS_FTS (
        rowid,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.alias,
        new.description
    );
END;

CREATE TRIGGER MODELS_DESCRIPTIONS_AD
AFTER DELETE ON MODELS_DESCRIPTIONS
BEGIN
    INSERT INTO MODELS_DESCRIPTIONS_FTS (
        MODELS_DESCRIPTIONS_FTS,
        rowid,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.alias,
        old.description
    );
END;

CREATE TRIGGER MODELS_DESCRIPTIONS_AU
AFTER UPDATE ON MODELS_DESCRIPTIONS
BEGIN
    INSERT INTO MODELS_DESCRIPTIONS_FTS (
        MODELS_DESCRIPTIONS_FTS,
        rowid,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.alias,
        old.description
    );

    INSERT INTO MODELS_DESCRIPTIONS_FTS (
        rowid,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.alias,
        new.description
    );
END;


-- ============================================================
-- SUBMODELS_DESCRIPTIONS synchronization triggers
-- ============================================================

CREATE TRIGGER SUBMODELS_DESCRIPTIONS_AI
AFTER INSERT ON SUBMODELS_DESCRIPTIONS
BEGIN
    INSERT INTO SUBMODELS_DESCRIPTIONS_FTS (
        rowid,
        submodel,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.submodel,
        new.alias,
        new.description
    );
END;

CREATE TRIGGER SUBMODELS_DESCRIPTIONS_AD
AFTER DELETE ON SUBMODELS_DESCRIPTIONS
BEGIN
    INSERT INTO SUBMODELS_DESCRIPTIONS_FTS (
        SUBMODELS_DESCRIPTIONS_FTS,
        rowid,
        submodel,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.submodel,
        old.alias,
        old.description
    );
END;

CREATE TRIGGER SUBMODELS_DESCRIPTIONS_AU
AFTER UPDATE ON SUBMODELS_DESCRIPTIONS
BEGIN
    INSERT INTO SUBMODELS_DESCRIPTIONS_FTS (
        SUBMODELS_DESCRIPTIONS_FTS,
        rowid,
        submodel,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.submodel,
        old.alias,
        old.description
    );

    INSERT INTO SUBMODELS_DESCRIPTIONS_FTS (
        rowid,
        submodel,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.submodel,
        new.alias,
        new.description
    );
END;


-- ============================================================
-- PARTS_DESCRIPTIONS synchronization triggers
-- ============================================================

CREATE TRIGGER PARTS_DESCRIPTIONS_AI
AFTER INSERT ON PARTS_DESCRIPTIONS
BEGIN
    INSERT INTO PARTS_DESCRIPTIONS_FTS (
        rowid,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.alias,
        new.description
    );
END;

CREATE TRIGGER PARTS_DESCRIPTIONS_AD
AFTER DELETE ON PARTS_DESCRIPTIONS
BEGIN
    INSERT INTO PARTS_DESCRIPTIONS_FTS (
        PARTS_DESCRIPTIONS_FTS,
        rowid,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.alias,
        old.description
    );
END;

CREATE TRIGGER PARTS_DESCRIPTIONS_AU
AFTER UPDATE ON PARTS_DESCRIPTIONS
BEGIN
    INSERT INTO PARTS_DESCRIPTIONS_FTS (
        PARTS_DESCRIPTIONS_FTS,
        rowid,
        alias,
        description
    )
    VALUES (
        'delete',
        old.rowid,
        old.alias,
        old.description
    );

    INSERT INTO PARTS_DESCRIPTIONS_FTS (
        rowid,
        alias,
        description
    )
    VALUES (
        new.rowid,
        new.alias,
        new.description
    );
END;


-- ============================================================
-- Search query templates
-- ============================================================

-- Models:
--
-- SELECT alias, description
-- FROM MODELS_DESCRIPTIONS_FTS
-- WHERE MODELS_DESCRIPTIONS_FTS MATCH ?
-- ORDER BY rank;


-- Submodels:
--
-- SELECT submodel, alias, description
-- FROM SUBMODELS_DESCRIPTIONS_FTS
-- WHERE SUBMODELS_DESCRIPTIONS_FTS MATCH ?
-- ORDER BY rank;


-- Parts:
--
-- SELECT alias, description
-- FROM PARTS_DESCRIPTIONS_FTS
-- WHERE PARTS_DESCRIPTIONS_FTS MATCH ?
-- ORDER BY rank;


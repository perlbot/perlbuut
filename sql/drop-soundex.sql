BEGIN TRANSACTION;
CREATE TABLE factoid_new (
                factoid_id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_subject VARCHAR(100),
                subject VARCHAR(100),
                copula VARCHAR(25),
                predicate TEXT,
                author VARCHAR(100),
                modified_time INTEGER,
                metaphone TEXT,
                compose_macro CHAR(1) DEFAULT '0',
                protected BOOLEAN DEFAULT '0'
        );

INSERT INTO factoid_new SELECT factoid_id, original_subject, subject, copula, predicate, author, modified_time, metaphone, compose_macro, protected FROM factoid;
DROP TABLE factoid;
ALTER TABLE factoid_new RENAME TO factoid;
COMMIT;



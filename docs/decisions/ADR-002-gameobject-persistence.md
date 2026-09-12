# ADR-002: native world spawns with transactional metadata
Context: user requests native persistence; target SaveToDB writes WorldDatabase and
updates native cache. Base native tables are MyISAM.
Decision: module ownership in world DB, native SaveToDB/DeleteFromDB inside directly
confirmed transactions. Fail closed until operator-approved InnoDB preparation.
Alternatives: character-DB materialization (Warband), cross-DB writes, automatic
native table conversion. None meet the requested native path as cleanly.
Consequences: world data must be backed up together; explicit operator preparation;
failed commit latches off after restoring cache where possible. Native migration/
respawn side effects require inspection after failure. Evidence: GameObject.cpp,
World::ExecuteUpdate, Database::CommitTransactionDirect, sql/create_databases.sql.

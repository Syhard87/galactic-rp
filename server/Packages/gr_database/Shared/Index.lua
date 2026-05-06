GRDatabase = GRDatabase or {}
GRDatabase.Shared = GRDatabase.Shared or {}

-- Shared contains package metadata only. Credentials, connection strings and
-- all database access must remain inside Server/.
GRDatabase.Shared.Constants = {
    PACKAGE_NAME = "gr_database",
    DEFAULT_ENGINE = "postgresql",
    LOG_PREFIX = "[gr_database]",
    SERVER_ONLY_NOTE = "Sensitive database logic stays in Server/.",
}

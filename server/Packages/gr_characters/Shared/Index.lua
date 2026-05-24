GRCharacters = GRCharacters or {}
GRCharacters.Shared = GRCharacters.Shared or {}

-- Shared exposes package metadata and event naming only. Character authority,
-- validation and persistence stay in Server/.
GRCharacters.Shared.Constants = {
    PACKAGE_NAME = "gr_characters",
    LOG_PREFIX = "[gr_characters]",
    EVENT_PREFIX = "gr.characters",
    SERVER_ONLY_NOTE = "Character lifecycle logic stays in Server/.",
}

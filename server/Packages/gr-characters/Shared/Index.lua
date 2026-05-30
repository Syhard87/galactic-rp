GRCharacters = GRCharacters or {}
GRCharacters.Shared = GRCharacters.Shared or {}

-- Shared exposes package metadata and event naming only. Character authority,
-- validation and persistence stay in Server/.
GRCharacters.Shared.Constants = {
    PACKAGE_NAME = "gr-characters",
    LOG_PREFIX = "[gr_characters]",
    EVENT_PREFIX = "gr.characters",
    SERVER_ONLY_NOTE = "Character lifecycle logic stays in Server/.",
}

GRCharacters.Shared.Events = {
    OPEN_CHARACTER_CREATION = "gr.characters.creation.open",
    SUBMIT_CHARACTER_CREATION = "gr.characters.creation.submit",
    CHARACTER_CREATION_RESULT = "gr.characters.creation.result",
}

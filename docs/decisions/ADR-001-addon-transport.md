# ADR-001: private command fallback
Context: stock Turtle Lua and target chat hooks differ from custom-client protocols.
Decision: self-whisper `.camp`, versioned tilde-delimited payload, private system
responses. No core seam. Raw pipes are escaped because native hyperlink validation
can reject them. Alternatives: generic LANG_ADDON consumer or custom opcode; neither
is required to support this task's stock client.
Consequences: conservative 800 ms addon pacing, visible system tags, PlayerCommands
gate for ordinary players. Evidence: ChatHandler.cpp ProcessChatMessageAfterSecurityCheck,
Chat.cpp ExecuteCommand/ParseCommands, Opcodes.cpp PACKET_PROCESS_WORLD.

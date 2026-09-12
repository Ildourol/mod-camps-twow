# TCAMP version 1

Transport: addon sends `SendChatMessage(".camp " .. payload, "WHISPER", nil,
UnitName("player"))`. The native parser consumes the command before whisper routing.
Even without the module or with PlayerCommands disabled, traffic is addressed only
to the sender. Replies use ChatHandler::SendSysMessage on that authenticated session.
The addon does not hide tagged system lines by replacing the global chat handler.
No custom client opcode or direct database connection is required.

Request: `1~requestId~OP~arg...`; response: `TCAMP/1~requestId~OP~field...`.
`~`, `%`, pipe and control bytes are percent-encoded as uppercase hex. Decoding is
one pass; malformed escapes and decoded control bytes are rejected. Raw pipes are
not wire separators because native chat hyperlink validation interprets them.
Request limit is 210 bytes (plus six-byte `.camp ` prefix); reply limit 240 bytes.
Names are truncated to 48 bytes (further shortened if escaping would exceed the
240-byte row limit); categories to 32. Non-ASCII name search is bytewise
except ASCII case folding. No locale-aware Unicode search is promised.

Request IDs: positive uint32, strictly increasing per character after HELLO. HELLO
cancels the old edit and starts negotiation, allowing a fresh ID sequence after
UI reload. HELLO reply fields: enabled, GM-authorized, normal-players-enabled,
capabilities, page-size. Authentication is session-derived; IDs never grant access.

## Operations (exact arity)

| Request operation | Arguments | Reply / purpose |
|---|---|---|
| HELLO | none | HELLO; cancels old edit and undo |
| STATUS | none | STATUS enabled, mode, usage, cap, radius, catalogue-size, has-camp |
| RELOAD | none | RELOAD enabled; administrator only; reconnect afterwards |
| MODE | GM or CAMP | MODE; cancels edit and undo |
| SEARCH | query, category, zero-based page | BEGIN CATALOG, up to 8 ITEM rows, END CATALOG total/page |
| OBJECTS | page | BEGIN OBJECTS, up to 8 OBJECT rows, END |
| CAMPS | page | BEGIN CAMPS, up to 8 CAMP rows, END |
| PREVIEW | template entry | EDIT token, entry, x, y, z, yaw |
| EDIT | owned spawn GUID | EDIT; start existing-object edit |
| DUPLICATE | owned spawn GUID | EDIT; new preview at source transform |
| NEAREST | 0 or 1 | EDIT; 1 restricts selection to facing cone |
| DELTA | edit-token, forward, left, height, yaw | EDIT; relative to current character facing |
| SNAP | edit-token | EDIT; native terrain/VMAP height |
| SAVE | edit-token | SAVED spawn-GUID, entry |
| CANCEL | edit-token | CANCEL |
| DELETE | owned spawn GUID | DELETED GUID; no edit may be active |
| UNDO | none | UNDONE |
| CLAIM | none | CLAIMED camp-ID (account); Camp mode only |
| PUBLIC | 0 or 1 | PUBLIC; toggle own camp's visit permission |
| GO | none | TRAVEL OK; own camp |
| VISIT | camp-ID | TRAVEL OK; permitted public camp |
| BREAK | REQUEST, then separate CONFIRM | CONFIRM BREAK 15, then BROKEN |

ITEM: entry, name, type, display ID, template size, category, SAFE/GM. GM here means
an otherwise-safe template denied to normal players by an override, not unsafe type.
OBJECT: spawn GUID, entry, x, y, z. CAMP: account/camp ID, map, x, y, prop count,
PUBLIC/PRIVATE. No packet accepts a native map ID, owner ID or absolute coordinates.

## Bounds and state
Server admission: one operation per 200 ms per active character, including malformed
input; SEARCH at least 750 ms apart. Flooded operations within the admission window
are silently dropped. Addon has one outstanding request, eight queued at most,
and at least 800 ms between sends. It never retries a timed-out mutation. A five-second
timeout clears its pending state and asks for reconnect; unsaved server state expires.

Deltas are finite decimal numbers only, at most 16 bytes, no exponent/NaN/Infinity.
Each translation axis is +/-5 yards, yaw +/-0.7854 radians. Total pose remains within
60 yards of the player and within their camp radius in Camp mode. Session token,
deadline and map are checked on every edit command. Search query <=48 bytes,
category <=32, page <=2500 (object/camp pages <=1250); only eight rows per page.

Errors are `ERROR~CODE`, correlated by request ID when parsing reached it. Examples:
PROTOCOL, ARGUMENTS, HANDSHAKE_OR_REPLAY, DISABLED_OR_PERMISSION, STALE_EDIT, LOCATION,
PREVIEW_REJECTED, OWNERSHIP_OR_BUSY, SPACING, DATABASE, LOAD_CAMP_OR_BUSY.
Unknown operations never fall through to another command family.

## Examples
```text
.camp 1~1~HELLO
.camp 1~2~MODE~CAMP
.camp 1~3~CLAIM
.camp 1~4~SEARCH~table~~0
.camp 1~5~PREVIEW~<entry-returned-by-server>
.camp 1~6~DELTA~<token>~0.5~0~0~0
.camp 1~7~SAVE~<token>
```
Do not send placeholder angle brackets literally. Use a real safe entry and current
token. The selected entry is revalidated on the server even for local favorites.

## Negotiated limits
Only protocol 1 and the private chat fallback are implemented. The target does have
LANG_ADDON and Turtle-specific dispatch, but there is no generic consumed incoming
addon hook selected for this implementation. Capabilities intentionally omit scale,
direct mouse picking, PlayerBots and personal phasing.

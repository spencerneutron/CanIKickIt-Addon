# CanIKickIt-Addon

CanIKickIt is a World of Warcraft addon focused on organizing group interrupts.
It helps players assign themselves to specific enemies, synchronizes these
assignments with other users of the addon, and shows the interrupt order on
nameplates.

## What it does
CanIKickIt is a lightweight group interrupt organizer for World of Warcraft nameplates. It
lets players mark intended interrupt targets and displays small icons on enemy nameplates
showing who intends to interrupt which spell, plus cooldown countdowns.

## How it behaves (summary)
- Intent assignments are two kinds: macro-sourced (explicit via user macro) and cast-sourced
  (created when a player actually casts an interrupt).
- Macro assignments are "locked": once set they cannot be overwritten by cast-sourced
  assignments (by the same player) unless the player presses the macro again.
- Cast assignments are lower priority and are used when no macro assignment exists.
- Assignments propagate to group members via addon comms so everyone sees intent markers.

## Macro vs Cast workflow (concrete)
1) Macro: user runs the macro (or button) to explicitly assign intent. The addon prefers
   the hostile focus first and then the hostile target when choosing what to assign. Macro
   assignments are flagged as source="macro" and show a small lock icon on nameplates.
2) Cast: when an interrupt spell is successfully cast (combat log detection) the addon
   creates a "cast" assignment locally and broadcasts it. Casts will not overwrite a
   macro-locked assignment for the same player.

## Communication & cooldown syncing
- Assign messages include a source field ("macro" or "cast") so receivers apply priority
  rules the same way.
- Cooldown syncing: the addon broadcasts remaining time (normalized via server time) so
  receivers can show a ticking cooldown independent of further updates.
- Local-only reconciliation: the addon watches your own spell cooldowns (debounced) and
  broadcasts updates when the game's authoritative cooldown differs from stored state
  (useful for channel/tick effects like Shifting Power).

## Commands & macro snippets
- Macro (recommended): set a macro with this line and bind it to a key or button:

  `/run CanIKickIt.AssignIntent()`

  This uses hostile focus > hostile target and marks the intent as macro (locked).

- Toggle icon anchor (persisted):

  `/cikianchor  -- toggles icons extending left/right and refreshes plates`

- Test draw (debug):

  `/cikitex [unit]`

## SavedVariables / configuration
The addon stores settings in CanIKickItDB (SavedVariables). Useful fields:
- CanIKickItDB.iconAnchor: "right" or "left" (default "right")
- CanIKickItDB.iconSpacing: spacing between icons (number)
- CanIKickItDB.iconSize: icon pixel size (number)
- CanIKickItDB.debug: boolean (enable debug logs)
- CanIKickItDB.syncMode: boolean (controls whether your client broadcasts CD updates)

## Troubleshooting & tips
- If debug logs disappear after Reload UI, enable debug and then Reload UI again to
  persist the setting before further testing (settings are written on reload/logout).
- If cooldowns appear frozen on remote clients, confirm both clients have syncMode enabled
  and that group comm distribution is available (party/raid/channel).
- For Shifting Power-style CD reductions, the addon polls your spell cooldowns (debounced)
  and will broadcast authoritative updates when it detects a meaningful change.

## Development notes (for maintainers)
- Canonical spell IDs: the addon canonicalizes interrupt spell IDs so icons, CD lookups and
  comm messages use a single id for aliases.
- Priority: assignment source and timestamps are used to resolve conflicts; macro > cast.
- Files of interest: Core.lua, Events.lua, Nameplates.lua, Comm.lua, Cooldowns.lua.

## License
See repository/LICENSE (if present).

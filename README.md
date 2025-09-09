# CanIKickIt-Addon

CanIKickIt is a small World of Warcraft addon that helps groups coordinate interrupts by
displaying intent icons and cooldowns on enemy nameplates and syncing intent across
addon users.

## What it does
This addon lets players mark intended interrupt targets and shows small icons on enemy
nameplates with who intends to interrupt which spell and a cooldown timer. It supports
explicit macro-sourced assignments (locked) and cast-sourced assignments (inferred from
combat log), plus a low-priority "observed" inference mode for non-addon party members.

## Modes of assignment
- Macro: explicit assignment via `/run CanIKickIt.AssignIntent()` (preferred: hostile focus,
  then hostile target). Macro assignments are marked source="macro" and display a lock
  icon on nameplates. Macros are highest priority and cannot be overwritten by cast or
  observed assignments.
- Cast: created when an interrupt spell is successfully cast (combat log detection). Cast
  assignments are broadcast and can overwrite older cast/remote assignments but not macros.
- Observed: a local-only, lowest-priority inference created when `observerMode` is enabled
  and another party member (non-raid) casts an interrupt. Observed assignments are not
  broadcast and are shown with an uncertain/question-mark marker on nameplates.

## Observer mode (important)
- Controlled by the `observerMode` option (on the options panel).
- Only active when you're in a party (not a raid).
- Pet casts are attributed to their owner when a pet→owner mapping is available, so observed
  inferences for pet casts use the owner's name where possible.
- Observed assignments never overwrite macro or cast assignments for the same player.

## Options / SavedVariables
Settings are stored in `CanIKickItDB` (SavedVariables). Relevant fields:
- `iconAnchor` ("right" or "left") — which direction icons grow from the nameplate.
- `iconSpacing` (number) — spacing in pixels between icons.
- `iconSize` (number) — size of the icon texture in pixels.
- `showLabels` (boolean) — show short player labels above icons.
- `labelFontSize` (number) — font size for the label text.
- `debug` (boolean) — enable debug logging printed to chat.
- `syncMode` (boolean) — enable broadcasting of cooldown updates to other addon users.
- `observerMode` (boolean) — enable low-priority inferred assignments from party members.

You can open the options panel from the game using the following slashes:
- `/ciki` or `/canikickit` — opens the AddOn's options panel (tries the legacy and
  Settings APIs as available).
- `/cikianchor` — toggles icon anchor left/right and refreshes visible nameplates.

Also supported:
- Macro: `/run CanIKickIt.AssignIntent()` — explicitly assign intent (macro-sourced).

## Cooldown syncing and reconciliation
- Assign messages include a `source` field so receivers apply priority rules consistently.
- Cooldown messages are sent with server-normalized ready times so remote clients can
  reconstruct remaining time reliably.
- The addon debounces local cooldown reconciliation and uses `C_Spell.GetSpellCooldown`
  to compare authoritative API values with stored state; if a meaningful difference is
  detected the addon will update and optionally broadcast the change (when `syncMode` is true).

## Nameplate behavior and ordering
- Icons are sorted by base cooldown (ascending) with stable tie-breaks. This keeps shorter
  CDs nearer the nameplate.
- The options panel exposes anchor and spacing controls so you can customize layout.

## Implementation notes (for maintainers)
- Canonical spell IDs: the addon normalizes interrupt spell IDs across Events/Nameplates/
  Cooldowns/Comm to handle merged/alias spell IDs consistently.
- Pet ownership: `Events.lua` maintains a small pet→owner cache to attribute pet casts to
  owner names (and stores owner GUIDs internally) which helps observed assignment accuracy.
- Observed assignments are local-only: they are not sent over addon comms and are lowest priority.
- Files of interest: `Core.lua`, `Events.lua`, `Nameplates.lua`, `Comm.lua`, `Cooldowns.lua`, `Options.lua`.

## Troubleshooting & tips
- If debug logs disappear after Reload UI, enable `debug` then Reload UI to persist the setting
  before further testing (SavedVariables are written on logout/reload).
- If cooldowns look wrong on remote clients, ensure both clients have `syncMode` enabled and
  that the group communication channel is available (party/raid).

## License
See repository/LICENSE (if present).

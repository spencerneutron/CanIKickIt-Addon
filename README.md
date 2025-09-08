# CanIKickIt-Addon

CanIKickIt is a World of Warcraft addon focused on organizing group interrupts.
It helps players assign themselves to specific enemies, synchronizes these
assignments with other users of the addon, and shows the interrupt order on
nameplates.

Macro Usage

Run this call after you have focused an enemy you intend to interrupt, or are targeting one if not using focus on a hostile.
```
/run CanIKickIt.AssignIntent()
```

## Core behaviour

### Interrupt assignment event
Players trigger the addon through a macro that signals an intent to interrupt a
hostile unit. When the event fires, the addon determines the relevant target by
capturing the player's hostile focus first, or their hostile target if no focus
is available. This information is stored so that the addon knows which unit the
player intends to cover.

### Hidden communication channel
Whenever an interrupt intent is registered, the addon sends a message over an
addon-only communication channel to party, raid, or instance members who also
use CanIKickIt. This traffic happens behind the scenes and does not appear in
chat, allowing users to quietly share their assignments.

### Nameplate display
For each enemy that has one or more assigned players, the addon shows the
assigned interrupt abilities to the right of that enemy's nameplate. Icons are
displayed in the order that players signaled their intent: the earliest is
anchored closest to the nameplate and later assignments extend left to right,
showing each spell's icon and cooldown.

This document outlines the intended behaviour so development can proceed with a
clear reference of the addon's goals. Implementation details may evolve, but the
core principles above should remain consistent.

Utilizes AceComm-3.0 to send and receive addon messages between users.

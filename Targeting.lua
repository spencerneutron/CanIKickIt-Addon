local NS = select(2, ...)

local function FirstHostileUnit()
  if UnitExists("focus") and UnitCanAttack("player","focus") then return "focus" end
  if UnitExists("target") and UnitCanAttack("player","target") then return "target" end
  return nil
end

function NS.AssignIntent()
  local unit
  if UnitExists("focus") and UnitCanAttack("player","focus") then unit = "focus"
  elseif UnitExists("target") and UnitCanAttack("player","target") then unit = "target" end
  if not unit then NS:Log("No hostile focus/target") return end

  local guid = UnitGUID(unit)
  if not guid then return end

  local intr = NS.GetPreferredInterruptForPlayer()
  if not intr then NS:Log("No applicable interrupt for class/spec") return end

  local player = UnitName("player")
  local ts = NS.Now()
  NS.Assignments_Add(guid, intr.spellID, player, ts)
  NS.Comm_SendAssign(guid, intr.spellID, player, ts)
  NS:Log(("Assigned %s (%d) to %s"):format(intr.name, intr.spellID, guid or "?"))
end


-- Example Macro usage:
-- /run CanIKickIt.AssignIntent()
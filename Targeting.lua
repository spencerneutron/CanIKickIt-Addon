local NS = select(2, ...)

local function FirstHostileUnit()
  if UnitExists("focus") and UnitCanAttack("player","focus") then return "focus" end
  if UnitExists("target") and UnitCanAttack("player","target") then return "target" end
  return nil
end

function NS.AssignIntent()
  -- preserve the original parameterless API; delegate to AssignIntentCore
  if NS.AssignIntentCore then
    NS.AssignIntentCore()
  else
    NS:Log("AssignIntent: core helper missing")
  end
end
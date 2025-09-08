-- Interrupts.lua (replace file)
local NS = select(2, ...)

-- Notes:
-- - "spec" can be true (any spec) or a specId (e.g., 252 Unholy) or {specId1, specId2}
-- - "aoe" marks AoE silences/interrupts (e.g., Solar Beam, Shield of Virtue, Disrupting Shout)
-- - "cd" equals the "duration" column from your source (base cooldown seconds)
-- - We keep "name" and "icon" for UI; GetSpellInfo can override at runtime if needed

NS.INTERRUPTS = {
  -- DEATH KNIGHT
  { class="DEATHKNIGHT", spellID=47482,  name="Leap",               cd=30, spec=252,     icon=237569 },   -- Ghoul leap (you flagged as interrupt)
  { class="DEATHKNIGHT", spellID=47528,  name="Mind Freeze",        cd=15, spec=true,    icon=237527 },

  -- DEMON HUNTER
  { class="DEMONHUNTER", spellID=183752, name="Disrupt",            cd=15,               icon=1305153 },

  -- DRUID
  { class="DRUID",       spellID=106839, name="Skull Bash",         cd=15, spec=true,    icon=236946 },
  { class="DRUID",       spellID=78675,  name="Solar Beam",         cd=60, spec=true,    icon=252188, aoe=true },

  -- EVOKER
  { class="EVOKER",      spellID=351338, name="Quell",              cd=40, spec=true,    icon=4622469 },

  -- HUNTER
  { class="HUNTER",      spellID=187707, name="Muzzle",             cd=15, spec=true,    icon=1376045 },
  { class="HUNTER",      spellID=147362, name="Counter Shot",       cd=24, spec=true,    icon=249170 },

  -- MAGE
  { class="MAGE",        spellID=2139,   name="Counterspell",       cd=24,               icon=135856 },

  -- MONK
  { class="MONK",        spellID=116705, name="Spear Hand Strike",  cd=15, spec=true,    icon=608940 },

  -- PALADIN
  { class="PALADIN",     spellID=215652, name="Shield of Virtue",   cd=45, spec=true,    icon=237452, aoe=true },
  { class="PALADIN",     spellID=31935,  name="Avenger's Shield",   cd=15, spec=true,    icon=135874 },
  { class="PALADIN",     spellID=96231,  name="Rebuke",             cd=15, spec=true,    icon=523893 },

  -- PRIEST
  { class="PRIEST",      spellID=15487,  name="Silence",            cd=45, spec=true,    icon=458230 },

  -- ROGUE
  { class="ROGUE",       spellID=1766,   name="Kick",               cd=15,               icon=132219 },

  -- SHAMAN
  { class="SHAMAN",      spellID=57994,  name="Wind Shear",         cd=12, spec=true,    icon=136018 },

  -- WARLOCK
  { class="WARLOCK",     spellID=119898, name="Command Demon",      cd=24,               icon=236292 }, -- maps to pet interrupt (e.g., Spell Lock) via Command Demon

  -- WARRIOR
  { class="WARRIOR",     spellID=6552,   name="Pummel",             cd=15,               icon=132938 },
  { class="WARRIOR",     spellID=386071, name="Disrupting Shout",   cd=90, spec=true,    icon=132091, aoe=true },
}

-- ---- Indices & helpers ----------------------------------------------------

-- Map: spellID -> entry
NS.INTERRUPT_BY_SPELLID = {}
-- Map: CLASS -> { entries... }
NS.INTERRUPTS_BY_CLASS = {}

local function addIndex(e)
  NS.INTERRUPT_BY_SPELLID[e.spellID] = e
  local bucket = NS.INTERRUPTS_BY_CLASS[e.class] or {}
  bucket[#bucket+1] = e
  NS.INTERRUPTS_BY_CLASS[e.class] = bucket
end

for _, e in ipairs(NS.INTERRUPTS) do addIndex(e) end

-- Utility: does this entry apply to the given spec?
local function specMatches(entry, currentSpecId)
  if entry.spec == nil then return true end
  if entry.spec == true then return true end
  if type(entry.spec) == "number" then return entry.spec == currentSpecId end
  if type(entry.spec) == "table" then
    for _, id in ipairs(entry.spec) do if id == currentSpecId then return true end end
  end
  return false
end

-- Public API:

-- Returns all interrupts available to the player (class/spec filtered)
function NS.GetPlayerInterrupts()
  local _, class = UnitClass("player")
  local specId = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or nil
  local list = {}
  for _, e in ipairs(NS.INTERRUPTS_BY_CLASS[class] or {}) do
    if specMatches(e, specId) then list[#list+1] = e end
  end
  return list
end

-- Prefer the shortest-CD single-target kick, fallback to anything
function NS.GetPreferredInterruptForPlayer()
  local list = NS.GetPlayerInterrupts()
  if #list == 0 then return nil end
  table.sort(list, function(a,b)
    local aKey = (a.aoe and 1 or 0)  -- single-target first
    local bKey = (b.aoe and 1 or 0)
    if aKey ~= bKey then return aKey < bKey end
    return (a.cd or 999) < (b.cd or 999)
  end)
  return list[0+1]   -- first
end

-- SpellID helpers
function NS.IsInterruptSpell(spellID)
  return NS.INTERRUPT_BY_SPELLID[spellID] ~= nil
end

function NS.GetInterruptBySpellID(spellID)
  return NS.INTERRUPT_BY_SPELLID[spellID]
end

-- Base CD (seconds) pulled from the table; safe default 15
function NS.GetBaseCD(spellID)
  local e = NS.INTERRUPT_BY_SPELLID[spellID]
  return (e and e.cd) or 15
end

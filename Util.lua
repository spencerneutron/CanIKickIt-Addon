local NS = select(2, ...)

-- Encode a table of fields as pipe-delimited string; escape pipes/backslashes.
function NS.Encode(fields)
  local out = {}
  for i = 1, #fields do
    local s = tostring(fields[i] or "")
    s = s:gsub("\\", "\\\\"):gsub("|", "\\p")
    out[i] = s
  end
  return table.concat(out, "|")
end

-- Decode to array; unescape.
function NS.Decode(s)
  local out = {}
  for part in string.gmatch(s, "([^|]*)|?") do
    if part == "" and #out > 0 and s:sub(-1) ~= "|" then break end
    part = part:gsub("\\p", "|"):gsub("\\\\", "\\")
    table.insert(out, part)
  end
  return out
end

function NS.Now()
  return GetTime()
end

-- stable sort by first then second field
function NS.StableSort(t, cmp)
  table.sort(t, cmp)
end
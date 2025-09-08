local NS = select(2, ...)

function NS.InitConfig()
  local db = NS.DB
  db.debug       = db.debug or false
  db.syncMode    = db.syncMode ~= false      -- enable comm-based CD sync by default
  db.iconSize    = db.iconSize or 18
  db.iconSpacing = db.iconSpacing or 2
end

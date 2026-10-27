if isServer() then return end
require "CDCLastHope/CDCClient"
require "CDCLastHope/CDCModal"

-- pickups
CDC.Pickup = { pending = {} }
local P = CDC.Pickup

-- is this pickup still available for this player, per its once mode
function P.available(def, player)
  local st = CDC.State.get()
  local once = def.once or "global"
  if once == "global" then return st.pickups[def.id] == nil end
  if once == "character" then return not (player:getModData().CDCPickups or {})[def.id] end
  return true
end

function P.request(player, def)
  P.pending[def.id] = { player = player, def = def }
  CDC.Net.send(player, "pickup", { id = def.id })
end

function P.onResult(args)
  local p = P.pending[args.id]
  if not p then return end
  P.pending[args.id] = nil
  if not args.ok then
    CDC.Modal.show(p.player, p.def.goneText or "Nothing here anymore.")
    return
  end
  if (p.def.once or "global") == "character" then
    local md = p.player:getModData()
    md.CDCPickups = md.CDCPickups or {}
    md.CDCPickups[p.def.id] = true
  end
  CDC.Modal.show(p.player, p.def.text)
end

---@class Store
---@field PlayerData Dict<PlayerData>
---@field WallProjectiles Dict<EntityProjectile>

local Store = {}

---@type Dict<PlayerData>
Store.PlayerData = {}
---@type Dict<EntityProjectile>
Store.WallProjectiles = {}

return Store
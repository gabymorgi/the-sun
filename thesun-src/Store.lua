---@class Store
---@field PlayerData Dict<PlayerData>
---@field WallProjectiles Dict<EntityProjectile>
---@field prismCachedCount number

local Store = {}

---@type Dict<PlayerData>
Store.PlayerData = {}
---@type Dict<EntityProjectile>
Store.WallProjectiles = {}
---@type number
Store.prismCachedCount = 0

return Store
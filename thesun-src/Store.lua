---@class Store
---@field PlayerData Dict<PlayerData>
---@field WallProjectiles Dict<EntityProjectile>
---@field prismCachedCount number
---@field releasedTears Dict<{ tear: EntityTear, velocity: Vector, expirationFrame: number }>

local Store = {}

---@type Dict<PlayerData>
Store.PlayerData = {}
---@type Dict<EntityProjectile>
Store.WallProjectiles = {}
---@type number
Store.prismCachedCount = 0
Store.releasedTears = {}

return Store
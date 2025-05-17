local Utils = include("thesun-src.utils")

---@class Orbital<T>: { entity: T }
---@field direction number
---@field radius number
---@field angle number
---@field expirationFrame number
---@field bounced? boolean
---@field target? Entity

---@alias addOrbital<T> fun(self: any, player: EntityPlayer, orbital: T, tearLifetime: number?): Orbital<T>
---@class Orbit<T>: { list: Dict<Orbital<EntityOrbital>>, add: addOrbital<T> }
---@field length number
---@field limit number
---@field new fun(self: any): any
---@field remove fun(self: any, hash: number): nil
---@field hasSpace fun(self: any): boolean
---@field __index any

---@type Orbit<Entity>
local Orbit = {}
Orbit.__index = Orbit

function Orbit:new()
  local obj = setmetatable({
    list = {},
    length = 0,
    limit = 60,
  }, self)
  return obj
end

---@param player EntityPlayer
---@param orbital EntityOrbital
---@param tearLifetime? number
function Orbit:add(player, orbital, tearLifetime)
  local orbitalHash = GetPtrHash(orbital)
  if self.list[orbitalHash] then return self.list[orbitalHash] end
  self.list[orbitalHash] = {
    entity = orbital,
    direction = Utils.GetClockWiseSign(player.Position, orbital),
    radius = (orbital.Position - player.Position):Length(),
    angle = Utils.GetAngle(player.Position, orbital.Position),
    expirationFrame = Game():GetFrameCount() + (tearLifetime or player.TearRange / 2),
  }
  self.length = self.length + 1
  return self.list[orbitalHash]
end

---@param hash number
function Orbit:remove(hash)
  self.list[hash] = nil
  self.length = self.length - 1
end

---@return boolean
function Orbit:hasSpace()
  return self.length < self.limit
end

-----------------------------------------------------------------------------

---@type Orbit<EntityTear>
local TearOrbit = setmetatable({}, { __index = Orbit })
TearOrbit.__index = TearOrbit

---@return Orbit<EntityTear>
---@diagnostic disable-next-line: duplicate-set-field
function TearOrbit:new()
  return setmetatable(Orbit.new(self), self)
end

---@param player EntityPlayer
---@param orbital EntityTear
---@return EntityTear
---@diagnostic disable-next-line: duplicate-set-field
function TearOrbit:add(player, orbital)
  orbital:AddTearFlags(TearFlags.TEAR_SPECTRAL)
  if (orbital.Type == EntityType.ENTITY_TEAR) then
    orbital.Height = -10
    orbital.FallingAcceleration = -0.1
    orbital.FallingSpeed = 0
  end
  return Orbit.add(self, player, orbital)
end

---@param hash number
---@diagnostic disable-next-line: duplicate-set-field
function TearOrbit:remove(hash)
  local tear = self.list[hash].entity
  if tear.Type == EntityType.ENTITY_TEAR and not tear.Variant == TearVariant.FETUS then
      -- tear.FallingSpeed = 0.5
      if not tear:HasTearFlags(TearFlags.TEAR_OCCULT) then
        tear.Velocity = tear.Velocity * 10
      end
      if tear:HasTearFlags(TearFlags.TEAR_POP) then
        tear.FallingAcceleration = -0.09
        tear:ClearTearFlags(TearFlags.TEAR_SPECTRAL)
        tear.FallingSpeed = 0
        tear.Velocity = tear.Velocity:Rotated(-90)
      else
        tear.FallingAcceleration = 0
      end
  end
  Orbit.remove(self, hash)
end

-----------------------------------------------------------------------------

local ProjectileOrbit = setmetatable({}, { __index = Orbit })
ProjectileOrbit.__index = ProjectileOrbit

---@return Orbit<EntityProjectile>
---@diagnostic disable-next-line: duplicate-set-field
function ProjectileOrbit:new()
  return setmetatable(Orbit.new(self), self)
end

---@param player EntityPlayer
---@param orbital EntityProjectile
---@return EntityProjectile
---@diagnostic disable-next-line: duplicate-set-field
function ProjectileOrbit:add(player, orbital)
  orbital:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES | ProjectileFlags.CANT_HIT_PLAYER)
  orbital.FallingAccel = -0.1
  orbital.FallingSpeed = 0
  return Orbit.add(self, player, orbital)
end

---@param hash number
---@diagnostic disable-next-line: duplicate-set-field
function ProjectileOrbit:remove(hash)
  local ent = self.list[hash].entity
  ent.FallingAccel = 0.1
  ent.Velocity = ent.Velocity * 10
  Orbit.remove(self, hash)
end

-----------------------------------------------------------------------------

--- Effect Orbital ---
local EffectOrbit = setmetatable({}, { __index = Orbit })
EffectOrbit.__index = EffectOrbit

---@return Orbit<EntityEffect>
---@diagnostic disable-next-line: duplicate-set-field
function EffectOrbit:new()
  return setmetatable(Orbit.new(self), self)
end

---@param player EntityPlayer
---@param orbital EntityEffect
---@return EntityEffect
---@diagnostic disable-next-line: duplicate-set-field
function EffectOrbit:add(player, orbital)
  if (orbital.Variant == EffectVariant.BLUE_FLAME or orbital.Variant == EffectVariant.RED_CANDLE_FLAME) then
    orbital.Timeout = 60
    orbital.LifeSpan = 60
    return Orbit.add(self, player, orbital, 60)
  end
  return Orbit.add(self, player, orbital)
end

return {
  Orbit = Orbit,
  TearOrbit = TearOrbit,
  ProjectileOrbit = ProjectileOrbit,
  EffectOrbit = EffectOrbit,
}

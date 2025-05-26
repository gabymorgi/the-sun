---@type Const
local Const = require("thesun-src.Const")

---@class Utils
---@field colorOffsets table<string, { colorOffset: number[], rangeMultiplier: number }>
---@field GetColorOffset fun(tear: EntityTear): string | nil
---@field GetClockWiseSign fun(playerPos: Vector, proj: Entity): number
---@field GetClockwiseSign2 fun(center: Vector, current: Vector, target: Vector): number
---@field GetAngle fun(pos1: Vector, pos2: Vector): number
---@field FastInvSqrt fun(x: number): number
---@field FastSqrt fun(x: number): number
---@field Clamp fun(value: number, min: number, max: number): number
---@field SpawnEntity fun(entityType: EntityType, variant: number, spawnPos: Vector, velocity: Vector, player?: EntityPlayer, subType?: number, seed?: number): Entity
---@field IsTheSun fun(player: EntityPlayer): boolean
---@field GetPlayers fun(): EntityPlayer[]
---@field GetEnemiesInRange fun(position: Vector, radius: number): Entity[]
---@field GetClosestEnemies fun(position: Vector): Entity?
---@field GetMarkedTarget fun(player: EntityPlayer): EntityEffect | nil
---@field GetExtraBulletTrain fun(player: EntityPlayer): number
---@field GetMarkedTarget fun(player: EntityPlayer): EntityEffect | nil
---@field GetHeadVector fun(player: EntityPlayer): Vector
---@field GetShootVector fun(player: EntityPlayer): Vector
---@field GetFlattenedOrbitPosition fun(player: EntityPlayer, angle: number, radius: number): Vector

local Utils = {}

---@param entityType EntityType
---@param variant number
---@param spawnPos Vector
---@param velocity Vector
---@param player? EntityPlayer
---@param subType? number
---@param seed? number
function Utils.SpawnEntity(entityType, variant, spawnPos, velocity, player, subType, seed)
  return Const.game:Spawn(
    entityType,
    variant,
    spawnPos,
    velocity,
    player,
    subType or 0,
    seed or Const.game:GetRoom():GetSpawnSeed()
  )
end

--- @param playerPos Vector
--- @param proj Entity
--- @return number -1 = clockwise, 1 = counter-clockwise
function Utils.GetClockWiseSign(playerPos, proj)
  local toProj = (proj.Position - playerPos):Normalized()
  local velocity = proj.Velocity:Normalized()

  local sign = velocity.X * toProj.Y - velocity.Y * toProj.X
  if sign > 0 then
    return -1
  else
    return 1
  end
end

---Calcula el signo para saber si orb debe girar horario o antihorario
---@param center Vector -- centro de la órbita (player.Position)
---@param current Vector -- posición actual de la lágrima (orb.position)
---@param target Vector -- posición del objetivo (orb.target.position)
---@return integer -- 1 si debe girar antihorario, -1 si horario
function Utils.GetClockwiseSign2(center, current, target)
  local v1 = current - center
  local v2 = target - center
  local cross = v1.X * v2.Y - v1.Y * v2.X
  return (cross > 0) and 1 or -1
end

--- @param pos1 Vector
--- @param pos2 Vector
--- @return number
function Utils.GetAngle(pos1, pos2)
  return math.atan(pos2.Y - pos1.Y, pos2.X - pos1.X)
end

-- Devuelve aproximadamente 1 / sqrt(x)
---@param x number
---@return number
function Utils.FastInvSqrt(x)
  local threehalfs = 1.5
  local x2 = x * 0.5
  local y = x
  local i = string.unpack("I4", string.pack("f", y))
  i = 0x5f3759df - (i >> 1)
  y = string.unpack("f", string.pack("I4", i))
  y = y * (threehalfs - (x2 * y * y))
  return y
end

-- Para obtener sqrt(x)
---@param x number
---@return number
function Utils.FastSqrt(x)
  return x * Utils.FastInvSqrt(x)
end

---@param value number
---@param min number
---@param max number
---@return number
function Utils.Clamp(value, min, max)
  return math.max(min, math.min(value, max))
end

Utils.colorOffsets = {
  Red = { colorOffset = { 0.61, -0.39, -0.39 }, rangeMultiplier = 1.38 },
  Yellow = { colorOffset = { 0.54, 0.61, -0.4 }, rangeMultiplier = 1.13 },
  Green = { colorOffset = { -0.4, 0.61, -0.26 }, rangeMultiplier = 0.88 },
  Cyan = { colorOffset = { -0.39, 0.4, 0.61 }, rangeMultiplier = 0.63 },
}

--- @param tear EntityTear
function Utils.GetColorOffset(tear)
  for color, values in pairs(Utils.colorOffsets) do
    if (
      math.abs(tear.Color.RO - values.colorOffset[1]) < 0.01 and
      math.abs(tear.Color.GO - values.colorOffset[2]) < 0.01 and
      math.abs(tear.Color.BO - values.colorOffset[3]) < 0.01
    ) then
      return color
    end
  end
  return nil
end

---@param player EntityPlayer
---@return boolean
function Utils.IsTheSun(player)
  if (player:GetPlayerType() == Const.TheSunType) then
    return true
  end
  return false
end

-- for _,player in pairs(GetPlayers()) do
--- @return EntityPlayer[]
function Utils.GetPlayers()
  local players = {}
  for i = 0, Const.game:GetNumPlayers() - 1 do
    local player = Const.game:GetPlayer(i)
    if Utils.IsTheSun(player) then
      table.insert(players, player)
    end
  end
  return players
end

---@param position Vector
---@param radius number
---@return Entity[]
function Utils.GetEnemiesInRange(position, radius)
  local enemies = {}
  for _, entity in pairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
    if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_NO_TARGET) then
      table.insert(enemies, entity)
    end
  end
  return enemies
end

---@param position Vector
---@return Entity?
function Utils.GetClosestEnemies(position)
  local nearestEnemy
  local minDist = math.huge
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    if entity:IsVulnerableEnemy() and not entity:IsDead() then
      local dist = position:DistanceSquared(entity.Position)
      if dist < minDist then
        minDist = dist
        nearestEnemy = entity
      end
    end
  end
  return nearestEnemy
end

--- @param player EntityPlayer
function Utils.GetMarkedTarget(player)
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.TARGET)) do
		local spawner = entity.SpawnerEntity
		
		if spawner and GetPtrHash(spawner) == GetPtrHash(player) then
			return entity:ToEffect()
		end
	end
	return nil
end

local DIRECTION_MAP = {
  [Direction.UP] = Vector(0,-1),
  [Direction.LEFT] = Vector(-1,0),
  [Direction.DOWN] = Vector(0,1),
  [Direction.RIGHT] = Vector(1,0),
  [Direction.NO_DIRECTION] = Vector(0,0)
}

---@param player EntityPlayer
---@return Vector
function Utils.GetHeadVector(player)
  if not player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK)then
    local fireDirection = player:GetFireDirection()
    if fireDirection == Direction.NO_DIRECTION then
      return DIRECTION_MAP[player:GetHeadDirection()]
    else
      return DIRECTION_MAP[fireDirection]
    end
  else
    return player:GetAimDirection()
  end
end

---@param player EntityPlayer
---@return Vector
function Utils.GetShootVector(player)
  if not player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK) then
    local fireDirection = player:GetFireDirection()
    return DIRECTION_MAP[fireDirection]
  else
    return player:GetAimDirection()
  end
end

function Utils.GetFlattenedOrbitPosition(player, angle, radius)
  local aim = Utils.GetHeadVector(player) -- :Normalized()
  local perp = Vector(-aim.Y, aim.X) -- Vector perpendicular al de disparo

  local x = math.cos(angle) * radius
  local y = math.sin(angle) * radius * 0.3 -- 1 normal, 0 plano

  return aim * x + perp * y
end

return Utils
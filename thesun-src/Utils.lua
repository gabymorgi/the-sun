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
---@field IsPluto fun(player: EntityPlayer): boolean
---@field HasOrbit fun(player: EntityPlayer): boolean
---@field GetPlayers fun(): EntityPlayer[]
---@field AnyoneHasOrbit fun(): number?
---@field GetEnemiesInRange fun(position: Vector, radius: number): Entity[]
---@field GetClosestEnemies fun(position: Vector): Entity?
---@field GetClosestEnemiesInCone fun(position: Vector, direction: Vector, radius: number, minAngle: number, maxAngle: number): Entity?
---@field GetMarkedTarget fun(player: EntityPlayer): EntityEffect | nil
---@field GetExtraBulletTrain fun(player: EntityPlayer): number
---@field GetHeadVector fun(player: EntityPlayer): Vector
---@field GetShootVector fun(player: EntityPlayer): Vector
---@field GetFlattenedOrbitPosition fun(player: EntityPlayer, angle: number, radius: number): Vector
---@field GetSulfurLaserVariant fun(amount: number): LaserVariant
---@field GetAbsorbedLaserVariant fun(laserVariant: LaserVariant): LaserVariant
---@field ReplaceTNTWithTrollBombs fun(): nil

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

---@param center Vector
---@param current Vector
---@param target Vector
---@return number -1 = clockwise, 1 = counter-clockwise
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

-- 1 / sqrt(x)
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
  return player:GetPlayerType() == Const.TheSunType
end

---@param player EntityPlayer
---@return boolean
function Utils.IsPluto(player)
  return player:GetPlayerType() == Const.PlutoType
end

---@param player EntityPlayer
---@return boolean
function Utils.HasOrbit(player)
  return player:GetPlayerType() == Const.TheSunType or player:GetPlayerType() == Const.PlutoType
end

--- @return EntityPlayer[]
function Utils.GetPlayers()
  local players = {}
  for i = 0, Const.game:GetNumPlayers() - 1 do
    local player = Const.game:GetPlayer(i)
    if Utils.HasOrbit(player) then
      table.insert(players, player)
    end
  end
  return players
end

--- @return number?
function Utils.AnyoneHasOrbit()
  for i = 0, Const.game:GetNumPlayers() - 1 do
    local player = Const.game:GetPlayer(i)
    if Utils.IsTheSun(player) then
      return Const.TheSunType
    elseif Utils.IsPluto(player) then
      return Const.PlutoType
    end
  end
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

---@param position Vector
---@param direction Vector
---@param radius number
---@param minAngle number -- in degrees
---@param maxAngle number -- in degrees
---@return Entity?
function Utils.GetClosestEnemiesInCone(position, direction, radius, minAngle, maxAngle)
  local nearestEnemy
  local minDist = math.huge
  local dirAngle = direction:GetAngleDegrees()

  for _, entity in pairs(Utils.GetEnemiesInRange(position, radius)) do
    if entity:IsVulnerableEnemy() and not entity:IsDead() then
      local toEnemy = entity.Position - position
      local angleToEnemy = toEnemy:GetAngleDegrees() - dirAngle

      angleToEnemy = (angleToEnemy + 180) % 360 - 180

      if angleToEnemy >= minAngle and angleToEnemy <= maxAngle then
        local dist = toEnemy:LengthSquared()
        if dist < minDist then
          minDist = dist
          nearestEnemy = entity
        end
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
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then
    local target = Utils.GetMarkedTarget(player)
    if target then
      return (target.Position - player.Position):Normalized()
    end
  end
  if not player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK) then
    local fireDirection = player:GetFireDirection()
    return DIRECTION_MAP[fireDirection]
  end
  return player:GetAimDirection()
end

function Utils.GetFlattenedOrbitPosition(player, angle, radius)
  local aim = Utils.GetHeadVector(player) -- :Normalized()
  local perp = Vector(-aim.Y, aim.X)

  local x = math.cos(angle) * radius
  local y = math.sin(angle) * radius * 0.3 -- 1 circular, 0 flat

  return aim * x + perp * y
end

---@param amount number
function Utils.GetSulfurLaserVariant(amount)
  if amount <= 1 then
    return LaserVariant.THICK_RED
  elseif amount <= 2 then
    return LaserVariant.BRIM_TECH
  elseif amount <= 3 then
    return LaserVariant.THICKER_RED
  elseif amount <= 4 then
    return LaserVariant.THICKER_BRIM_TECH
  elseif amount <= 6 then
    return LaserVariant.GIANT_RED
  elseif amount <= 8 then
    return LaserVariant.GIANT_BRIM_TECH
  else
    return LaserVariant.BEAST
  end
end

---@param laserVariant LaserVariant
function Utils.GetAbsorbedLaserVariant(laserVariant)
  if laserVariant == LaserVariant.THIN_RED or laserVariant == LaserVariant.ELECTRIC then
    return LaserVariant.THIN_RED
  elseif laserVariant == LaserVariant.PRIDE or laserVariant == LaserVariant.THICK_BROWN then
    return LaserVariant.THICK_BROWN
  elseif laserVariant == LaserVariant.LIGHT_BEAM or laserVariant == LaserVariant.LIGHT_RING then
    return LaserVariant.LIGHT_RING
  else
    return LaserVariant.THICK_RED
  end
end

function Utils.ReplaceTNTWithTrollBombs()
  local room = Game():GetRoom()

  for i = 0, room:GetGridSize() - 1 do
    local grid = room:GetGridEntity(i)

    if grid and grid:GetType() == GridEntityType.GRID_TNT and grid.State < 4 then
      log.Value("Replacing TNT", {
        state = grid.State,
      })
      local pos = room:GetGridPosition(i)
      -- room:RemoveGridEntity(i, 0, false)
      Utils.SpawnEntity(
        EntityType.ENTITY_BOMB,
        BombVariant.BOMB_TROLL,
        pos,
        Vector.Zero
      )
    end
  end
end

return Utils
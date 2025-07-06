---@type Store
local Store = require("thesun-src.Store")
---@type Const
local Const = require("thesun-src.Const")
---@type Utils
local Utils = require("thesun-src.Utils") --
---@type PlayerUtils
local PlayerUtils = require("thesun-src.PlayerUtils") --

local wallDirection = 0 -- 00 = left, 10 = right, 01 = top, 11 = down
local PROJECTILE_SPAWN_OFFSET = 40
local PROJECTILE_DESPAWN_OFFSET = Vector(80, 80)

---@class WallFire
---@field PurgeWallProjectiles fun(topLeftPos: Vector, bottomRightPos: Vector): nil
---@field GetExtraBulletTrain fun(player: EntityPlayer): number
---@field SpawnBulletWall fun(player: EntityPlayer, spawnPos: Vector, velocity: Vector): nil
---@field GetWallSpawn fun(topLeft: Vector, bottomRight: Vector, roomShape: RoomShape): Vector, Vector
---@field WallShot fun(player: EntityPlayer): nil
---@field ClusterWallShot fun(player: EntityPlayer): nil

local WallFire = {}

---@param topLeftPos Vector
---@param bottomRightPos Vector
function WallFire.PurgeWallProjectiles(topLeftPos, bottomRightPos)
  local roomInit = topLeftPos - PROJECTILE_DESPAWN_OFFSET
  local roomEnd = bottomRightPos + PROJECTILE_DESPAWN_OFFSET
  for hash, proj in pairs(Store.WallProjectiles) do
    if proj and proj:Exists() and not proj:IsDead() then
      local pos = proj.Position
      if pos.X < roomInit.X or pos.X > roomEnd.X or pos.Y < roomInit.Y or pos.Y > roomEnd.Y then
        Store.WallProjectiles[hash] = nil
        proj:Remove()
      end
    else
      -- when the projectile is absorved
      Store.WallProjectiles[hash] = nil
    end
  end
end

--- @param player EntityPlayer
--- @return number
function WallFire.GetExtraBulletTrain(player)
  local bulletTrain = 0
  local amount = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_20_20)
  if amount > 0 then
    bulletTrain = bulletTrain + amount
  end
  amount = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_INNER_EYE)
  if amount > 0 then
    bulletTrain = bulletTrain + amount * 2
  end
  amount = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_MUTANT_SPIDER)
  if amount > 0 then
    bulletTrain = bulletTrain + amount * 3
  end
  if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then
    bulletTrain = bulletTrain + 2
  end
  if player:HasPlayerForm(PlayerForm.PLAYERFORM_BOOK_WORM) then
    if Const.rng:RandomFloat() < 0.25 then
      bulletTrain = bulletTrain + 1
    end
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_SORE) then
    bulletTrain = bulletTrain + Const.rng:RandomInt(4)
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LOKIS_HORNS) then
    local threshold = 0.25 + 0.05 * player.Luck
    if Const.rng:RandomFloat() < threshold then
      bulletTrain = bulletTrain + 3
    end
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_EYE) then
    local threshold = 0.5 + 0.1 * player.Luck
    if Const.rng:RandomFloat() < threshold then
      bulletTrain = bulletTrain + 1
    end
  end

  return math.min(bulletTrain, 12)
end

--- @param player EntityPlayer
--- @param spawnPos Vector
--- @param velocity Vector
function WallFire.SpawnBulletWall(player, spawnPos, velocity)
  local proj = Utils.SpawnEntity(
    EntityType.ENTITY_PROJECTILE,
    ProjectileVariant.PROJECTILE_NORMAL,
    spawnPos,
    velocity
  ):ToProjectile()
  if not proj then return end
  Store.WallProjectiles[GetPtrHash(proj)] = proj
  proj:AddProjectileFlags(ProjectileFlags.GHOST)
  if Utils.IsTheSun(player) or (player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and Const.rng:RandomFloat() < 0.5) then
    proj:AddProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER)
  end
  proj.FallingAccel = -0.1
  proj.FallingSpeed = 0
  proj.Scale = 0.25
  if player:HasCollectible(CollectibleType.COLLECTIBLE_SOY_MILK) or player:HasCollectible(CollectibleType.COLLECTIBLE_ALMOND_MILK) then
    proj.Scale = 0.1
    proj.Size = 2
  end
end

---@param player EntityPlayer
---@return Vector, Vector, number, number
local function GetWallSpawn(player)
  local room = Const.game:GetRoom()
  local roomShape = room:GetType()
  local topLeftPos = room:GetTopLeftPos()
  local bottomRightPos = room:GetBottomRightPos()

  WallFire.PurgeWallProjectiles(topLeftPos, bottomRightPos)
  local gridSize = (bottomRightPos - topLeftPos) / 40
  -- The Beast room has no standar size
  gridSize.X = math.floor(gridSize.X)
  gridSize.Y = math.floor(gridSize.Y)
  local pos, dir
  if wallDirection % 2 == 1 then
    -- Top o Bottom
    local x = Const.rng:RandomInt(gridSize.X - 1)
    pos = Vector(topLeftPos.X + x * Const.GRID_SIZE + 40, 0)

    if wallDirection == 1 then -- Top
      if (roomShape == RoomShape.ROOMSHAPE_LTL and x < 13) or (roomShape == RoomShape.ROOMSHAPE_LTR and x >= 13) then
        pos.Y = topLeftPos.Y + 240
      else
        pos.Y = topLeftPos.Y - PROJECTILE_SPAWN_OFFSET
      end
      dir = Vector(0, 1)
    else -- Bottom
      if (roomShape == RoomShape.ROOMSHAPE_LBL and x < 13) or (roomShape == RoomShape.ROOMSHAPE_LBR and x >= 13) then
        pos.Y = bottomRightPos.Y - 240
      else
        pos.Y = bottomRightPos.Y + PROJECTILE_SPAWN_OFFSET
      end
      dir = Vector(0, -1)
    end
  else
    -- Left o Right
    local y = Const.rng:RandomInt(gridSize.Y - 1)
    pos = Vector(0, topLeftPos.Y + y * Const.GRID_SIZE + 40)

    if wallDirection == 0 then -- Left
      if (roomShape == RoomShape.ROOMSHAPE_LTL and y < 7) or (roomShape == RoomShape.ROOMSHAPE_LBL and y >= 7) then
        pos.X = topLeftPos.X - 480
      else
        pos.X = topLeftPos.X - PROJECTILE_SPAWN_OFFSET
      end
      dir = Vector(1, 0)
    else -- Right
      if (roomShape == RoomShape.ROOMSHAPE_LTR and y < 7) or (roomShape == RoomShape.ROOMSHAPE_LBR and y >= 7) then
        pos.X = bottomRightPos.X + 480
      else
        pos.X = bottomRightPos.X + PROJECTILE_SPAWN_OFFSET
      end
      dir = Vector(-1, 0)
    end
  end
  local bulletTrain = 1 + WallFire.GetExtraBulletTrain(player)
  local wizOffset = player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) and 1 or 0
  local playerData = PlayerUtils.GetPlayerData(player)
  if wizOffset ~= 0 then
    bulletTrain = bulletTrain + 1
    dir = dir:Rotated(-45)
  elseif playerData.wizardRemainingFrames > 0 then
    playerData.wizardRemainingFrames = playerData.wizardRemainingFrames - player.MaxFireDelay
    dir = dir:Rotated(Const.rng:RandomInt(2) * 90 - 45)
  end
  return pos, dir, bulletTrain, wizOffset
end

--- @param player EntityPlayer
function WallFire.WallShot(player)
  local spawnPos, direction, bulletTrain, wizOffset = GetWallSpawn(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local currentFloor = Const.game:GetLevel():GetAbsoluteStage()
  local velMagnitude = 4 + currentFloor * 0.25
  local velocity = direction * velMagnitude
  for _ = 1, bulletTrain do
    WallFire.SpawnBulletWall(player, spawnPos, velocity)
    if wizOffset ~= 0 then
      velocity = velocity:Rotated(90 * wizOffset)
      wizOffset = -wizOffset
    end
    spawnPos = spawnPos - direction * 10
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
    playerData.leadPencilCount = playerData.leadPencilCount + 1
    if playerData.leadPencilCount > 15 then
      playerData.leadPencilCount = 0
      for _ = 1, 12 do
        local randomAngle = Const.rng:RandomFloat() * 20 - 10
        WallFire.SpawnBulletWall(
          player,
          spawnPos + Vector(randomAngle * 2, 0),
          velocity:Rotated(randomAngle)
        )
        spawnPos = spawnPos - direction * 10
      end
    end
  end

  wallDirection = (wallDirection + 1) % 4
end

--- @param player EntityPlayer
function WallFire.ClusterWallShot(player)
  local spawnPos, direction, bulletTrain = GetWallSpawn(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local velMagnitude = 4 * player.MoveSpeed   -- half of the player speed
  local velocity = direction * velMagnitude

  bulletTrain = bulletTrain + 12
  for _ = 1, bulletTrain do
    local randomAngle = Const.rng:RandomFloat() * 20 - 10
    WallFire.SpawnBulletWall(
      player,
      spawnPos + Vector(randomAngle * 2, 0),
      velocity:Rotated(randomAngle)
    )
    spawnPos = spawnPos - direction * 10
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
    playerData.leadPencilCount = playerData.leadPencilCount + 1
    if playerData.leadPencilCount > 15 then
      playerData.leadPencilCount = 0
      for _ = 1, bulletTrain do
        local randomAngle = Const.rng:RandomFloat() * 20 - 10
        WallFire.SpawnBulletWall(
          player,
          spawnPos + Vector(randomAngle * 2, 0),
          velocity:Rotated(randomAngle)
        )
        spawnPos = spawnPos - direction * 10
      end
    end
  end

  wallDirection = (wallDirection + 1) % 4
end

return WallFire

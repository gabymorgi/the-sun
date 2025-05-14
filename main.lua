---@alias EntityOrbital EntityTear | EntityProjectile | EntityEffect
---@alias Ludovico { Tear: EntityTear, BaseDamage: number, Multiplier: number, ExpFrames: number[], Index: number }

---@class Dict<T>: { [number]: T }

local log = include("log")
local Orbit = include("thesun-src.Orbit")
local Utils = include("thesun-src.Utils")
local ChargeBar = include("thesun-src.ChargeBar")
local TearOrbit = Orbit.TearOrbit
local ProjectileOrbit = Orbit.ProjectileOrbit
local EffectOrbit = Orbit.EffectOrbit

local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false)
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2")

local game = Game()
local rng = RNG()
local HALF_PI = math.pi / 2
local TWO_PI = math.pi * 2
local framesPerSecond = 25

---@alias WallDict { [number]: EntityProjectile }
---@type WallDict
local wallProjectiles = {}
local RADIUS_STEP_MULTIPLIER = 3
local PROJECTILE_SPAWN_OFFSET = 40
local GRID_SIZE = 40
local PROJECTILE_DESPAWN_OFFSET = Vector(80, 80)

--- helpers
--- @type { [number]: EntityTear }
local tearsToCheck = {}
--- @type { [number]: EntityEffect }
local effectToCheck = {}

-- synergy variables



--3/4
--2/3
--1/2
local playerInRoomMultiplier = {1, 0.75, 0.66, 0.6}
local roomMultiplier = {
  [RoomShape.ROOMSHAPE_1x1] = 1,
  [RoomShape.ROOMSHAPE_IH] = 1.25,
  [RoomShape.ROOMSHAPE_IV] = 1.25,
  [RoomShape.ROOMSHAPE_1x2] = 0.7,
  [RoomShape.ROOMSHAPE_IIV] = 0.8,
  [RoomShape.ROOMSHAPE_2x1] = 0.7,
  [RoomShape.ROOMSHAPE_IIH] = 0.8,
  [RoomShape.ROOMSHAPE_2x2] = 0.5,
  [RoomShape.ROOMSHAPE_LTL] = 0.6,
  [RoomShape.ROOMSHAPE_LTR] = 0.6,
  [RoomShape.ROOMSHAPE_LBL] = 0.6,
  [RoomShape.ROOMSHAPE_LBR] = 0.6,
}
-- local roomDelay = 10
-- local current = 0
local cachedRoomShape = RoomShape.ROOMSHAPE_1x1
local cachedPlayerCount = 1
local wallDirection = 0 -- 00 = left, 10 = right, 01 = top, 11 = down

---@param entityType EntityType
---@param variant number
---@param spawnPos Vector
---@param velocity Vector
---@param player? EntityPlayer
---@param subType? number
---@param seed? number
local function SpawnEntity(entityType, variant, spawnPos, velocity, player, subType, seed)
  return game:Spawn(
    entityType,
    variant,
    spawnPos,
    velocity,
    player,
    subType or 0,
    seed or game:GetRoom():GetSpawnSeed()
  )
end

--- @param player EntityPlayer
--- @return number
local function getExtraBulletTrain(player)
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
    if rng:RandomFloat() < 0.25 then
      bulletTrain = bulletTrain + 1
    end
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_SORE) then
    bulletTrain = bulletTrain + rng:RandomInt(4)
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LOKIS_HORNS) then
    local threshold = 0.25 + 0.05 * player.Luck
    if rng:RandomFloat() < threshold then
      bulletTrain = bulletTrain + 3
    end
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_EYE) then
    local threshold = 0.5 + 0.1 * player.Luck
    if rng:RandomFloat() < threshold then
      bulletTrain = bulletTrain + 1
    end
  end

  return math.min(bulletTrain, 12)
end

---@param player EntityPlayer
---@return boolean
local function IsTheSun(player)
  if (player:GetPlayerType() == theSunType) then
    return true
  end
  return false
end

-- for _,player in pairs(GetPlayers()) do
--- @return EntityPlayer[]
local function GetPlayers()
  local players = {}
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    if IsTheSun(player) then
      table.insert(players, player)
    end
  end
  return players
end

---@param position Vector
---@param radius number
---@return Entity[]
local function GetEnemiesInRange(position, radius)
  local enemies = {}
  for _, entity in pairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
    if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_NO_TARGET) then
      table.insert(enemies, entity)
    end
  end
  return enemies
end

--- @param player EntityPlayer
local function GetMarkedTarget(player)
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.TARGET)) do
		local spawner = entity.SpawnerEntity
		
		if spawner and GetPtrHash(spawner) == GetPtrHash(player) then
			return entity:ToEffect()
		end
	end
	return nil
end


---@class PlayerData
---@field tearOrbit Orbit<EntityTear>
---@field projOrbit Orbit<EntityProjectile>
---@field effectOrbit Orbit<EntityEffect>
---@field orbitRange { min: number, max: number, act: number }
---@field cacheCollectibles Dict<number | boolean>
---@field activeBars Dict<ChargeBar>
---@field leadPencilCount number
---@field friendlySpiderCount number
---@field wizardRemainingFrames number
---@field ludodivo Ludovico | nil

---@type { [number]: PlayerData }
local PlayerData = {}

---@param player EntityPlayer
---@return PlayerData
local function GetPlayerData(player)
  local playerHash = GetPtrHash(player)
  if not PlayerData[playerHash] then
    PlayerData[playerHash] = {
      tearOrbit = TearOrbit:new(),
      projOrbit = ProjectileOrbit:new(),
      effectOrbit = EffectOrbit:new(),
      orbitRange = {
        min = GRID_SIZE,
        max = 90,
        act = GRID_SIZE,
      },
      cacheCollectibles = {
        [CollectibleType.COLLECTIBLE_DR_FETUS] = false,
        [CollectibleType.COLLECTIBLE_EPIC_FETUS] = false,
        [CollectibleType.COLLECTIBLE_IPECAC] = false,
      },
      activeBars = {},
      leadPencilCount = 0,
      friendlySpiderCount = 0,
      wizardRemainingFrames = 0,
      ludodivo = nil,
    }
  end
  return PlayerData[playerHash]
end

---@param player EntityPlayer
local function CachePlayerCollectibles(player)
  local playerData = GetPlayerData(player)
  local evaluate = false
  local value
  value = player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS)
  if value ~= playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_DR_FETUS] then
    playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_DR_FETUS] = value
    playerData.orbitRange.min = value and 100 or GRID_SIZE
    playerData.orbitRange.act = Utils.Clamp(playerData.orbitRange.act, playerData.orbitRange.min, playerData.orbitRange.max)
  end
  value = player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS)
  if value ~= playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_EPIC_FETUS] then
    playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_EPIC_FETUS] = value
    playerData.orbitRange.min = value and 100 or GRID_SIZE
    playerData.orbitRange.act = Utils.Clamp(playerData.orbitRange.act, playerData.orbitRange.min, playerData.orbitRange.max)
  end
  value = player:HasCollectible(CollectibleType.COLLECTIBLE_IPECAC)
  if value ~= playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_IPECAC] then
    playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_IPECAC] = value
    playerData.orbitRange.min = value and 100 or GRID_SIZE
    playerData.orbitRange.act = Utils.Clamp(playerData.orbitRange.act, playerData.orbitRange.min, playerData.orbitRange.max)
  end
  -- more collectibles
  if evaluate then
    player:EvaluateItems()
  end
end

--- @param player EntityPlayer
local function ReleaseHomingTears(player)
  local playerData = GetPlayerData(player)
  local enemies = GetEnemiesInRange(player.Position, playerData.orbitRange.max + GRID_SIZE)
  for hash, orb in pairs(playerData.tearOrbit.list) do
    local closestEnemy = nil
    local closestEnemyDist = 80 ^ 2
    for _, enemy in pairs(enemies) do
      local dist = enemy.Position:DistanceSquared(orb.entity.Position)
      if dist < closestEnemyDist then
        closestEnemy = enemy
        closestEnemyDist = dist
      end
    end
    if closestEnemy then
      orb.entity.Velocity = (closestEnemy.Position - orb.entity.Position):Normalized() * player.ShotSpeed
      playerData.tearOrbit:remove(hash)
    end
  end
end

--- @param player EntityPlayer
--- @param releaseOrbit boolean?
local function ExpandHomingTears(player, releaseOrbit)
  local playerData = GetPlayerData(player)
  local enemies
  local step = player.ShotSpeed * RADIUS_STEP_MULTIPLIER * 2
  local epsilon = 0.5
  for hash, orb in pairs(playerData.tearOrbit.list) do
    local closestEnemy = nil
    local closestEnemyDist = math.huge
    if not orb.target or not orb.target:Exists() then
      if not enemies then
        enemies = GetEnemiesInRange(player.Position, playerData.orbitRange.max)
      end
      for _, enemy in pairs(enemies) do
        local dist = enemy.Position:DistanceSquared(orb.entity.Position)
        if dist < closestEnemyDist then
          closestEnemy = enemy
          closestEnemyDist = dist
        end
      end
      orb.target = closestEnemy
    else
      closestEnemy = orb.target
    end
    local targetRadius = playerData.orbitRange.act
    if orb.target then
      if releaseOrbit then
        orb.entity.Velocity = (orb.target.Position - orb.entity.Position):Normalized() * player.ShotSpeed
        playerData.tearOrbit:remove(hash)
      else
        local clockWiseSign = Utils.GetClockwiseSign2(player.Position, orb.entity.Position, orb.target.Position)
        orb.direction = orb.direction + clockWiseSign * 0.1
        targetRadius = math.min(orb.target.Position:Distance(player.Position), playerData.orbitRange.max)
        log:Value("radius", {
          hash = hash,
          distance = orb.target.Position:Distance(player.Position),
          orbRange = orb.radius,
          targetRadius = targetRadius,
        })
      end
    end
    local diff = targetRadius - orb.radius
    if math.abs(diff) < epsilon then
      orb.radius = targetRadius
    elseif diff > 0 then
      orb.radius = math.min(orb.radius + step, targetRadius)
    else
      orb.radius = math.max(orb.radius - step, targetRadius)
    end
  end
end

--- @param player EntityPlayer
--- @param entityOrbit Orbit<EntityOrbital>
local function ExpandOrbitingTears(player, entityOrbit)
  local playerData = GetPlayerData(player)
  local step = player.ShotSpeed * RADIUS_STEP_MULTIPLIER
  local target = playerData.orbitRange.act
  local epsilon = 0.5
  for _, orb in pairs(entityOrbit.list) do
    local diff = target - orb.radius
    if math.abs(diff) < epsilon then
      orb.radius = target
    elseif diff > 0 then
      orb.radius = math.min(orb.radius + step, target)
    else
      orb.radius = math.max(orb.radius - step, target)
    end
  end
end

--- @param player EntityPlayer
--- @param entityOrbit Orbit<EntityOrbital>
local function ExplodeOrbitingTears(player, entityOrbit)
  for _, orb in pairs(entityOrbit.list) do
    local explosion = SpawnEntity(
      EntityType.ENTITY_BOMB,
      BombVariant.BOMB_NORMAL,
      orb.entity.Position,
      Vector.Zero,
      player
    ):ToBomb()
    if explosion then
      explosion:SetExplosionCountdown(0)
    end
    orb.entity:Remove()
  end
end

--- @param player EntityPlayer
--- @param entityOrbit Orbit<EntityOrbital>
local function SpinOrbitingTears(player, entityOrbit)
  for _, orb in pairs(entityOrbit.list) do
    local vel = player.ShotSpeed / math.sqrt(orb.radius)
    orb.angle = orb.angle + orb.direction * vel
    local offset = Vector(math.cos(orb.angle), math.sin(orb.angle)) * orb.radius
    orb.entity.Position = player.Position + offset
    -- tear orientation
    local tangentAngle = orb.angle + orb.direction * HALF_PI
    orb.entity.Velocity = Vector(math.cos(tangentAngle), math.sin(tangentAngle))
  end
end

---@param topLeftPos Vector
---@param bottomRightPos Vector
local function PurgeWallProjectiles(topLeftPos, bottomRightPos)
  local roomInit = topLeftPos - PROJECTILE_DESPAWN_OFFSET
  local roomEnd = bottomRightPos + PROJECTILE_DESPAWN_OFFSET
  for hash, proj in pairs(wallProjectiles) do
    if proj and proj:Exists() and not proj:IsDead() then
      local pos = proj.Position
      if pos.X < roomInit.X or pos.X > roomEnd.X or pos.Y < roomInit.Y or pos.Y > roomEnd.Y then
        wallProjectiles[hash] = nil
        proj:Remove()
      end
    else
      -- when the projectile is absorved
      wallProjectiles[hash] = nil
    end
  end
end

---@param entityOrbit Orbit<EntityOrbital>
---@param gameFrameCount number
local function PurgeOrbitingEntities(entityOrbit, gameFrameCount)
  for hash, orb in pairs(entityOrbit.list) do
    if not (orb.entity and orb.entity:Exists() and not orb.entity:IsDead()) or orb.expirationFrame < gameFrameCount then
      entityOrbit:remove(hash)
    end
  end
end

--- @param player EntityPlayer
--- @param spawnPos Vector
--- @param velocity Vector
local function SpawnBulletWall(player, spawnPos, velocity)
  local proj = SpawnEntity(
    EntityType.ENTITY_PROJECTILE,
    ProjectileVariant.PROJECTILE_TEAR,
    spawnPos,
    velocity,
    player
  ):ToProjectile()
  if not proj then return end
  wallProjectiles[GetPtrHash(proj)] = proj
  proj:AddProjectileFlags(ProjectileFlags.GHOST | ProjectileFlags.CANT_HIT_PLAYER)
  proj.FallingAccel = -0.1
  proj.FallingSpeed = 0
  -- proj.CollisionDamage = player.Damage
  -- proj.Size = GetProjectileSize(player.Damage)
  proj.Scale = 0.5   -- GetProjectileScale(player.Damage)
end

--- @param player EntityPlayer
local function FireFromWall(player)
  local room = game:GetRoom()
  local roomShape = room:GetType()
  local topLeftPos = room:GetTopLeftPos()
  local bottomRightPos = room:GetBottomRightPos()
  local roomGridSize = (bottomRightPos - topLeftPos) / 40

  PurgeWallProjectiles(topLeftPos, bottomRightPos)

  local velMagnitude = 4 * player.MoveSpeed   -- half of the player speed

  local spawnPos, direction
  if wallDirection & 1 ~= 0 then
    local x = rng:RandomInt(roomGridSize.X)
    spawnPos = Vector(topLeftPos.X + x * GRID_SIZE + 20, 0)
    if wallDirection == 1 then     -- top
      if (roomShape == RoomShape.ROOMSHAPE_LTL and x < 13) or (roomShape == RoomShape.ROOMSHAPE_LTR and x >= 13) then
        spawnPos.Y = topLeftPos.Y + 240
      else
        spawnPos.Y = topLeftPos.Y - PROJECTILE_SPAWN_OFFSET
      end
      direction = Vector(0, 1)
    else     -- bottom
      if (roomShape == RoomShape.ROOMSHAPE_LBL and x < 13) or (roomShape == RoomShape.ROOMSHAPE_LBR and x >= 13) then
        spawnPos.Y = bottomRightPos.Y - 240
      else
        spawnPos.Y = bottomRightPos.Y + PROJECTILE_SPAWN_OFFSET
      end
      direction = Vector(0, -1)
    end
  else
    local y = rng:RandomInt(roomGridSize.Y)
    spawnPos = Vector(0, topLeftPos.Y + y * GRID_SIZE + 20)
    if wallDirection == 0 then     -- left
      if (roomShape == RoomShape.ROOMSHAPE_LTL and y < 7) or (roomShape == RoomShape.ROOMSHAPE_LBL and y >= 7) then
        spawnPos.X = topLeftPos.X - 480
      else
        spawnPos.X = topLeftPos.X - PROJECTILE_SPAWN_OFFSET
      end
      direction = Vector(1, 0)
    else     -- right
      if (roomShape == RoomShape.ROOMSHAPE_LTR and y < 7) or (roomShape == RoomShape.ROOMSHAPE_LBR and y >= 7) then
        spawnPos.X = bottomRightPos.X + 480
      else
        spawnPos.X = bottomRightPos.X + PROJECTILE_SPAWN_OFFSET
      end
      direction = Vector(-1, 0)
    end
  end

  local playerData = GetPlayerData(player)
  local bulletTrain = 1 + getExtraBulletTrain(player)
  local theWizOffset = player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) and 1 or 0
  if theWizOffset ~= 0 then
    bulletTrain = bulletTrain + 1
    direction = direction:Rotated(-45)
  elseif playerData.wizardRemainingFrames > 0 then
    playerData.wizardRemainingFrames = playerData.wizardRemainingFrames - player.MaxFireDelay
    direction = direction:Rotated(rng:RandomInt(2) * 90 - 45)
  end
  
  local velocity = direction * velMagnitude
  for _ = 1, bulletTrain do
    SpawnBulletWall(player, spawnPos, velocity)
    if theWizOffset ~= 0 then
      velocity = velocity:Rotated(90 * theWizOffset)
      theWizOffset = -theWizOffset
    end
    spawnPos = spawnPos - direction * 10
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
    playerData.leadPencilCount = playerData.leadPencilCount + 1
    if playerData.leadPencilCount > 15 then
      playerData.leadPencilCount = 0
      for _ = 1, 12 do
        local randomAngle = rng:RandomFloat() * 20 - 10
        SpawnBulletWall(
          player,
          spawnPos + Vector(randomAngle * 2, 0),
          velocity:Rotated(randomAngle)
        )
        spawnPos = spawnPos - direction * 10
      end
    end
  end

  wallDirection = wallDirection + 1
  if wallDirection > 3 then wallDirection = 0 end
end

--- @param playerPos Vector
--- @param proj EntityProjectile
local function IsProjectileBehindPlayer(playerPos, proj)
  local toProj = (proj.Position - playerPos):Normalized()
  local velocity = proj.Velocity:Normalized()

  -- 0 = side, 1 = back, -1 = front
  return velocity:Dot(toProj) > 0.1
end

--- @param player EntityPlayer
--- @param orb Orbital<EntityTear>
local function CalculatePostTearSynergies(player, orb)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_WIG) then
    local playerData = GetPlayerData(player)
    if playerData.friendlySpiderCount < 5 then
      local prob = player.Luck < 10 and 1 / (20 - (2 * player.Luck)) or 1
      if rng:RandomFloat() < prob then
        SpawnEntity(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, player.Position, Vector.Zero, player)
        playerData.friendlySpiderCount = playerData.friendlySpiderCount + 1
      end
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
    if rng:RandomFloat() < 0.05 then
      local zitTear = player:FireTear(player.Position, orb.entity.Velocity, false, true, false, player, 2)
      zitTear.TearFlags = TearFlags.TEAR_SLOW
      GetPlayerData(player).tearOrbit:add(player, zitTear)
      SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, orb.entity.Position, Vector.Zero, player)
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_AKELDAMA) then
    local akeldamaTear = player:FireTear(player.Position, orb.entity.Velocity, false, true, false)
    akeldamaTear.TearFlags = TearFlags.TEAR_CHAIN | TearFlags.TEAR_SPECTRAL
    akeldamaTear.CollisionDamage = 3.5
    akeldamaTear.Size = 7
    akeldamaTear.Scale = 1
    akeldamaTear:ChangeVariant(TearVariant.BLOOD)
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_IMMACULATE_HEART) then
    if rng:RandomFloat() < 0.2 then
      local immaculateTear = player:FireTear(player.Position, orb.entity.Velocity, false)
      local immaculateOrb = GetPlayerData(player).tearOrbit:add(player, immaculateTear)
      immaculateOrb.direction = immaculateOrb.direction * -1
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_GHOST_PEPPER)) then
    local prob = math.min(1/(12 - player.Luck), 0.5)
    if rng:RandomFloat() < prob then
      local fire = SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, orb.entity.Position, Vector(10, 0), player):ToEffect()
      if fire then
        GetPlayerData(player).effectOrbit:add(player, fire)
      end
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE)) then
    local prob = math.min(1/(12 - player.Luck), 0.5)
    if rng:RandomFloat() < prob then
      local fire = SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, orb.entity.Position, Vector.Zero, player):ToEffect()
      if fire then
        GetPlayerData(player).effectOrbit:add(player, fire)
      end
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_CHEMICAL_PEEL)) then
    if orb.direction == 1 then
      orb.entity.CollisionDamage = orb.entity.CollisionDamage + 2
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_BLOOD_CLOT)) then
    if orb.direction == 1 then
      orb.entity.CollisionDamage = orb.entity.CollisionDamage + 1
      orb.expirationFrame = orb.expirationFrame + 40 -- more range
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_POP)) then
    orb.direction = orb.direction * 0.5
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_PROPTOSIS) then
    orb.direction = orb.direction * 2
  end
end

--- @param player EntityPlayer
local function TryAbsorbTears(player)
  local nearby = Isaac.FindInRadius(player.Position, 60, EntityPartition.BULLET)
  for _, ent in ipairs(nearby) do
    local proj = ent:ToProjectile()
    if proj and IsProjectileBehindPlayer(player.Position, proj) then
      local playerData = GetPlayerData(player)
      local projHash = GetPtrHash(proj)
      if wallProjectiles[projHash] then
        if not playerData.tearOrbit:hasSpace() then
          proj:Remove()
          goto continue
        end
        local tear
        if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
          tear = player:FireKnife(player, 0, false, KnifeVariant.SPIRIT_SWORD, 0)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) and playerData.ludodivo then
          tear = playerData.ludodivo.Tear
          playerData.ludodivo.Multiplier = playerData.ludodivo.Multiplier + 0.1
          playerData.ludodivo.Tear.CollisionDamage = playerData.ludodivo.BaseDamage * playerData.ludodivo.Multiplier
          table.insert(playerData.ludodivo.ExpFrames, game:GetFrameCount() + 30 * framesPerSecond)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) then
          tear = player:FireBomb(proj.Position, proj.Velocity, player)
        else
          tear = player:FireTear(proj.Position, proj.Velocity, true, true, true)
        end
        proj:Remove()
        -- tear.TearFlags = tear.TearFlags | TearFlags.TEAR_ORBIT
        if tear then
          local orb = GetPlayerData(player).tearOrbit:add(player, tear --[[@as EntityTear]])
          CalculatePostTearSynergies(player, orb)
        end
      elseif not playerData.projOrbit.list[projHash] then
        if not proj:HasProjectileFlags(ProjectileFlags.HIT_ENEMIES) and playerData.projOrbit:hasSpace() then
          playerData.projOrbit:add(player, proj)
        end
      end
    end
    ::continue::
  end
end

--- Detecta colisiones entre tears orbitando basado en su ángulo y radio
--- @param tearOrbit Orbit<EntityTear>
--- @param orbitRadius number
local function CheckOrbitingTearCollisions(tearOrbit, orbitRadius)
  local tearSize = 24
  local minAngle = tearSize / orbitRadius   -- arco = longitud / radio
  -- Convertimos la tabla en un array ordenable
  local sorted = {}
  for _, orbital in pairs(tearOrbit.list) do
    local pre = orbital.angle
    orbital.angle = orbital.angle % TWO_PI
    table.insert(sorted, orbital)
  end

  table.sort(sorted, function(a, b)
    return a.angle < b.angle
  end)

  for i = 1, #sorted - 1 do
    local t1 = sorted[i]
    local t2 = sorted[i + 1]
    local delta = math.abs(t1.angle - t2.angle)
    if delta < minAngle then
      -- Colisión entre t1 y t2
      tearOrbit:remove(GetPtrHash(t1.entity))
    end
  end
end

---@param player EntityPlayer
local function UpdateOrbitingRadius(player)
  local playerData = GetPlayerData(player)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then
    local target = GetMarkedTarget(player)
    if target then
      playerData.orbitRange.act = Utils.Clamp(
        target.Position:Distance(player.Position),
        playerData.orbitRange.min,
        playerData.orbitRange.max
      )
    end
  else
    if player:GetShootingInput():Length() > 0 then
      if (playerData.orbitRange.act < playerData.orbitRange.max) then
        playerData.orbitRange.act = playerData.orbitRange.act + RADIUS_STEP_MULTIPLIER
      end
    else
      if (playerData.orbitRange.act > playerData.orbitRange.min) then
        playerData.orbitRange.act = playerData.orbitRange.act - RADIUS_STEP_MULTIPLIER
      end
    end
  end
end

---@param player EntityPlayer
local function UpdateOrbitingTears(player)
  local playerData = GetPlayerData(player)
  local gameFrameCount = game:GetFrameCount()
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) and playerData.ludodivo then
    local input = player:GetShootingInput()
    local aimDir = player:GetAimDirection()
		local fireDir = player:GetFireDirection()
    log:Value("input", {
      -- shootingInput = input.X .. ", " .. input.Y,
      aimDir = aimDir.X .. ", " .. aimDir.Y,
      fireDir = fireDir,
    })
    if (playerData.ludodivo.ExpFrames[playerData.ludodivo.Index] and playerData.ludodivo.ExpFrames[playerData.ludodivo.Index] < gameFrameCount) then
      playerData.ludodivo.Index = playerData.ludodivo.Index + 1
      playerData.ludodivo.Multiplier = playerData.ludodivo.Multiplier - 0.1
      playerData.ludodivo.Tear.CollisionDamage = playerData.ludodivo.BaseDamage * playerData.ludodivo.Multiplier
    end
    return
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
    if player:GetShootingInput():Length() > 0 then
      ExplodeOrbitingTears(player, playerData.tearOrbit)
    end
  end
  
  PurgeOrbitingEntities(playerData.tearOrbit, gameFrameCount)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT) then
    local distanceSquared = playerData.orbitRange.max ^ 2
    for _, orb in pairs(playerData.tearOrbit.list) do
      if orb.entity.Position:DistanceSquared(player.Position) > distanceSquared then
        local direction = (orb.entity.Position - player.Position):Normalized()
        orb.entity.Position = player.Position + direction * playerData.orbitRange.max
      end
    end
  else
    if (
      player:HasCollectible(CollectibleType.COLLECTIBLE_SPOON_BENDER) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_SACRED_HEART) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_GODHEAD)
    ) then
      ExpandHomingTears(player)
    else
      if player:HasTrinket(TrinketType.TRINKET_BRAIN_WORM) and gameFrameCount % 8 == 0 then
        ReleaseHomingTears(player)
      end
      ExpandOrbitingTears(player, playerData.tearOrbit)
    end
    SpinOrbitingTears(player, playerData.tearOrbit)
    local hasPop = player:HasCollectible(CollectibleType.COLLECTIBLE_POP)
    if (hasPop and gameFrameCount % 4 == 0) then -- artificial delay for the pop effect
      CheckOrbitingTearCollisions(playerData.tearOrbit, playerData.orbitRange.act)
    end
  end
end

---@param player EntityPlayer
local function UpdateOrbitingEntities(player)
  local gameFrameCount = game:GetFrameCount()
  local playerData = GetPlayerData(player)
  PurgeOrbitingEntities(playerData.projOrbit, gameFrameCount)
  ExpandOrbitingTears(player, playerData.projOrbit)
  SpinOrbitingTears(player, playerData.projOrbit)
  PurgeOrbitingEntities(playerData.effectOrbit, gameFrameCount)
  ExpandOrbitingTears(player, playerData.effectOrbit)
  SpinOrbitingTears(player, playerData.effectOrbit)
end

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
  if not IsTheSun(player) then return end

  player:AddNullCostume(hairCostume)

  local players = GetPlayers()
  if #players ~= cachedPlayerCount then
    cachedPlayerCount = math.max(#players, 4)
    for _, p in pairs(players) do
      p:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
      p:EvaluateItems()
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.GiveCostumesOnInit)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheRange(player)
  if not IsTheSun(player) then return end

  GetPlayerData(player).orbitRange.max = player.TearRange / 3
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheRange, CacheFlag.CACHE_RANGE)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFlight(player)
  if not IsTheSun(player) then return end

  player.CanFly = true
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFlight, CacheFlag.CACHE_FLYING)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFireDelay(player)
  if not IsTheSun(player) then return end

  log:Value("onEvaluateCacheFireDelay", player.MaxFireDelay)

  player.MaxFireDelay = playerInRoomMultiplier[cachedPlayerCount] * roomMultiplier[cachedRoomShape] * player.MaxFireDelay
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFireDelay, CacheFlag.CACHE_FIREDELAY)

---@param entity Entity
function theSunMod:OnEntityDeath(entity)
  if entity.Type == EntityType.ENTITY_FAMILIAR and entity.Variant == FamiliarVariant.BLUE_SPIDER then
    local player = entity.SpawnerEntity:ToPlayer()
    if not player or not IsTheSun(player) then return end
    local playerData = GetPlayerData(player)
    playerData.friendlySpiderCount = math.max(0, playerData.friendlySpiderCount - 1)
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, theSunMod.OnEntityDeath)

local function HandleRoomEnter()
  local players = GetPlayers()
  if #players == 0 then return end

  tearsToCheck = {}
  effectToCheck = {}
  wallProjectiles = {}
  for _, player in pairs(players) do
    local playerData = GetPlayerData(player)
    playerData.tearOrbit = TearOrbit:new()
    playerData.projOrbit = ProjectileOrbit:new()
    playerData.effectOrbit = EffectOrbit:new()

    if (player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE)) then
      local tear = player:FireTear(
        player.Position,
        player.Velocity,
        false,
        true,
        true
      )
      tear:AddTearFlags(TearFlags.TEAR_LUDOVICO | TearFlags.TEAR_OCCULT)
      playerData.ludodivo = {
        Tear = tear,
        BaseDamage = tear.CollisionDamage,
        Multiplier = 0.5,
        ExpFrames = {},
        Index = 0,
      }
    end
  end

  local room = game:GetRoom()
  local roomShape = room:GetRoomShape()
  if (cachedRoomShape ~= roomShape) then
    cachedRoomShape = roomShape
    for _, player in pairs(players) do
      player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
      player:EvaluateItems()
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HandleRoomEnter)

---@param tear EntityTear
---@param collider Entity
function theSunMod:OnTearCollision(tear, collider)
  -- log:Value("OnTearCollision", {
  --   flags = log:Flag("tear", tear.TearFlags),
  --   variant = log:Enum("tear", tear.Variant),
  --   collision = tear.CollisionDamage,
  -- })
  local player = tear.SpawnerEntity:ToPlayer()
  if not player or not IsTheSun(player) then
    return
  end
  local playerData = GetPlayerData(player)
  local tearHash = GetPtrHash(tear)
  if not playerData.tearOrbit.list[tearHash] then
    return
  end
  if collider:IsActiveEnemy() and collider:IsVulnerableEnemy() then
    local isPiercing = tear:HasTearFlags(TearFlags.TEAR_PIERCING)
    -- sticky: explosivo - sinus infection - mucormycosis
    local isSticky = tear:HasTearFlags(TearFlags.TEAR_STICKY | TearFlags.TEAR_BOOGER | TearFlags.TEAR_SPORE)
    if not isPiercing or isSticky then
      if tear:HasTearFlags(TearFlags.TEAR_BOUNCE) and not playerData.tearOrbit.list[tearHash].bounced then
        playerData.tearOrbit.list[tearHash].bounced = true
        playerData.tearOrbit.list[tearHash].direction = -playerData.tearOrbit.list[tearHash].direction
        -- TODO: select the correct player
        -- local player = Isaac.GetPlayer(0)
        -- SpinOrbitingTear(player, orbitingEntity[tearHash])
        -- tear:Update()
      else
        playerData.tearOrbit:remove(tearHash)
      end
    end
  end
end

theSunMod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, theSunMod.OnTearCollision)

function theSunMod:OnUpdate()
  local players = GetPlayers()

  if #players > 0 then
    local room = game:GetRoom()
    -- if not room:IsClear() then -- TOMOD
    if true then
      for _, player in pairs(players) do
        -- current = current + 1
        if player.FireDelay <= 0 then
          FireFromWall(player)
          player.FireDelay = player.MaxFireDelay
        end
        TryAbsorbTears(player)
      end
    end
    for _, player in pairs(players) do
      UpdateOrbitingRadius(player)
      UpdateOrbitingEntities(player)
      UpdateOrbitingTears(player)
      if game:GetFrameCount() % 32 == 0 then -- once every seconds
        CachePlayerCollectibles(player)
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, theSunMod.OnUpdate)

--- @param pillEffect PillEffect
--- @param player EntityPlayer
function theSunMod:OnUsePill(pillEffect, player, _)
  if pillEffect == PillEffect.PILLEFFECT_WIZARD and IsTheSun(player) then
    GetPlayerData(player).wizardRemainingFrames = 30 * framesPerSecond -- 30 segundos
  end
end
theSunMod:AddCallback(ModCallbacks.MC_USE_PILL, theSunMod.OnUsePill)

--- Accessing the initialized entity does provide incomplete data in some use cases
--- @param tear EntityTear
function theSunMod:HandleTearInit(tear)
  local player = tear.SpawnerEntity:ToPlayer()
  if not player or not IsTheSun(player) then return end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_ANGELIC_PRISM) then
    tearsToCheck[GetPtrHash(tear)] = tear
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, theSunMod.HandleTearInit, TearVariant.BLUE)

--- @param tear EntityTear
function theSunMod:HandleTearUpdate(tear)
  local hash = GetPtrHash(tear)
  if tearsToCheck[hash] then
    tearsToCheck[hash] = nil
    local player = tear.SpawnerEntity:ToPlayer()
    if not player or not IsTheSun(player) then return end
    local color = Utils.GetColorOffset(tear)

    if color then
      local playerData = GetPlayerData(player)
      if (playerData.tearOrbit:hasSpace()) then
        local newOrb = playerData.tearOrbit:add(player, tear)
        newOrb.direction = newOrb.direction * Utils.colorOffsets[color].rangeMultiplier
      else
        tear.Velocity = tear.Velocity * 10
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, theSunMod.HandleTearUpdate, TearVariant.BLUE)

--- @param effect EntityEffect
function theSunMod:HandleEffectInit(effect)
  -- log:Value("HandleEffectInit", {
  --   variant = log:Enum("effect", effect.Variant),
  --   damage = effect.DamageSource,
  --   SpawnerEntity = effect.SpawnerEntity,
  --   CollisionDamage = effect.CollisionDamage,
  --   Timeout = effect.Timeout,
  --   LifeSpan = effect.LifeSpan,
  --   FallingAcceleration = effect.FallingAcceleration,
  --   FallingSpeed = effect.FallingSpeed,
  -- })
  
  -- local player = effect.SpawnerEntity:ToPlayer()
  -- if not player then
  --   return
  -- end
  -- if not IsTheSun(player) then
  --   return
  -- end
  -- effectToCheck[GetPtrHash(effect)] = effect
  if (#GetPlayers() < 1) then return end
  local closestPlayer = nil
  local closestDistance = math.huge
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_EVIL_EYE) then
      local distance = player.Position:DistanceSquared(effect.Position)
      if distance < closestDistance then
        closestDistance = distance
        closestPlayer = player
      end
    end
  end
  if closestPlayer and IsTheSun(closestPlayer) then
    GetPlayerData(closestPlayer).effectOrbit:add(closestPlayer, effect)
  end
  
end
theSunMod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, theSunMod.HandleEffectInit, EffectVariant.EVIL_EYE)

-- --- @param effect EntityEffect
-- function theSunMod:HandleEffectUpdate(effect)
--   local hash = GetPtrHash(effect)
--   if effectToCheck[hash] then
--     effectToCheck[hash] = nil

--     if effect.Variant == EffectVariant.EVIL_EYE then
--       local player = effect.SpawnerEntity:ToPlayer()
--       if not player then
--         return
--       end
--       AddToOrbitals(player, effect)
--     end
--   end
-- end
-- theSunMod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, theSunMod.HandleEffectUpdate, EffectVariant.EVIL_EYE)



--------------------------------------------------------------------------------------------------

function theSunMod:HandleProjInit(proj)
  -- log:Value("HandleProjInit", {
  --   flags = proj.ProjectileFlags, -- log:Flag("proj", proj.ProjectileFlags),
  --   variant = proj.Variant,       -- log:Enum("proj", proj.Variant),
  --   color = proj.Color,
  --   spawnerType = proj.SpawnerType,
  --   spawnerVariant = proj.SpawnerVariant,
  -- })
  local player = proj.SpawnerEntity:ToPlayer()
  if not player then
    return
  end
  if not IsTheSun(player) then
    return
  end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, theSunMod.HandleProjInit)

--- @param knife EntityKnife
function theSunMod:HandleKnifeInit(knife)
  -- log:Value("HandleKnifeInit", {
  --   flags = log:Flag("proj", knife.TearFlags),
  --   variant = knife.Variant, -- log:Enum("proj", proj.Variant),
  --   rotation = knife.Rotation,
  --   rotationOffset = knife.RotationOffset,
  -- })
end

theSunMod:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, theSunMod.HandleKnifeInit)



--- @param tear EntityTear
function theSunMod:HandleFireTear(tear, player)
  -- log:Value("tear", {
  --   Variant = log:Enum("tear", tear.Variant),
  --   Flags = log:Flag("tear", tear.TearFlags),
  --   collision = tear.CollisionDamage,
  --   base = tear.BaseDamage,
  -- })
end
theSunMod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, theSunMod.HandleFireTear)

--------------------------------------------------------------------------------------------------

local PLUTO_TYPE = Isaac.GetPlayerTypeByName("Pluto", true)
local HOLY_OUTBURST_ID = Isaac.GetItemIdByName("Holy Outburst")

---@param player EntityPlayer
function theSunMod:PlutoInit(player)
  if player:GetPlayerType() ~= PLUTO_TYPE then
    return
  end

  player:SetPocketActiveItem(HOLY_OUTBURST_ID, ActiveSlot.SLOT_POCKET, true)

  local pool = game:GetItemPool()
  pool:RemoveCollectible(HOLY_OUTBURST_ID)
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.PlutoInit)

function theSunMod:HolyOutburstUse(_, _, player)
  local spawnPos = player.Position

  local creep = SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, spawnPos, Vector.Zero, player):ToEffect()
  creep.Scale = 2
  creep:Update()

  return true
end

theSunMod:AddCallback(ModCallbacks.MC_USE_ITEM, theSunMod.HolyOutburstUse, HOLY_OUTBURST_ID)

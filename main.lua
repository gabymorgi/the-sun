local log = require("log")

local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false)
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2")

local game = Game()
local rng = RNG()
local HALF_PI = math.pi / 2
local TWO_PI = math.pi * 2

---@class OrbitalTear
---@field tear EntityTear | EntityProjectile | EntityEffect
---@field direction number
---@field radius number
---@field angle number
---@field time number
---@field bounced? boolean
---@field rangeMultiplier? number

--- @type { [number]: OrbitalTear }
local orbitingTears = {}
local orbitingTearsCount = 0
--- @type { [number]: EntityProjectile }
local wallProjectiles = {}
local MIN_ORBITING_RADIUS = 40
local orbitingRadius = MIN_ORBITING_RADIUS
local MAX_ORBITING_TEARS = 60
local MAX_ORBITING_PROJ = MAX_ORBITING_TEARS * 2
local RADIUS_STEP_MULTIPLIER = 2
local PROJECTILE_SPAWN_OFFSET = 40
local GRID_SIZE = 40
local PROJECTILE_DESPAWN_OFFSET = Vector(80, 80)
local tearLifetime = 160
local activeWizardEffectFrames = 0
local framesPerSecond = 25

-- synergy variables

local leadPencilCount = 0
local friendlySpiderCount = 0

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

local roomDelay = 10
local current = 0
local wallDirection = 0

-- 00 = left
-- 10 = right
-- 01 = top
-- 11 = down

local colorOffsets = {
  Red = { colorOffset = { 0.61, -0.39, -0.39 }, rangeMultiplier = 0.63 },
  Yellow = { colorOffset = { 0.54, 0.61, -0.4 }, rangeMultiplier = 0.88 },
  Green = { colorOffset = { -0.4, 0.61, -0.26 }, rangeMultiplier = 1.13 },
  Cyan = { colorOffset = { -0.39, 0.4, 0.61 }, rangeMultiplier = 1.38 },
}

--- @param tear EntityTear
local function GetColorOffset(tear)
  for color, values in pairs(colorOffsets) do
    if (
      math.abs(tear.Color.RO - values[1]) < 0.01 and
      math.abs(tear.Color.GO - values[2]) < 0.01 and
      math.abs(tear.Color.BO - values[3]) < 0.01
    ) then
      return color
    end
  end
  return nil
end

---@param player EntityPlayer
local function calculateRoomFireDelay(player)
  local room = game:GetRoom()
  local roomShape = room:GetRoomShape()

  roomDelay = player.MaxFireDelay * (roomMultiplier[roomShape] or 1)

  log:Value("roomDelay", roomDelay .. " - " .. player.MaxFireDelay .. " - " .. roomShape .. " - " .. roomMultiplier[roomShape])
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

---@param players EntityPlayer[]
---@return boolean
local function SomePlayerWithOrbital(players)
  for _, player in pairs(players) do
    if player:GetPlayerType() == theSunType then
      return true
    end
  end
  return false
end

-- for _,player in pairs(GetPlayers()) do
--- @return EntityPlayer[]
local function GetPlayers()
  local players = {}
  for i = 0, game:GetNumPlayers() - 1 do
    local player = Game():GetPlayer(i)
    -- index = player.GetCollectibleRNG(CollectibleType.COLLECTIBLE_SAD_ONION)
    players[i] = player
  end
  return players
end

--- @param playerPos Vector
--- @param proj Entity
--- @return number
--- -1 = clockwise, 1 = counter-clockwise
local function GetClockWiseSign(playerPos, proj)
  local toProj = (proj.Position - playerPos):Normalized()
  local velocity = proj.Velocity:Normalized()

  -- negative = clockwise, positive = counter-clockwise
  local sign = velocity.X * toProj.Y - velocity.Y * toProj.X
  if sign > 0 then
    return -1     -- counter-clockwise
  else
    return 1      -- clockwise
  end
end

--- @param pos1 Vector
--- @param pos2 Vector
--- @return number
local function GetAngle(pos1, pos2)
  return math.atan(pos2.Y - pos1.Y, pos2.X - pos1.X)
end

--- @param player EntityPlayer
--- @param orb OrbitalTear
--- @param multiplier? number
local function SpinOrbitingTear(player, orb, multiplier)
  local vel = player.ShotSpeed / math.sqrt(orb.radius)
  if multiplier and multiplier ~= 1 then
    vel = vel * multiplier
  end
  orb.angle = orb.angle + orb.direction * vel
  -- angle between the player and the tear
  -- orb.angle = GetAngle(player.Position, orb.tear.Position)
  local offset = Vector(math.cos(orb.angle), math.sin(orb.angle)) * orb.radius
  orb.tear.Position = player.Position + offset
  -- tear orientation
  local tangentAngle = orb.angle + orb.direction * HALF_PI
  orb.tear.Velocity = Vector(math.cos(tangentAngle), math.sin(tangentAngle))
  -- orb.tear.Rotation = orb.angle + HALF_PI
end

--- @param player EntityPlayer
--- @param tear EntityTear | EntityProjectile
--- @return OrbitalTear
local function AddToOrbitals(player, tear)
  local tearHash = GetPtrHash(tear)
  if orbitingTears[tearHash] then
    return orbitingTears[tearHash] -- already in orbit
  end

  if tear.Type == EntityType.ENTITY_TEAR then
    tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
    tear.FallingAcceleration = -0.1
    tear.Height = -10
  else
    tear:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES | ProjectileFlags.CANT_HIT_PLAYER | ProjectileFlags.GHOST)
    tear.FallingAccel = -0.1
  end
  tear.FallingSpeed = 0
  orbitingTears[tearHash] = {
    tear = tear,
    direction = GetClockWiseSign(player.Position, tear),
    radius = (tear.Position - player.Position):Length(),
    angle = math.atan(tear.Position.Y - player.Position.Y, tear.Position.X - player.Position.X),
    time = 0,
  }

  orbitingTearsCount = orbitingTearsCount + 1

  return orbitingTears[tearHash]
end

--- @param hash number
--- @param hasPop? boolean
local function RemoveFromOrbit(hash, hasPop)
  if orbitingTears[hash] then
    orbitingTears[hash].tear.FallingSpeed = 0.5
    if orbitingTears[hash].tear.Type == EntityType.ENTITY_TEAR then
      if (hasPop) then
        orbitingTears[hash].tear.FallingAcceleration = -0.09
        orbitingTears[hash].tear.TearFlags = orbitingTears[hash].tear.TearFlags & ~TearFlags.TEAR_SPECTRAL
        orbitingTears[hash].tear.FallingSpeed = 0
        orbitingTears[hash].tear.Velocity = orbitingTears[hash].tear.Velocity:Rotated(-90)
      else
        orbitingTears[hash].tear.FallingAcceleration = 0.1
      end
    else
      orbitingTears[hash].tear.FallingAccel = 0.1
    end
    orbitingTears[hash].tear.Velocity = orbitingTears[hash].tear.Velocity * 10
    orbitingTears[hash] = nil
    orbitingTearsCount = orbitingTearsCount - 1
  end
end

---@param topLeftPos Vector
---@param bottomRightPos Vector
local function purgeWallProjectiles(topLeftPos, bottomRightPos)
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

--- @param player EntityPlayer
--- @param spawnPos Vector
--- @param velocity Vector
local function spawnBulletWall(player, spawnPos, velocity)
  local proj = Isaac.Spawn(
    EntityType.ENTITY_PROJECTILE,
    ProjectileVariant.PROJECTILE_TEAR,
    0,
    spawnPos,
    velocity,
    player
  ):ToProjectile()
  if not proj then return end
  wallProjectiles[GetPtrHash(proj)] = proj
  proj.ProjectileFlags = proj.ProjectileFlags | ProjectileFlags.GHOST | ProjectileFlags.CANT_HIT_PLAYER
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

  purgeWallProjectiles(topLeftPos, bottomRightPos)

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

  local bulletTrain = 1 + getExtraBulletTrain(player)
  local theWizOffset = player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) and 1 or 0
  if theWizOffset ~= 0 then
    bulletTrain = bulletTrain + 1
    direction = direction:Rotated(-45)
  elseif activeWizardEffectFrames > 0 then
    activeWizardEffectFrames = activeWizardEffectFrames - roomDelay
    direction = direction:Rotated(rng:RandomInt(2) * 90 - 45)
  end
  
  local velocity = direction * velMagnitude
  for _ = 1, bulletTrain do
    spawnBulletWall(player, spawnPos, velocity)
    if theWizOffset ~= 0 then
      velocity = velocity:Rotated(90 * theWizOffset)
      theWizOffset = -theWizOffset
    end
    spawnPos = spawnPos - direction * 10
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
    leadPencilCount = leadPencilCount + 1
    if leadPencilCount > 15 then
      leadPencilCount = 0
      for _ = 1, 12 do
        local randomAngle = rng:RandomFloat() * 20 - 10
        spawnBulletWall(
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
local function TryAbsorbTears(player)
  local nearby = Isaac.FindInRadius(player.Position, 60, EntityPartition.BULLET)
  for _, ent in ipairs(nearby) do
    local proj = ent:ToProjectile()
    if proj and not orbitingTears[GetPtrHash(proj)] and IsProjectileBehindPlayer(player.Position, proj) then
      if wallProjectiles[GetPtrHash(proj)] then
        if orbitingTearsCount > MAX_ORBITING_TEARS then
          proj:Remove()
          goto continue
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
          player:FireKnife(
            player,
            0,
            false,
            KnifeVariant.SPIRIT_SWORD,
            0)
          proj:Remove()
          return
        end
        local tear = player:FireTear(proj.Position, proj.Velocity, true, true, true)
        proj:Remove()
        -- LogEnum("tearVariant", tear.Variant)
        -- LogFlag("tearFlags", tear.TearFlags)
        -- tear.TearFlags = tear.TearFlags | TearFlags.TEAR_ORBIT
        if tear then
          AddToOrbitals(player, tear)

          if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_WIG) then
            if friendlySpiderCount < 5 then
              local prob = player.Luck < 10 and 1 / (20 - (2 * player.Luck)) or 1
              if rng:RandomFloat() < prob then
                Isaac.Spawn(
                  EntityType.ENTITY_FAMILIAR,
                  FamiliarVariant.BLUE_SPIDER,
                  0,
                  player.Position,
                  Vector.Zero, player)
                friendlySpiderCount = friendlySpiderCount + 1
              end
            end
          end

          if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
            if rng:RandomFloat() < 0.05 then
              tear = player:FireTear(player.Position, proj.Velocity, false, true, false, player, 2)
              tear.TearFlags = TearFlags.TEAR_SLOW
              AddToOrbitals(player, tear)
              local creep = Isaac.Spawn(
                EntityType.ENTITY_EFFECT,
                EffectVariant.PLAYER_CREEP_WHITE,
                0,
                proj.Position,
                Vector.Zero,
                player)
              -- creep:Update()
            end
          end

          if player:HasCollectible(CollectibleType.COLLECTIBLE_AKELDAMA) then
            tear = player:FireTear(player.Position, proj.Velocity, false, true, false)
            tear.TearFlags = TearFlags.TEAR_CHAIN | TearFlags.TEAR_SPECTRAL
            tear.CollisionDamage = 3.5
            tear.Size = 7
            tear.Scale = 1
            tear:ChangeVariant(TearVariant.BLOOD)
          end

          if player:HasCollectible(CollectibleType.COLLECTIBLE_IMMACULATE_HEART) then
            if rng:RandomFloat() < 0.2 then
              local tear = player:FireTear(player.Position, proj.Velocity, false)
              tear.TearFlags = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_ORBIT
              tear.FallingAcceleration = -0.1
            end
          end
        end
      else
        if proj.ProjectileFlags & ProjectileFlags.HIT_ENEMIES ~= 0 or orbitingTearsCount > MAX_ORBITING_PROJ then
          goto continue
        end
        AddToOrbitals(player, proj)
      end

      
    end
    ::continue::
  end
end

--- Detecta colisiones entre tears orbitando basado en su ángulo y radio
--- @param orbitingTearsTable { [number]: OrbitalTear }
--- @param orbitRadius number
local function CheckOrbitingTearCollisions(orbitingTearsTable, orbitRadius)
  local tearSize = 24
  local minAngle = tearSize / orbitRadius   -- arco = longitud / radio
  -- Convertimos la tabla en un array ordenable
  local sorted = {}
  for _, orbital in pairs(orbitingTearsTable) do
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
      RemoveFromOrbit(GetPtrHash(t1.tear), true)
    end
  end
end

---@param player EntityPlayer
local function UpdateOrbitingTears(player)
  local hasPop = player:HasCollectible(CollectibleType.COLLECTIBLE_POP)
  local multiplier = 1
  if hasPop then
    multiplier = 0.5
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_PROPTOSIS) then
    multiplier = multiplier * 2
  end
  for hash, orb in pairs(orbitingTears) do
    orb.time = orb.time + 1
    if not (orb.tear and orb.tear:Exists() and not orb.tear:IsDead()) or orb.time > tearLifetime then
      RemoveFromOrbit(hash, hasPop)
    else
      local targetRadius = orb.rangeMultiplier and orb.rangeMultiplier * orbitingRadius or orbitingRadius
      if orb.radius < targetRadius then
        orb.radius = orb.radius + player.ShotSpeed * RADIUS_STEP_MULTIPLIER
      end
      if orb.radius > targetRadius then
        orb.radius = targetRadius
      end
      SpinOrbitingTear(player, orb, multiplier)
    end
  end

  if (hasPop and current % 3 == 0) then -- artificial delay for the pop effect
    CheckOrbitingTearCollisions(orbitingTears, orbitingRadius)
  end
end

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
  if not IsTheSun(player) then
    return     -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
  end

  player:AddNullCostume(hairCostume)
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.GiveCostumesOnInit)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheRange(player)
  if not IsTheSun(player) then
    return
  end

  tearLifetime = player.TearRange
  player.TearRange = player.TearRange / 3
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheRange, CacheFlag.CACHE_RANGE)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFlight(player)
  if not IsTheSun(player) then
    return
  end

  player.CanFly = true
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFlight, CacheFlag.CACHE_FLYING)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFireDelay(player)
  if not IsTheSun(player) then
    return
  end

  log:Value("onEvaluateCacheFireDelay", player.MaxFireDelay)

  calculateRoomFireDelay(player)
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFireDelay, CacheFlag.CACHE_FIREDELAY)

function theSunMod:OnEntityDeath(entity)
  if entity.Type == EntityType.ENTITY_FAMILIAR and entity.Variant == FamiliarVariant.BLUE_SPIDER then
    friendlySpiderCount = math.max(0, friendlySpiderCount - 1)
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, theSunMod.OnEntityDeath)

local function HandleRoomEnter()
  local player = Isaac.GetPlayer(0)
  if not IsTheSun(player) then
    return
  end

  wallProjectiles = {}
  orbitingTears = {}
  orbitingTearsCount = 0

  calculateRoomFireDelay(player)

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE)) then
    local tear = player:FireTear(
      player.Position,
      player.Velocity,
      true,
      true,
      true
    )
    tear.TearFlags = TearFlags.TEAR_LUDOVICO
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
  local tearHash = GetPtrHash(tear)
  if not orbitingTears[tearHash] then
    return
  end
  if collider:IsActiveEnemy() and collider:IsVulnerableEnemy() then
    local isPiercing = tear:HasTearFlags(TearFlags.TEAR_PIERCING)
    -- sticky: explosivo - sinus infection - mucormycosis
    local isSticky = tear:HasTearFlags(TearFlags.TEAR_STICKY | TearFlags.TEAR_BOOGER | TearFlags.TEAR_SPORE)
    if not isPiercing or isSticky then
      if tear:HasTearFlags(TearFlags.TEAR_BOUNCE) and not orbitingTears[tearHash].bounced then
        orbitingTears[tearHash].bounced = true
        orbitingTears[tearHash].direction = -orbitingTears[tearHash].direction
        -- TODO: select the correct player
        -- local player = Isaac.GetPlayer(0)
        -- SpinOrbitingTear(player, orbitingTears[tearHash])
        -- tear:Update()
      else
        RemoveFromOrbit(tearHash)
      end
    end
  end
end

theSunMod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, theSunMod.OnTearCollision)

function theSunMod:OnUpdate()
  local players = GetPlayers()

  if SomePlayerWithOrbital(players) then
    local room = game:GetRoom()
    -- if not room:IsClear() then -- TOMOD
    if true then
      current = current + 1
      if current > roomDelay then
        FireFromWall(players[0])
        current = 0
      end
    end
  end
  for _, player in pairs(players) do
    if not IsTheSun(player) then
      goto continue       -- Skip to the next iteration of the loop if the player is not The Sun.
    end

    TryAbsorbTears(player)
    if player:GetShootingInput():Length() > 0 then
      if (orbitingRadius < player.TearRange) then
        orbitingRadius = orbitingRadius + RADIUS_STEP_MULTIPLIER
      end
    else
      if (orbitingRadius > MIN_ORBITING_RADIUS) then
        orbitingRadius = orbitingRadius - RADIUS_STEP_MULTIPLIER
      end
    end

    UpdateOrbitingTears(player)
    ::continue::
  end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, theSunMod.OnUpdate)

--- @param pillEffect PillEffect
--- @param player EntityPlayer
function theSunMod:OnUsePill(pillEffect, player, _)
  if pillEffect == PillEffect.PILLEFFECT_WIZARD then
    -- local index = player.ControllerIndex
    activeWizardEffectFrames = 30 * framesPerSecond -- 30 segundos
  end
end

theSunMod:AddCallback(ModCallbacks.MC_USE_PILL, theSunMod.OnUsePill)

--- @type { [number]: EntityTear }
local tearsToCheck = {}
--- @type { [number]: EntityTear }
local effectToCheck = {}

--- Accessing the initialized entity does provide incomplete data in some use cases
--- @param tear EntityTear
function theSunMod:HandleTearInit(tear)
  local player = tear.SpawnerEntity:ToPlayer()
  if not player then
    return
  end
  if not IsTheSun(player) then
    return
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_ANGELIC_PRISM) then
    tearsToCheck[GetPtrHash(tear)] = tear
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_INIT, theSunMod.HandleTearInit, TearVariant.BLUE)

--- @param effect EntityEffect
function theSunMod:HandleEffectInit(effect)
  log:Value("HandleEffectInit", {
    variant = log:Enum("effect", effect.Variant),
    damage = effect.DamageSource,
  })
end
theSunMod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, theSunMod.HandleEffectInit)

--------------------------------------------------------------------------------------------------

function theSunMod:HandleTearUpdate(tear)
  if tearsToCheck[GetPtrHash(tear)] then
    tearsToCheck[GetPtrHash(tear)] = nil

    local color = GetColorOffset(tear)

    if color then
      local newOrb = AddToOrbitals(tear.SpawnerEntity:ToPlayer(), tear)
      newOrb.rangeMultiplier = colorOffsets[color].rangeMultiplier
    end
  end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, theSunMod.HandleTearUpdate, TearVariant.BLUE)

function theSunMod:HandleProjInit(proj)
  log:Value("HandleProjInit", {
    flags = proj.ProjectileFlags, -- log:Flag("proj", proj.ProjectileFlags),
    variant = proj.Variant,       -- log:Enum("proj", proj.Variant),
    color = proj.Color,
    spawnerType = proj.SpawnerType,
    spawnerVariant = proj.SpawnerVariant,
  })
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
  log:Value("HandleKnifeInit", {
    flags = log:Flag("proj", knife.TearFlags),
    variant = knife.Variant, -- log:Enum("proj", proj.Variant),
    rotation = knife.Rotation,
    rotationOffset = knife.RotationOffset,
  })
end

theSunMod:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, theSunMod.HandleKnifeInit)



--- @param tear EntityTear
function theSunMod:HandleFireTear(tear, player)
  log:Value("HandleTearFired", {
    flags = log:Flag("tear", tear.TearFlags),
    variant = log:Enum("tear", tear.Variant),
    fallingSpeed = tear.FallingSpeed,
    fallingAccel = tear.FallingAcceleration,
  })
  -- Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.EVIL_EYE, 0, tear.Position, Vector(5, 0), player)
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

  local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, 0, spawnPos, Vector.Zero,
    player):ToEffect()
  creep.Scale = 2
  creep:Update()

  return true
end

theSunMod:AddCallback(ModCallbacks.MC_USE_ITEM, theSunMod.HolyOutburstUse, HOLY_OUTBURST_ID)

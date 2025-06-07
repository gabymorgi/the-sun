local log = include("log")
---@type PlayerUtils
local PlayerUtils = include("thesun-src.PlayerUtils")
---@type Const
local Const = require("thesun-src.Const")
---@type Utils
local Utils = include("thesun-src.Utils")
---@type Store
local Store = require("thesun-src.Store")
---@type WormEffects
WormEffects = include("thesun-src.WormEffects")

---@class OrbitingTears
---@field ReleaseHomingTears fun(player: EntityPlayer)
---@field ExpandHomingTears fun(player: EntityPlayer, releaseOrbit: boolean?)
---@field ExpandOrbitingTears fun(player: EntityPlayer, entityOrbit: Orbit<EntityOrbital>)
---@field ExplodeOrbitingTears fun(player: EntityPlayer, entityOrbit: Orbit<EntityOrbital>)
---@field SpinOrbitingTears fun(player: EntityPlayer, entityOrbit: Orbit<EntityOrbital>)
---@field PurgeOrbitingEntities fun(entityOrbit: Orbit<EntityOrbital>, gameFrameCount: number)
---@field IsProjectileBehindPlayer fun(playerPos: Vector, proj: EntityProjectile): boolean
---@field CalculatePostTearSynergies fun(player: EntityPlayer, orb: Orbital<EntityTear>)
---@field TryAbsorbTears fun(player: EntityPlayer)
---@field CheckOrbitingTearCollisions fun(tearOrbit: Orbit<EntityTear>, orbitRadius: number)
---@field UpdateOrbitingRadius fun(player: EntityPlayer)
---@field UpdateOrbitingTears fun(player: EntityPlayer)
---@field UpdateOrbitingEntities fun(player: EntityPlayer)

local OrbitingTears = {}

---@param ludodivo Ludovico
---@param mult number
function AddLudoMult(ludodivo, mult)
  local step = mult * 0.1
  ludodivo.Multiplier = ludodivo.Multiplier + step
  ludodivo.Tear.Scale = ludodivo.Tear.Scale + step
  ludodivo.Tear.CollisionDamage = ludodivo.BaseDamage * ludodivo.Multiplier
end

--- @param player EntityPlayer
function OrbitingTears.ReleaseHomingTears(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local enemies = Utils.GetEnemiesInRange(player.Position, playerData.orbitRange.max + Const.GRID_SIZE)
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
function OrbitingTears.ExpandHomingTears(player, releaseOrbit)
  ---@type PlayerData
  local playerData = PlayerUtils.GetPlayerData(player)
  local enemies
  local step = player.ShotSpeed * Const.RADIUS_STEP_MULTIPLIER * 2
  local epsilon = 0.5
  for hash, orb in pairs(playerData.tearOrbit.list) do
    local closestEnemy = nil
    local closestEnemyDist = math.huge
    if not orb.target or not orb.target:Exists() then
      if not enemies then
        enemies = Utils.GetEnemiesInRange(player.Position, playerData.orbitRange.max)
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
        log.Value("radius", {
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
function OrbitingTears.ExpandOrbitingTears(player, entityOrbit)
  local playerData = PlayerUtils.GetPlayerData(player)
  local step = player.ShotSpeed * Const.RADIUS_STEP_MULTIPLIER
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
function OrbitingTears.ExplodeOrbitingTears(player, entityOrbit)
  for _, orb in pairs(entityOrbit.list) do
    local explosion = Utils.SpawnEntity(
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
--- @param entityOrbit Orbit<Entity>
--- @param checkWorm boolean?
function OrbitingTears.SpinOrbitingTears(player, entityOrbit, checkWorm)
  local playerData = PlayerUtils.GetPlayerData(player)
  for _, orb in pairs(entityOrbit.list) do
    local vel = player.ShotSpeed * Utils.FastInvSqrt(orb.radius)
    orb.angle = orb.angle + orb.direction * vel
    local angle, radius = checkWorm and WormEffects.GetModifiedOrbit(orb) or orb.angle, orb.radius
    local offset
    if playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_TRACTOR_BEAM] then
      offset = Utils.GetFlattenedOrbitPosition(player, angle, radius)
    else
      offset = Vector(math.cos(angle), math.sin(angle)) * radius
    end
    local targetPos = player.Position + offset
    orb.entity.Velocity = (targetPos - orb.entity.Position) * 0.5
  end
end

--- @param player EntityPlayer
function OrbitingTears.UpdateAntiGravityTears(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  for _, tear in pairs(playerData.antigravityTears) do
    if tear:Exists() then
      if tear.FrameCount > 60 then
        local orb = playerData.tearOrbit:add(player, tear, Const.game:GetFrameCount() - 60)
        OrbitingTears.CalculatePostTearSynergies(player, orb)
        playerData.antigravityTears[GetPtrHash(tear)] = nil
      else
        tear.Velocity = Vector.Zero
      end
    else
      tear:Remove()
    end
  end
end

---@param entityOrbit Orbit<EntityOrbital>
---@param gameFrameCount number
function OrbitingTears.PurgeOrbitingEntities(entityOrbit, gameFrameCount)
  for hash, orb in pairs(entityOrbit.list) do
    if not (orb.entity and orb.entity:Exists()) or orb.expirationFrame < gameFrameCount then
      entityOrbit:remove(hash)
    end
  end
end

--- @param playerPos Vector
--- @param proj EntityProjectile
function OrbitingTears.IsProjectileBehindPlayer(playerPos, proj)
  local toProj = (proj.Position - playerPos):Normalized()
  local velocity = proj.Velocity:Normalized()

  -- 0 = side, 1 = back, -1 = front
  return velocity:Dot(toProj) > 0.1
end

--- @param player EntityPlayer
--- @param orb Orbital<EntityTear>
function OrbitingTears.CalculatePostTearSynergies(player, orb)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION) then
    orb.entity:ChangeVariant(TearVariant.FETUS)
    orb.entity:AddTearFlags(TearFlags.TEAR_FETUS)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) or player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_BOMBER)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_BRIMSTONE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_SWORD)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_BONE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_KNIFE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_TECHX)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) then
      orb.entity:AddTearFlags(TearFlags.TEAR_FETUS_TECH)
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_WIG) then
    local playerData = PlayerUtils.GetPlayerData(player)
    if playerData.friendlySpiderCount < 5 then
      local prob = player.Luck < 10 and 1 / (20 - (2 * player.Luck)) or 1
      if Const.rng:RandomFloat() < prob then
        Utils.SpawnEntity(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, player.Position, Vector.Zero, player)
        playerData.friendlySpiderCount = playerData.friendlySpiderCount + 1
      end
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
    if Const.rng:RandomFloat() < 0.05 then
      local zitTear = player:FireTear(player.Position, orb.entity.Velocity, false, true, false, player, 2)
      zitTear.TearFlags = TearFlags.TEAR_SLOW
      PlayerUtils.GetPlayerData(player).tearOrbit:add(player, zitTear)
      Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, orb.entity.Position, Vector.Zero, player)
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
    if Const.rng:RandomFloat() < 0.2 then
      local immaculateTear = player:FireTear(player.Position, orb.entity.Velocity, false)
      local immaculateOrb = PlayerUtils.GetPlayerData(player).tearOrbit:add(player, immaculateTear)
      immaculateOrb.direction = immaculateOrb.direction * -1
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_GHOST_PEPPER)) then
    local prob = math.min(1/(12 - player.Luck), 0.5)
    if Const.rng:RandomFloat() < prob then
      local fire = Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, orb.entity.Position, Vector(10, 0), player):ToEffect()
      if fire then
        PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fire)
      end
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE)) then
    local prob = math.min(1/(12 - player.Luck), 0.5)
    if Const.rng:RandomFloat() < prob then
      local fire = Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, orb.entity.Position, Vector.Zero, player):ToEffect()
      if fire then
        PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fire)
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

  if player:HasTrinket(TrinketType.TRINKET_TORN_CARD) then
    local playerData = PlayerUtils.GetPlayerData(player)
    playerData.tornCardCount = playerData.tornCardCount + 1
    if playerData.tornCardCount > 15 then
      playerData.tornCardCount = 0
      local tear = player:FireTear(player.Position, orb.entity.Velocity, false, true, false)
      tear:AddTearFlags(TearFlags.TEAR_EXPLOSIVE | TearFlags.TEAR_BOOMERANG)
      tear.Size = 8
      tear.Color = Color(0.5, 0.9, 0.4, 1)
      tear.CollisionDamage = 40
      playerData.tearOrbit:add(player, tear)
    end
  end
end

--- @param player EntityPlayer
function OrbitingTears.TryAbsorbTears(player)
  local nearby = Isaac.FindInRadius(player.Position, 60, EntityPartition.BULLET)
  for _, ent in ipairs(nearby) do
    local proj = ent:ToProjectile()
    if proj and (not proj:GetData().theSunIsAbsorbed) and OrbitingTears.IsProjectileBehindPlayer(player.Position, proj) then
      local playerData = PlayerUtils.GetPlayerData(player)
      local projHash = GetPtrHash(proj)
      if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or Store.WallProjectiles[projHash] then
        if not playerData.tearOrbit:hasSpace() then
          proj:Remove()
          goto continue
        end
        local tear
        local multiplier = 1
        local hasCSection = player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION)
        if hasCSection then
          multiplier = 0.75
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
          multiplier = multiplier * (4 / (playerData.tearOrbit.length + 1))
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) and playerData.ludodivo then
          AddLudoMult(playerData.ludodivo, 1)
          table.insert(playerData.ludodivo.ExpFrames, Const.game:GetFrameCount() + player.TearRange)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) then
          tear = player:FireBomb(proj.Position, proj.Velocity, player)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) and (not hasCSection) then
          local nearestEnemy = Utils.GetClosestEnemies(player.Position)
          if nearestEnemy then
            local direction = (nearestEnemy.Position - player.Position):Normalized()
            local laser = player:FireTechLaser(proj.Position, LaserOffset.LASER_TECH1_OFFSET, direction, false, true,
            player, multiplier)
            laser:SetMaxDistance(playerData.orbitRange.max)
          end
        elseif (
          player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X) or
          player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) or
          player:GetEffects():HasTrinketEffect(TrinketType.TRINKET_AZAZELS_STUMP)
        ) then
          tear = player:FireTechXLaser(proj.Position, Vector.Zero, 5, player, multiplier)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
          local a = Isaac.Spawn(EntityType.ENTITY_KNIFE, 0, 0, player.Position, Vector.Zero, player):ToKnife()
          a.Visible = true
          a.Parent = player

          -- local a = player:FireKnife(player)
          -- a:Shoot(1, 10)
        else
          tear = player:FireTear(proj.Position, proj.Velocity, true, true, true, player, multiplier)
          if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
            tear:ChangeVariant(TearVariant.SWORD_BEAM)
          end
          if player:HasCollectible(CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then
            playerData.antigravityTears[GetPtrHash(tear)] = tear
            tear.FallingAcceleration = -0.1
            tear = nil
          end
        end
        proj:Remove()
        proj:GetData().theSunIsAbsorbed = true
        if player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY_2) then
          local extra = math.max(1, math.ceil(player.MaxFireDelay))
          if (playerData.technologyTwoLaser and playerData.technologyTwoLaser:Exists()) then
            --- setTimeout actually accepts a number
            ---@diagnostic disable-next-line: param-type-mismatch
            playerData.technologyTwoLaser:SetTimeout(playerData.technologyTwoLaser.Timeout + extra)
          else
            local laser = player:FireTechXLaser(proj.Position, Vector.Zero, 100, player, 0.1)
            --- setTimeout actually accepts a number
            ---@diagnostic disable-next-line: param-type-mismatch
            laser:SetTimeout(extra)
            playerData.technologyTwoLaser = laser
          end
        end
        if tear then
          local orb = PlayerUtils.GetPlayerData(player).tearOrbit:add(player, tear --[[@as EntityTear]])
          OrbitingTears.CalculatePostTearSynergies(player, orb)
        end
      elseif not playerData.projOrbit.list[projHash] then
        proj:GetData().theSunIsAbsorbed = true
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
function OrbitingTears.CheckOrbitingTearCollisions(tearOrbit, orbitRadius)
  local tearSize = 24
  local minAngle = tearSize / orbitRadius   -- arco = longitud / radio
  -- Convertimos la tabla en un array ordenable
  local sorted = {}
  for _, orbital in pairs(tearOrbit.list) do
    local pre = orbital.angle
    orbital.angle = orbital.angle % Const.TWO_PI
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
function OrbitingTears.UpdateOrbitingRadius(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then
    local target = Utils.GetMarkedTarget(player)
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
        playerData.orbitRange.act = playerData.orbitRange.act + Const.RADIUS_STEP_MULTIPLIER
      end
    else
      if (playerData.orbitRange.act > playerData.orbitRange.min) then
        playerData.orbitRange.act = playerData.orbitRange.act - Const.RADIUS_STEP_MULTIPLIER
      end
    end
  end
end

---@param player EntityPlayer
function OrbitingTears.UpdateOrbitingTears(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local gameFrameCount = Const.game:GetFrameCount()
  if player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) and playerData.ludodivo then
    local input = player:GetAimDirection()
    if playerData.ludodivo.Tear then
      playerData.ludodivo.Tear.Velocity = input * player.ShotSpeed * 10
    end
    if (playerData.ludodivo.ExpFrames[playerData.ludodivo.Index] and playerData.ludodivo.ExpFrames[playerData.ludodivo.Index] < gameFrameCount) then
      playerData.ludodivo.Index = playerData.ludodivo.Index + 1
      AddLudoMult(playerData.ludodivo, -1)
    end
    return
  end
  if playerData.technologyTwoLaser then
    if playerData.technologyTwoLaser:Exists() then
      playerData.technologyTwoLaser.Position = player.Position
    end
  end
  if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
    if player:GetShootingInput():Length() > 0 then
      OrbitingTears.ExplodeOrbitingTears(player, playerData.tearOrbit)
    end
  end
  
  OrbitingTears.PurgeOrbitingEntities(playerData.tearOrbit, gameFrameCount)
  OrbitingTears.UpdateAntiGravityTears(player)
  if playerData.activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE] then
    local bar = playerData.activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE]
    bar:set(playerData.tearOrbit.length + playerData.projOrbit.length)
  end
  if (
    player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT) or
    player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION)
  ) then
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
      player:HasCollectible(CollectibleType.COLLECTIBLE_SACRED_HEART) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) or
      player:HasCollectible(CollectibleType.COLLECTIBLE_GODHEAD)
    ) then
      OrbitingTears.ExpandHomingTears(player)
    else
      if player:HasTrinket(TrinketType.TRINKET_BRAIN_WORM) and gameFrameCount % 8 == 0 then
        OrbitingTears.ReleaseHomingTears(player)
      end
      OrbitingTears.ExpandOrbitingTears(player, playerData.tearOrbit)
    end
    OrbitingTears.SpinOrbitingTears(player, playerData.tearOrbit, true)
    local hasPop = player:HasCollectible(CollectibleType.COLLECTIBLE_POP)
    if (hasPop and gameFrameCount % 4 == 0) then -- artificial delay for the pop effect
      OrbitingTears.CheckOrbitingTearCollisions(playerData.tearOrbit, playerData.orbitRange.act)
    end
  end
end

---@param player EntityPlayer
function OrbitingTears.UpdateOrbitingEntities(player)
  local gameFrameCount = Const.game:GetFrameCount()
  local playerData = PlayerUtils.GetPlayerData(player)
  OrbitingTears.PurgeOrbitingEntities(playerData.projOrbit, gameFrameCount)
  OrbitingTears.ExpandOrbitingTears(player, playerData.projOrbit)
  OrbitingTears.SpinOrbitingTears(player, playerData.projOrbit)
  OrbitingTears.PurgeOrbitingEntities(playerData.effectOrbit, gameFrameCount)
  OrbitingTears.ExpandOrbitingTears(player, playerData.effectOrbit)
  OrbitingTears.SpinOrbitingTears(player, playerData.effectOrbit)
end

return OrbitingTears

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
local WormEffects = include("thesun-src.WormEffects")

---@class OrbitingTears
---@field DropRelease fun(player: EntityPlayer)
---@field VengefulRelease fun(player: EntityPlayer)
---@field ReleaseHomingTears fun(player: EntityPlayer)
---@field ExplodeOrbitingTears fun(player: EntityPlayer, entityOrbit: Orbit<EntityOrbital>)
---@field SpinOrbitingTears fun(player: EntityPlayer, entityOrbit: Orbit<EntityOrbital>)
---@field PurgeOrbitingEntities fun(entityOrbit: Orbit<EntityOrbital>, gameFrameCount: number)
---@field IsProjectileBehindPlayer fun(playerPos: Vector, proj: EntityProjectile): boolean
---@field CalculatePostTearSynergies fun(player: EntityPlayer, tear: EntityTear, orb?: Orbital<EntityTear>)
---@field TryAbsorbTears fun(player: EntityPlayer)
---@field TryAbsorbEntities fun(player: EntityPlayer)
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
function OrbitingTears.DropRelease(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  for hash, orb in pairs(playerData.tearOrbit.list) do
    playerData.tearOrbit:remove(hash)
  end
  for hash, orb in pairs(playerData.projOrbit.list) do
    playerData.projOrbit:remove(hash)
  end
  for hash, orb in pairs(playerData.effectOrbit.list) do
    if orb.entity.Variant == EffectVariant.BRIMSTONE_BALL then
      player:FireTechLaser(orb.entity.Position, LaserOffset.LASER_TECH1_OFFSET, orb.entity.Velocity:Normalized(), false,
        true, player, 1)
      orb.entity:Remove()
    elseif (orb.entity.Type == EntityType.ENTITY_TEAR) then --knives
      Store.releasedTears[GetPtrHash(orb.entity)] = {
        tear = orb.entity --[[@as EntityTear]],
        velocity = orb.entity.Velocity,
        expirationFrame = 120
      }
    end
    playerData.effectOrbit:remove(hash)
  end
end

--- @param player EntityPlayer
function OrbitingTears.VengefulRelease(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  if playerData.tearOrbit.length + playerData.projOrbit.length + playerData.effectOrbit.length < 1 then
    return
  end
  local hasTheWiz = player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) or playerData.wizardRemainingFrames > 0
  local shootVector = Utils.GetShootVector(player)
  if hasTheWiz then
    shootVector = shootVector:Rotated(Const.rng:RandomInt(2) * 90 - 45)
  end
  ---@type Entity?
  local nearestEnemy
  nearestEnemy = Utils.GetClosestEnemiesInCone(
    player.Position,
    shootVector,
    player.TearRange,
    -45,
    45
  )
  local targetPos = nearestEnemy and nearestEnemy.Position or player.Position + shootVector * player.TearRange
  local hasTractorBeam = player:HasCollectible(CollectibleType.COLLECTIBLE_TRACTOR_BEAM)
  for hash, orb in pairs(playerData.tearOrbit.list) do
    playerData.tearOrbit:remove(hash)
    orb.entity:AddTearFlags(TearFlags.TEAR_HOMING)
    orb.entity.Velocity = (targetPos - orb.entity.Position):Normalized() * player.ShotSpeed * 15
    orb.entity.FallingAcceleration = -0.085
    if hasTractorBeam then
      local lineDir = (targetPos - player.Position):Normalized()
      local toTear = orb.entity.Position - player.Position
      local projectionLength = toTear:Dot(lineDir)
      orb.entity.Position = player.Position + lineDir * projectionLength
    end
  end
  for hash, orb in pairs(playerData.projOrbit.list) do
    playerData.projOrbit:remove(hash)
    orb.entity.Velocity = (targetPos - orb.entity.Position):Normalized() * player.ShotSpeed * 15
  end
  for hash, orb in pairs(playerData.effectOrbit.list) do
    playerData.effectOrbit:remove(hash)
    local direction = (targetPos - orb.entity.Position):Normalized()
    if orb.entity.Variant == EffectVariant.BRIMSTONE_BALL then
      local laser = player:FireTechLaser(orb.entity.Position, LaserOffset.LASER_TECH1_OFFSET, direction, false, true, player, 1)
      -- laser.Variant = LaserVariant.THICK_RED
      orb.entity:Remove()
    elseif (orb.entity.Type == EntityType.ENTITY_TEAR) then --knives
      Store.releasedTears[GetPtrHash(orb.entity)] = {
        tear = orb.entity --[[@as EntityTear]],
        velocity = direction * player.ShotSpeed * 15,
        expirationFrame = math.maxinteger
      }
    else
      orb.entity.Velocity = direction * player.ShotSpeed * 15
    end
  end
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
--- @param entityOrbit Orbit<Entity>
function OrbitingTears.SpinOrbitingTears(player, entityOrbit)
  local playerData = PlayerUtils.GetPlayerData(player)
  local step = player.ShotSpeed * Const.RADIUS_STEP_MULTIPLIER
  local epsilon = 0.5
  local orbitRange = playerData.orbitRange
  local enemies
  local reductionStepScale = 2.5 / player.TearRange
  local reductionStepDamage = 20 / player.TearRange

  for hash, orb in pairs(entityOrbit.list) do
    local entity = orb.entity
    local tear = entity:ToTear()
    local hasHoming = false

    if tear then
      hasHoming = tear:HasTearFlags(TearFlags.TEAR_HOMING)
      if (orb.flags & Const.CustomFlags.TEAR_SHRINK ~= 0) then
        log.Value("Shrinking tear", {
          scale = tear.Scale,
          damage = tear.CollisionDamage,
          range = player.TearRange
        })
        tear.Scale = tear.Scale - reductionStepScale
        tear.CollisionDamage = tear.CollisionDamage - reductionStepDamage
        if tear.CollisionDamage < 0.1 then
          playerData.tearOrbit:remove(hash)
        end
      end
    end

    -- Lógica HOMING
    if hasHoming then
      local closestEnemy = orb.target
      local closestDist = math.huge

      if not (closestEnemy and closestEnemy:Exists()) then
        if not enemies then
          enemies = Utils.GetEnemiesInRange(player.Position, orbitRange.max)
        end
        for _, enemy in pairs(enemies) do
          local dist = enemy.Position:DistanceSquared(entity.Position)
          if dist < closestDist then
            closestEnemy = enemy
            closestDist = dist
          end
        end
        orb.target = closestEnemy
      end

      if closestEnemy then
        -- Ajustar dirección y radio hacia el enemigo
        local distToEnemy = closestEnemy.Position:Distance(player.Position)
        local clockWiseSign = Utils.GetClockwiseSign2(player.Position, entity.Position, closestEnemy.Position)
        local homingFactor = Utils.Clamp(1 / (distToEnemy / 40 + 1), 0.05, 1.0)
        orb.direction = Utils.Clamp(orb.direction + clockWiseSign * 0.1 * homingFactor, -1.5, 1.5)
        local targetRadius = math.min(distToEnemy, orbitRange.max)

        -- Interpolación de radio
        local diff = targetRadius - orb.radius
        local radiusAdjustSpeed = step * 2 -- * homingFactor
        if math.abs(diff) < epsilon then
          orb.radius = targetRadius
        elseif diff > 0 then
          orb.radius = math.min(orb.radius + radiusAdjustSpeed, targetRadius)
        else
          orb.radius = math.max(orb.radius - radiusAdjustSpeed, targetRadius)
        end
      end
    else
      -- Lógica NORMAL (mantiene la órbita activa)
      local diff = orbitRange.act - orb.radius
      if math.abs(diff) < epsilon then
        orb.radius = orbitRange.act
      elseif diff > 0 then
        orb.radius = math.min(orb.radius + step, orbitRange.act)
      else
        orb.radius = math.max(orb.radius - step, orbitRange.act)
      end
    end


    local vel = player.ShotSpeed * Utils.FastInvSqrt(orb.radius)
    orb.angle = orb.angle + orb.direction * vel
    local angle, radius = orb.angle, orb.radius
    if tear then
      angle, radius = WormEffects.GetModifiedOrbit(orb)
    end
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
--- @param entityOrbit Orbit<EntityOrbital>
function OrbitingTears.ExplodeOrbitingTears(player, entityOrbit)
  for _, orb in pairs(entityOrbit.list) do
    local explosion = Utils.SpawnEntity(
      EntityType.ENTITY_BOMB,
      BombVariant.BOMB_NORMAL,
      orb.entity.Position,
      Vector(0, 0),
      player
    ):ToBomb()
    if explosion then
      explosion:SetExplosionCountdown(0)
    end
    orb.entity:Remove()
  end
end

--- @param player EntityPlayer
function OrbitingTears.UpdateAntiGravityTears(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  for _, tear in pairs(playerData.antigravityTears) do
    if tear:Exists() then
      if tear.FrameCount > 60 then
        local orb = playerData.tearOrbit:add(player, tear, Const.game:GetFrameCount() - 60)
        OrbitingTears.CalculatePostTearSynergies(player, tear, orb)
        playerData.antigravityTears[GetPtrHash(tear)] = nil
      else
        tear.Velocity = Vector(0, 0)
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
  return velocity:Dot(toProj) > 0
end

--- @param player EntityPlayer
--- @param tear EntityTear
--- @param orb? Orbital<EntityTear>
function OrbitingTears.CalculatePostTearSynergies(player, tear, orb)
  if player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION) then
    tear:ChangeVariant(TearVariant.FETUS)
    tear:AddTearFlags(TearFlags.TEAR_FETUS)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) or player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_BOMBER)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_BRIMSTONE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_SWORD)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_BONE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_KNIFE)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_TECHX)
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) then
      tear:AddTearFlags(TearFlags.TEAR_FETUS_TECH)
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_WIG) then
    local playerData = PlayerUtils.GetPlayerData(player)
    if playerData.friendlySpiderCount < 5 then
      local prob = player.Luck < 10 and 1 / (20 - (2 * player.Luck)) or 1
      if Const.rng:RandomFloat() < prob then
        Utils.SpawnEntity(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, player.Position, Vector(0, 0), player)
        playerData.friendlySpiderCount = playerData.friendlySpiderCount + 1
      end
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
    if Const.rng:RandomFloat() < 0.05 then
      local zitTear = player:FireTear(player.Position, tear.Velocity, false, true, false, player, 2)
      zitTear.TearFlags = TearFlags.TEAR_SLOW
      PlayerUtils.GetPlayerData(player).tearOrbit:add(player, zitTear)
      Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, tear.Position, Vector(0, 0), player)
    end
  end

  if player:HasCollectible(CollectibleType.COLLECTIBLE_IMMACULATE_HEART) then
    if Const.rng:RandomFloat() < 0.2 then
      local immaculateTear = player:FireTear(player.Position, tear.Velocity, false)
      local immaculateOrb = PlayerUtils.GetPlayerData(player).tearOrbit:add(player, immaculateTear)
      immaculateOrb.direction = immaculateOrb.direction * -1
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_GHOST_PEPPER)) then
    local prob = player.Luck < 10 and 1/(12 - player.Luck) or 0.5
    if Const.rng:RandomFloat() < prob then
      local fire = Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, tear.Position, Vector(10, 0), player):ToEffect()
      fire.CollisionDamage = player.Damage * 4
      if fire then
        PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fire)
      end
    end
  end

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE)) then
    local prob = player.Luck < 10 and 1/(12 - player.Luck) or 0.5
    if Const.rng:RandomFloat() < prob then
      local fire = Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, tear.Position, tear.Velocity, player):ToEffect()
      fire.CollisionDamage = player.Damage * 4
      if fire then
        PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fire)
      end
    end
  end

  if player:HasTrinket(TrinketType.TRINKET_TORN_CARD) then
    local playerData = PlayerUtils.GetPlayerData(player)
    playerData.tornCardCount = playerData.tornCardCount + 1
    if playerData.tornCardCount > 15 then
      playerData.tornCardCount = 0
      local tear = player:FireTear(player.Position, tear.Velocity, false, true, false)
      tear:AddTearFlags(TearFlags.TEAR_EXPLOSIVE | TearFlags.TEAR_BOOMERANG)
      tear.Size = 8
      tear.Color = Color(0.5, 0.9, 0.4, 1)
      tear.CollisionDamage = 40
      playerData.tearOrbit:add(player, tear)
    end
  end

  if orb then
    if (player:HasCollectible(CollectibleType.COLLECTIBLE_CHEMICAL_PEEL)) then
      if orb.direction == 1 then
        tear.CollisionDamage = tear.CollisionDamage + 2
      end
    end

    if (player:HasCollectible(CollectibleType.COLLECTIBLE_BLOOD_CLOT)) then
      if orb.direction == 1 then
        tear.CollisionDamage = tear.CollisionDamage + 1
        orb.expirationFrame = orb.expirationFrame + 40 -- more range
      end
    end

    if (player:HasCollectible(CollectibleType.COLLECTIBLE_POP)) then
      orb.direction = orb.direction * 0.5
    end
  end
end

--- @param player EntityPlayer
function OrbitingTears.TryAbsorbTears(player)
  local nearby = Isaac.FindInRadius(player.Position, Const.AbsorbRange, EntityPartition.BULLET)
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
        if player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
          multiplier = multiplier * 3
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
          multiplier = multiplier * (4 / (playerData.tearOrbit.length + 1))
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) and playerData.ludodivo then
          AddLudoMult(playerData.ludodivo, 1)
          table.insert(playerData.ludodivo.ExpFrames, Const.game:GetFrameCount() + player.TearRange)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) then
          tear = player:FireBomb(proj.Position, proj.Velocity, player)
          tear.RadiusMultiplier = 0.7
          tear:SetExplosionCountdown(300)
        elseif (
          player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X) or
          player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) or
          player:GetEffects():HasTrinketEffect(TrinketType.TRINKET_AZAZELS_STUMP)
        ) then
          tear = player:FireTechXLaser(proj.Position, proj.Velocity, 5, player, multiplier)
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY) and (not hasCSection) then
          local techEffect = Utils.SpawnEntity(
            EntityType.ENTITY_EFFECT,
            EffectVariant.BRIMSTONE_BALL,
            proj.Position,
            proj.Velocity,
            player
          ):ToEffect()
          if techEffect then
            techEffect.Size = 5
            techEffect.CollisionDamage = player.Damage * 0.5
            techEffect:Update()
            playerData.effectOrbit:add(player, techEffect, 300)
            OrbitingTears.CalculatePostTearSynergies(player, techEffect --[[@as EntityTear]])
          end
        elseif player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
          local fakeKnife = player:FireTear(
            proj.Position,
            proj.Velocity,
            false,
            true,
            true,
            player,
            1
          )
          fakeKnife:AddTearFlags(TearFlags.TEAR_LUDOVICO)
          local sprite = fakeKnife:GetSprite()
          sprite:Load("gfx/008.000_moms knife.anm2", true)
          sprite:Play("Idle", true)
          local orb = PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fakeKnife)
          OrbitingTears.CalculatePostTearSynergies(player, fakeKnife, orb)
        else
          tear = player:FireTear(proj.Position, proj.Velocity, true, true, true, player, multiplier)
          log.Value("Absorbing tear", {
            damage = tear.CollisionDamage,
            scale = tear.Scale,
            size = tear.Size,
          })
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
          if Utils.IsTheSun(player) then
            local extra = math.max(1, math.ceil(player.MaxFireDelay))
            if (playerData.technologyTwoLaser and playerData.technologyTwoLaser:Exists()) then
              --- setTimeout actually accepts a number
              ---@diagnostic disable-next-line: param-type-mismatch
              playerData.technologyTwoLaser:SetTimeout(playerData.technologyTwoLaser.Timeout + extra)
            else
              local laser = player:FireTechXLaser(proj.Position, Vector(0, 0), 100, player, 0.1)
              --- setTimeout actually accepts a number
              ---@diagnostic disable-next-line: param-type-mismatch
              laser:SetTimeout(extra)
              playerData.technologyTwoLaser = laser
            end
          else
            local nearestEnemy = Utils.GetClosestEnemies(player.Position)
            if nearestEnemy then
              local direction = (nearestEnemy.Position - proj.Position):Normalized()
              player:FireTechLaser(proj.Position, LaserOffset.LASER_TECH1_OFFSET, direction, false, true,
              player, multiplier)
            end
          end
        end
        if tear then
          local orb = PlayerUtils.GetPlayerData(player).tearOrbit:add(player, tear --[[@as EntityTear]])
          OrbitingTears.CalculatePostTearSynergies(player, tear --[[@as EntityTear]], orb)
        end
      elseif not playerData.projOrbit.list[projHash] then
        proj:GetData().theSunIsAbsorbed = true
        if playerData.projOrbit:hasSpace() then
          playerData.projOrbit:add(player, proj)
        end
      end
    end
    ::continue::
  end
end

local gridOffsets = {
  Vector(0, 0),                                                       -- center
  Vector(40, 0), Vector(-40, 0), Vector(0, 40), Vector(0, -40),       -- cardinals
  Vector(40, 40), Vector(-40, 40), Vector(40, -40), Vector(-40, -40), -- diagonals
  Vector(80, 0), Vector(-80, 0), Vector(0, 80), Vector(0, -80),       -- second layer cardinals
}

--- @param player EntityPlayer
function OrbitingTears.TryAbsorbEntities(player)
  for _, entity in ipairs(Isaac.GetRoomEntities()) do
    if entity.Type == EntityType.ENTITY_FIREPLACE then
      local dist = player.Position:DistanceSquared(entity.Position)
      if dist < Const.AbsorbRangeSquared then
        if entity.HitPoints > 1 and entity.Variant < 2 then -- only orange and red
          local fire = Utils.SpawnEntity(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, entity.Position,
            Vector(0, 0), player):ToEffect()
          fire.CollisionDamage = player.Damage
          if fire then
            PlayerUtils.GetPlayerData(player).effectOrbit:add(player, fire)
          end
        end
      end
    elseif entity.Type == EntityType.ENTITY_POOP then
      local dist = player.Position:DistanceSquared(entity.Position)
      if dist < Const.AbsorbRangeSquared then
        local isDamage = entity:TakeDamage(1, 0, EntityRef(player), 0)
        if isDamage then
          local tear = player:FireTear(entity.Position, Vector(0, 0), false, true, false)
          if tear then
            tear:ChangeVariant(TearVariant.BALLOON_BRIMSTONE)
            PlayerUtils.GetPlayerData(player).tearOrbit:add(player, tear)
          end
        end
      end
    elseif entity.Type == EntityType.ENTITY_LASER then
      local laser = entity:ToLaser()
      -- Asegurar que no es friendly (jugador o familiar)
      if laser and not laser:HasCommonParentWithEntity(player) then
        local samples = laser:GetSamples()
        ---@type Vector[]
        local samplesValues = {}
        if samples.Size == 0 then
          table.insert(samplesValues, laser.Position)
          table.insert(samplesValues, laser:GetEndPoint())
        else
          for i = 0, samples.Size - 1 do
            local pos = samples:Get(i)
            table.insert(samplesValues, pos)
          end
        end
        for i = 1, #samplesValues - 1 do
          local a = samplesValues[i]
          local b = samplesValues[i + 1]
          local ab = b - a
          local t = math.max(0, math.min(1, (player.Position - a):Dot(ab) / ab:LengthSquared()))
          local closest = a + ab * t
          local dist = player.Position:DistanceSquared(closest)

          if dist < Const.AbsorbRangeSquared then
            local techEffect = Utils.SpawnEntity(
              EntityType.ENTITY_EFFECT,
              EffectVariant.BRIMSTONE_BALL,
              closest,
              ab:Normalized(),
              player
            ):ToEffect()
            if techEffect then
              techEffect.Color = Color(1, 0.5, 0, 1)
              techEffect.Size = 10
              techEffect.CollisionDamage = player.Damage
              techEffect:Update()
              PlayerUtils.GetPlayerData(player).effectOrbit:add(player, techEffect, 300)
            end
            goto continue
          end
        end
        ::continue::
      end
    end
  end

  local room = Game():GetRoom()
  local playerPos = player.Position
  

  for _, offset in ipairs(gridOffsets) do
    local checkPos = playerPos + offset
    local gridEntity = room:GetGridEntityFromPos(checkPos)
    if gridEntity and gridEntity:GetType() == GridEntityType.GRID_POOP then
      local poop = gridEntity:ToPoop()
      local isDamage = poop:Hurt(1)
      if poop and isDamage then
        local tear = player:FireTear(checkPos, Vector(0, 0), false, true, false)
        if tear then
          tear:ChangeVariant(TearVariant.BALLOON_BRIMSTONE)
          PlayerUtils.GetPlayerData(player).tearOrbit:add(player, tear)
        end
      end
    end
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
    if player:HasTrinket(TrinketType.TRINKET_BRAIN_WORM) and gameFrameCount % 8 == 0 then
      OrbitingTears.ReleaseHomingTears(player)
    end
    OrbitingTears.SpinOrbitingTears(player, playerData.tearOrbit)
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
  OrbitingTears.SpinOrbitingTears(player, playerData.projOrbit)
  for hash, orb in pairs(playerData.effectOrbit.list) do
    if (orb.entity.Type == EntityType.ENTITY_TEAR) then --knives
      local sprite = orb.entity:GetSprite()
      sprite.Rotation = orb.entity.Velocity:GetAngleDegrees() - 90
    end
    if not (orb.entity and orb.entity:Exists()) or orb.expirationFrame < gameFrameCount then
      playerData.effectOrbit:remove(hash)
      if (orb.entity.Type == EntityType.ENTITY_TEAR) then --knives
        Store.releasedTears[GetPtrHash(orb.entity)] = {
          tear = orb.entity --[[@as EntityTear]],
          velocity = orb.entity.Velocity,
          expirationFrame = gameFrameCount + player.TearRange,
        }
      elseif (orb.entity.Variant == EffectVariant.BRIMSTONE_BALL) then
        player:FireTechLaser(orb.entity.Position, LaserOffset.LASER_TECH1_OFFSET, orb.entity.Velocity:Normalized(), false, true, player, 1)
        orb.entity:Remove()
      end
    end
  end
  OrbitingTears.SpinOrbitingTears(player, playerData.effectOrbit)
end

return OrbitingTears

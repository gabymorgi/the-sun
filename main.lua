---@alias EntityOrbital EntityTear | EntityProjectile | EntityEffect
---@class Dict<T>: { [number]: T }

include("thesun-src.Eid")
---@type Store
local Store = require("thesun-src.Store")
---@type Const
local Const = require("thesun-src.Const")
---@type Utils
local Utils = include("thesun-src.Utils")
---@type OrbitingTears
local OrbitingTears = include("thesun-src.OrbitingTears")
---@type WallFire
local WallFire = include("thesun-src.WallFire")
---@type PlayerUtils
local PlayerUtils = include("thesun-src.PlayerUtils")

local theSunMod = RegisterMod("The Orbits of Asterogues", 1)

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

local cachedRoomShape = RoomShape.ROOMSHAPE_1x1
local cachedPlayerCount = 1

---@param player EntityPlayer
function theSunMod:PlayerInit(player)
  local cachePlayer = false
  if Utils.IsTheSun(player) then
    player:AddNullCostume(Const.HairCostume)
    player:AddTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE, true)
    player:UsePill(PillEffect.PILLEFFECT_GULP, 0)
    cachePlayer = true
  elseif Utils.IsPluto(player) then
    -- player.SizeMulti = Vector(0.5, 0.5)
    player:ClearCostumes()
    player:AddTrinket(TrinketType.TRINKET_FRIENDSHIP_NECKLACE, true)
    player:UsePill(PillEffect.PILLEFFECT_GULP, 0)
    player:AddCollectible(CollectibleType.COLLECTIBLE_SOUL, 0, false)
    cachePlayer = true
  end

  if not cachePlayer then return end

  local players = Utils.GetPlayers()
  if #players ~= cachedPlayerCount then
    cachedPlayerCount = math.max(#players, 4)
    for _, p in pairs(players) do
      p:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
      p:EvaluateItems()
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.PlayerInit)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheRange(player)
  if not Utils.IsTheSun(player) then return end
  PlayerUtils.GetPlayerData(player).orbitRange.max = player.TearRange / 3
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheRange, CacheFlag.CACHE_RANGE)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFlight(player)
  if not Utils.IsTheSun(player) then return end
  player.CanFly = true
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFlight, CacheFlag.CACHE_FLYING)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFireDelay(player)
  if not Utils.HasOrbit(player) then return end
  player.MaxFireDelay = playerInRoomMultiplier[cachedPlayerCount] * roomMultiplier[cachedRoomShape] * player.MaxFireDelay
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFireDelay, CacheFlag.CACHE_FIREDELAY)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheDamage(player)
  if not Utils.IsPluto(player) then return end
  player.Damage = player.Damage * 1.5
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheDamage, CacheFlag.CACHE_DAMAGE)

--- COLLECTIBLE_MOMS_WIG effect
---@param entity Entity
function theSunMod:OnEntityDeath(entity)
  if entity.SpawnerEntity and entity.Type == EntityType.ENTITY_FAMILIAR and entity.Variant == FamiliarVariant.BLUE_SPIDER then
    local player = entity.SpawnerEntity:ToPlayer()
    if not player or not Utils.HasOrbit(player) then return end
    local playerData = PlayerUtils.GetPlayerData(player)
    playerData.friendlySpiderCount = math.max(0, playerData.friendlySpiderCount - 1)
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, theSunMod.OnEntityDeath)

function theSunMod:OnRoomEnter()
  local players = Utils.GetPlayers()
  if #players == 0 then return end

  Store.WallProjectiles = {}
  for _, player in pairs(players) do
    PlayerUtils.HandleNewRoom(player)
  end

  local room = Const.game:GetRoom()
  local roomShape = room:GetRoomShape()
  if (cachedRoomShape ~= roomShape) then
    cachedRoomShape = roomShape
    for _, player in pairs(players) do
      player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
      player:EvaluateItems()
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, theSunMod.OnRoomEnter)

--- release bomb on collision
---@param bomb EntityBomb
---@param collider Entity
function theSunMod:OnBombCollision(bomb, collider)
  if not bomb.SpawnerEntity then
    return
  end
  local player = bomb.SpawnerEntity:ToPlayer()
  if not player or not Utils.HasOrbit(player) then
    return
  end
  if collider:IsActiveEnemy() and collider:IsVulnerableEnemy() then
    local playerData = PlayerUtils.GetPlayerData(player)
    local bombHash = GetPtrHash(bomb)
    if playerData.tearOrbit.list[bombHash] then
      playerData.tearOrbit:remove(bombHash, player)
      if bomb.FrameCount < 240 then
        bomb:SetExplosionCountdown(15)
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_PRE_BOMB_COLLISION, theSunMod.OnBombCollision)

---@param tear EntityTear
---@param collider Entity
function theSunMod:OnTearCollision(tear, collider)
  if not tear.SpawnerEntity then return end
  local player = tear.SpawnerEntity:ToPlayer()
  if not player or not Utils.HasOrbit(player) then
    return
  end
  local playerData = PlayerUtils.GetPlayerData(player)
  if playerData.ludodivo and GetPtrHash(tear) == GetPtrHash(playerData.ludodivo.Tear) then
    -- overrides default ludo damage
    tear.CollisionDamage = playerData.ludodivo.BaseDamage * playerData.ludodivo.Multiplier
    return
  end
  local tearHash = GetPtrHash(tear)
  if not playerData.tearOrbit.list[tearHash] then
    return
  end
  if collider:IsActiveEnemy() and collider:IsVulnerableEnemy() then
    -- local isPiercing = tear:HasTearFlags(TearFlags.TEAR_PIERCING)
    -- sticky: explosivo - sinus infection - mucormycosis
    -- local isSticky = tear:HasTearFlags(TearFlags.TEAR_STICKY | TearFlags.TEAR_BOOGER | TearFlags.TEAR_SPORE)
    if tear:HasTearFlags(TearFlags.TEAR_BOUNCE) then
      playerData.tearOrbit:remove(tearHash, player)
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, theSunMod.OnTearCollision)

---@param projectile EntityProjectile
---@param collider Entity
function theSunMod:OnProjectileCollision(projectile, collider)
  local orbitPlayers = Utils.GetPlayers()
  if #orbitPlayers == 0 then return end
  local playerHash
  if collider then
    local familiar = collider:ToFamiliar()
    if familiar and familiar.Variant == FamiliarVariant.PSY_FLY then
      playerHash = GetPtrHash(familiar.Player)
    end
  end
  for _, p in pairs(Utils.GetPlayers()) do
    if playerHash == GetPtrHash(p) then
      OrbitingTears.SpawnTear(p, projectile)
      return
    end
  end

  for _, p in pairs(Utils.GetPlayers()) do
    local playerData = PlayerUtils.GetPlayerData(p)
    if playerData.projOrbit.list[GetPtrHash(projectile)] then
      if collider:IsActiveEnemy() and collider:IsVulnerableEnemy() then
        playerData.projOrbit:remove(GetPtrHash(projectile))
      end
      return
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_PRE_PROJECTILE_COLLISION, theSunMod.OnProjectileCollision)

---@param player EntityPlayer
function theSunMod:OnPeffectUpdate(player)
  if not Utils.HasOrbit(player) then return end

  local frameCount = Const.game:GetFrameCount()
  local room = Const.game:GetRoom()
  local playerData = PlayerUtils.GetPlayerData(player)
  if not room:IsClear() or Isaac.CountEnemies() > 0 then
    if player.FireDelay <= 0 then
      if player:HasCollectible(CollectibleType.COLLECTIBLE_KIDNEY_STONE) then
        if playerData.kidneyStoneFrame < frameCount then
          goto skipShot
        end
      end
      local clusterShot = false
      if player:HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) then
        clusterShot = true
      elseif player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
        playerData.leadPencilCount = playerData.leadPencilCount + 1
        if playerData.leadPencilCount > 15 then
          playerData.leadPencilCount = 0
          clusterShot = true
        end
      end
      if clusterShot then
        WallFire.ClusterWallShot(player)
      else
        WallFire.WallShot(player)
      end
      if player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_5) then
        if frameCount % 4 == 0 and Const.rng:RandomFloat() < 0.18 then
          if Utils.IsTheSun(player) then
            local laser = player:FireTechXLaser(player.Position, player.Velocity, playerData.orbitRange.act, player)
            --- setTimeout actually accepts a number
            ---@diagnostic disable-next-line: param-type-mismatch
            laser:SetTimeout(5)
            laser.OneHit = true
          else
            local nearestEnemy = Utils.GetClosestEnemies(player.Position)
            if nearestEnemy then
              local direction = (nearestEnemy.Position - player.Position):Normalized()
              player:FireTechLaser(player.Position, LaserOffset.LASER_TECH5_OFFSET, direction, false, true,
                player, 1)
            end
          end
        end
      end
      player.FireDelay = player.MaxFireDelay
    end

    ::skipShot::

    if playerData.activeBars[CollectibleType.COLLECTIBLE_NEPTUNUS] then
      local bar = playerData.activeBars[CollectibleType.COLLECTIBLE_NEPTUNUS]
      if playerData.tearOrbit.length > 0 then
        if bar.charge > 0 then
          local min = math.min(bar.charge, player.FireDelay)
          bar:add(-min)
          player.FireDelay = player.FireDelay - min
        end
      else
        bar:add(1)
      end
    end
  else
    if not Store.roomCleared then
      Utils.ReplaceTNTWithTrollBombs()
      Store.roomCleared = true
    end
    for hash, proj in pairs(Store.WallProjectiles) do
      proj:Die()
      Store.WallProjectiles[hash] = nil
    end
  end

  OrbitingTears.TryAbsorbTears(player)
  if frameCount % 16 == 0 then
    OrbitingTears.TryAbsorbEntities(player)
  end
  if Utils.IsPluto(player) then
    if player:GetShootingInput():Length() > 0 or (player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) and Utils.GetMarkedTarget(player)) then
      OrbitingTears.VengefulRelease(player)
    end
  else
    OrbitingTears.UpdateOrbitingRadius(player)
  end
  OrbitingTears.UpdateOrbitingEntities(player)
  OrbitingTears.UpdateOrbitingTears(player)
  if frameCount % 32 == 0 then -- once every second
    PlayerUtils.CachePlayerCollectibles(player)
  end
  if Input.IsActionPressed(ButtonAction.ACTION_DROP, player.ControllerIndex) then
    OrbitingTears.DropRelease(player)
  end
  if frameCount % 8 == 0 then -- orbit damage
    local currentFloor = Game():GetLevel():GetAbsoluteStage()

    for _, enemy in ipairs(Utils.GetEnemiesInRange(player.Position, Const.AbsorbRange)) do
      if enemy:IsVulnerableEnemy() and not enemy:IsDead() then
        local dist = player.Position:DistanceSquared(enemy.Position)
        local t = 1 - math.min(dist / Const.AbsorbRangeSquared, 1) -- 1 cerca, 0 en el borde
        local dmg = 0.4 + t * (3.9 + 0.3 * currentFloor - 0.4)
        enemy:TakeDamage(dmg, DamageFlag.DAMAGE_FAKE, EntityRef(player), 0)
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, theSunMod.OnPeffectUpdate)

--- handles manually time before wizard stop
--- @param pillEffect PillEffect
--- @param player EntityPlayer
function theSunMod:OnUsePill(pillEffect, player, _)
  if pillEffect == PillEffect.PILLEFFECT_WIZARD and Utils.HasOrbit(player) then
    PlayerUtils.GetPlayerData(player).wizardRemainingFrames = 30 * Const.FPS
  end
end
theSunMod:AddCallback(ModCallbacks.MC_USE_PILL, theSunMod.OnUsePill)

--- tries to detect tears spawned by prisma
--- @param tear EntityTear
function theSunMod:HandleBlueTearUpdate(tear)
  if Store.prismCachedCount < 1 then return end
  --- Accessing the initialized entity on MC_POST_TEAR_INIT provides incomplete data in some use cases
  if tear.FrameCount == 1 then
    local player = tear.SpawnerEntity:ToPlayer()
    if not player or not Utils.HasOrbit(player) then return end
    local color = Utils.GetColorOffset(tear)

    if color then
      local playerData = PlayerUtils.GetPlayerData(player)
      if (playerData.tearOrbit:hasSpace()) then
        local newOrb = playerData.tearOrbit:add(player, tear)
        newOrb.direction = newOrb.direction * Utils.colorOffsets[color].rangeMultiplier
      else
        tear.Velocity = tear.Velocity * 10
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, theSunMod.HandleBlueTearUpdate, TearVariant.BLUE)

--- handles manually time before kidney stop
--- @param tear EntityTear
function theSunMod:HandleStoneTearUpdate(tear)
  --- Accessing the initialized entity on MC_POST_TEAR_INIT provides incomplete data in some use cases
  if tear.FrameCount == 1 then
    local player = tear.SpawnerEntity:ToPlayer()
    if not player or not Utils.HasOrbit(player) then return end
    local playerData = PlayerUtils.GetPlayerData(player)
    local tearHash = GetPtrHash(tear)
    if playerData.tearOrbit.list[tearHash] then
      return
    end
    local orb = playerData.tearOrbit:add(player, tear)
    orb.direction = 2
    playerData.kidneyStoneFrame = Const.game:GetFrameCount() + Const.FPS * 30
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, theSunMod.HandleStoneTearUpdate, TearVariant.STONE)

--- @param effect EntityEffect
function theSunMod:HandleEffectInit(effect)
  if not Utils.AnyoneHasOrbit() then return end
  -- evil eye doesnt have a spawner entity, so we need to find the closest player with the collectible
  local closestPlayer = nil
  local closestDistance = math.huge
  for i = 0, Const.game:GetNumPlayers() - 1 do
    local player = Const.game:GetPlayer(i)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_EVIL_EYE) then
      local distance = player.Position:DistanceSquared(effect.Position)
      if distance < closestDistance then
        closestDistance = distance
        closestPlayer = player
      end
    end
  end
  if closestPlayer and Utils.HasOrbit(closestPlayer) then
    PlayerUtils.GetPlayerData(closestPlayer).effectOrbit:add(closestPlayer, effect)
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, theSunMod.HandleEffectInit, EffectVariant.EVIL_EYE)

local RADIUS = 30
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player)
  if not Game():GetHUD():IsVisible() then return end
  if Game():IsPaused() then return end

  local activeBars = PlayerUtils.GetPlayerData(player).activeBars
  local keys = {}
  for k in pairs(activeBars) do table.insert(keys, k) end
  table.sort(keys)

  local n = #keys
  for i, id in ipairs(keys) do
    if i > 8 then break end
    local angle = (i - 1) * 45
    local offset = Vector.FromAngle(angle):Resized(RADIUS)
    local scrPos = Isaac.WorldToScreen(player.Position + offset)

    local bar = activeBars[id]
    local charging = bar.charge > 0

    bar:render(scrPos, charging)
  end
end)

---@param entity Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdownFrames integer
function theSunMod:OnTakeDamage(entity, amount, flags, source, countdownFrames)
  if not source or not source.Entity then return end
  local sourceHash = GetPtrHash(source.Entity)
  for _, player in pairs(Utils.GetPlayers()) do
    local playerData = PlayerUtils.GetPlayerData(player)
    local orb = playerData.tearOrbit.list[sourceHash]
    if orb and (orb.flags & Const.CustomFlags.TEAR_LUDOVICO ~= 0) then
      if (orb.flags & Const.CustomFlags.TEAR_TECH ~= 0) then
        local angle = (entity.Position - source.Entity.Position):GetAngleDegrees()
        PlayerUtils.FireLaserFromTear(player, orb, angle)
        playerData.tearOrbit:remove(sourceHash, player)
        source.Entity:Remove()
      else
        orb.hitCounts = orb.hitCounts + 1
        if orb.hitCounts > 4 then
          playerData.tearOrbit:remove(sourceHash, player)
        end
      end
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, theSunMod.OnTakeDamage)

---@param entity Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdownFrames integer
function theSunMod:OnPlayerTakeDamage(entity, amount, flags, source, countdownFrames)
  local player = entity:ToPlayer()
  if not player or not Utils.HasOrbit(player) then return end

  -- Chack that is not going to die
  local health = player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts()
  if health < 2 then return end
  local activeBars = PlayerUtils.GetPlayerData(player).activeBars
  if (activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE] and not player:HasCollectible(CollectibleType.COLLECTIBLE_BLACK_CANDLE)) then
    local bar = activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE]
    if bar.charge > 0 and not bar:isFull() then
      Const.game:MoveToRandomRoom(false, Const.rng:RandomInt(100) + 1, player)
    end
  end
end

theSunMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, theSunMod.OnPlayerTakeDamage, EntityType.ENTITY_PLAYER)

local color = Color(1, 1, 1, 1, 0, 0, 0, 0, 0, 0)
local function OnPostUpdate()
  -- force remove ghost color for non friendly projectiles
  for _, playerData in pairs(Store.PlayerData) do
    for _, proj in pairs(playerData.projOrbit.list) do
      proj.entity:SetColor(color, 1, 1, false, false)
    end
  end
  for hash, proj in pairs(Store.WallProjectiles) do
    if not proj:HasProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER) then
      proj:SetColor(color, 1, 1, false, false)
    end
  end

  local players = Utils.GetPlayers()
  if #players < 1 then return end
  -- mocked knives control
  for _, player in pairs(players) do
    local playerData = PlayerUtils.GetPlayerData(player)
    for _, orb in pairs(playerData.tearOrbit.list) do
      if (orb.flags & Const.CustomFlags.TEAR_KNIFE) ~= 0 then
        orb.entity:GetSprite().Rotation = orb.entity.Velocity:GetAngleDegrees() - 90
      end
    end
  end
  local frameCount = Const.game:GetFrameCount()
  local room = Const.game:GetRoom()
  local offset = Vector(5, 5)
  local topLeftPos = room:GetTopLeftPos() + offset
  local bottomRightPos = room:GetBottomRightPos() - offset
  for hash, orb in pairs(Store.releasedTears) do
    local isOutside = false
    local pos = orb.tear.Position
    if pos.X < topLeftPos.X or pos.X > bottomRightPos.X
        or pos.Y < topLeftPos.Y or pos.Y > bottomRightPos.Y then
      isOutside = true
    end
    if isOutside or orb.expirationFrame < frameCount then
      Store.releasedTears[hash] = nil
      orb.tear:Remove()
    else
      orb.tear.Velocity = orb.velocity
    end
    if (orb.turnSprite) then
      orb.tear:GetSprite().Rotation = orb.tear.Velocity:GetAngleDegrees() - 90
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_UPDATE, OnPostUpdate)

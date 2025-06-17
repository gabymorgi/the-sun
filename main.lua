---@alias EntityOrbital EntityTear | EntityProjectile | EntityEffect

---@class Dict<T>: { [number]: T }

local log = include("log")

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

local theSunMod = RegisterMod("The Sun Character Mod", 1)

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

---@param player EntityPlayer
function theSunMod:PlayerInit(player)
  local cachePlayer = false
  if Utils.IsTheSun(player) then
    player:AddNullCostume(Const.HairCostume)
    cachePlayer = true
  elseif Utils.IsPluto(player) then
    player.SizeMulti = Vector(0.5, 0.5)
    player:ClearCostumes()
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
  
  log.Value("onEvaluateCacheFireDelay", player.MaxFireDelay)
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFireDelay, CacheFlag.CACHE_FIREDELAY)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheDamage(player)
  if not Utils.IsPluto(player) then return end

  player.Damage = player.Damage * 1.5
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheDamage, CacheFlag.CACHE_DAMAGE)

---@param player EntityPlayer
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player)
  if Utils.IsPluto(player) then
    log.Value("pre onEvaluateCacheSize", player.SizeMulti)
    -- player.SizeMulti = Vector(0.5, 0.5)
    log.Value("onEvaluateCacheSize", {
      Size = player.Size,
      SizeMulti = player.SizeMulti,
    })
  end
end, CacheFlag.CACHE_SIZE);

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

---@param bomb EntityBomb
---@param collider Entity
function theSunMod:OnBombCollision(bomb, collider)
  -- log.Value("OnBombCollision", {
  --   flags = log.Flag("tear", tear.TearFlags),
  --   variant = log.Enum("tear", tear.Variant),
  --   collision = tear.CollisionDamage,
  -- })
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
      playerData.tearOrbit:remove(bombHash)
    end
  end
end
theSunMod:AddCallback(ModCallbacks.MC_PRE_BOMB_COLLISION, theSunMod.OnBombCollision)

---@param tear EntityTear
---@param collider Entity
function theSunMod:OnTearCollision(tear, collider)
  -- log.Value("OnTearCollision", {
  --   flags = log.Flag("tear", tear.TearFlags),
  --   variant = log.Enum("tear", tear.Variant),
  --   collision = tear.CollisionDamage,
  -- })
  --tear.CollisionDamage = 2
  
  local player = tear.SpawnerEntity:ToPlayer()
  if not player or not Utils.HasOrbit(player) then
    return
  end
  local playerData = PlayerUtils.GetPlayerData(player)
  if tear:HasTearFlags(TearFlags.TEAR_LUDOVICO) then
    log.Value("ludodivo collision", tostring(playerData.ludodivo.BaseDamage) .. " * " .. tostring(playerData.ludodivo.Multiplier))
    tear.CollisionDamage = playerData.ludodivo.BaseDamage * playerData.ludodivo.Multiplier
    return
  end
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

---@param player EntityPlayer
function theSunMod:OnUpdate(player)
  -- local itemConfigPluto = Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_PLUTO)
  -- player:RemoveCostume(itemConfigPluto)

  if not Utils.HasOrbit(player) then return end

  local frameCount = Const.game:GetFrameCount()
  local room = Const.game:GetRoom()
  -- if not room:IsClear() then -- TOMOD
  if true then
    local playerData = PlayerUtils.GetPlayerData(player)
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

    OrbitingTears.TryAbsorbTears(player)
    if Utils.IsPluto(player) then
      -- local target
      if player:GetShootingInput():Length() > 0 or (player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) and Utils.GetMarkedTarget(player)) then
        OrbitingTears.VengefulRelease(player)
      end
    end
  end

  OrbitingTears.UpdateOrbitingRadius(player)
  OrbitingTears.UpdateOrbitingEntities(player)
  OrbitingTears.UpdateOrbitingTears(player)
  if frameCount % 32 == 0 then -- once every second
    PlayerUtils.CachePlayerCollectibles(player)
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, theSunMod.OnUpdate)

--- @param pillEffect PillEffect
--- @param player EntityPlayer
function theSunMod:OnUsePill(pillEffect, player, _)
  if pillEffect == PillEffect.PILLEFFECT_WIZARD and Utils.HasOrbit(player) then
    PlayerUtils.GetPlayerData(player).wizardRemainingFrames = 30 * Const.FPS -- 30 segundos
  end
end
theSunMod:AddCallback(ModCallbacks.MC_USE_PILL, theSunMod.OnUsePill)

--- @param tear EntityTear
function theSunMod:HandleBlueTearUpdate(tear)
  if Store.prismCachedCount < 1 then return end
  --- Accessing the initialized entity on MC_POST_TEAR_INIT does provide incomplete data in some use cases
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

--- @param tear EntityTear
function theSunMod:HandleStoneTearUpdate(tear)
  --- Accessing the initialized entity on MC_POST_TEAR_INIT does provide incomplete data in some use cases
  if tear.FrameCount == 1 then
    -- log.Value("tear updated", {
    --   Variant = log.Enum("tear", tear.Variant),
    --   Flags = log.Flag("tear", tear.TearFlags),
    -- })
    local player = tear.SpawnerEntity:ToPlayer()
    if not player or not Utils.HasOrbit(player) then return end
    local playerData = PlayerUtils.GetPlayerData(player)
    local tearHash = GetPtrHash(tear)
    if playerData.tearOrbit.list[tearHash] then
      return
    end
    local orb = playerData.tearOrbit:add(player, tear)
    orb.direction = 2
    playerData.kidneyStoneFrame = Const.game:GetFrameCount() + 25 * 30 -- 30 segundos
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, theSunMod.HandleStoneTearUpdate, TearVariant.STONE)

--- @param tear EntityLaser
function theSunMod:HandleLaserUpdate(tear)
  log.Value("laser updated 0", tear.FrameCount)
  --- Accessing the initialized entity on MC_POST_TEAR_INIT does provide incomplete data in some use cases
  if tear.FrameCount == 1 then
    log.Value("laser updated", {
      Variant = log.Enum("tear", tear.Variant),
      Flags = log.Flag("tear", tear.TearFlags),
    })
  end
end
theSunMod:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, theSunMod.HandleLaserUpdate)

--- @param effect EntityEffect
function theSunMod:HandleEffectInit(effect)
  -- log.Value("HandleEffectInit", {
  --   variant = log.Enum("effect", effect.Variant)
  -- })
  if (#Utils.GetPlayers() < 1) then return end
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
  -- log.Value("HandleProjInit", {
  --   flags = proj.ProjectileFlags, -- log.Flag("proj", proj.ProjectileFlags),
  --   variant = proj.Variant,       -- log.Enum("proj", proj.Variant),
  --   color = proj.Color,
  --   spawnerType = proj.SpawnerType,
  --   spawnerVariant = proj.SpawnerVariant,
  -- })
  if not proj.SpawnerEntity then
    return
  end
  local player = proj.SpawnerEntity:ToPlayer()
  if not player then
    return
  end
  if not Utils.HasOrbit(player) then
    return
  end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, theSunMod.HandleProjInit)

--- @param knife EntityKnife
function theSunMod:HandleKnifeInit(knife)
  -- log.Value("HandleKnifeInit", {
  --   flags = log.Flag("proj", knife.TearFlags),
  --   variant = knife.Variant, -- log.Enum("proj", proj.Variant),
  --   rotation = knife.Rotation,
  --   rotationOffset = knife.RotationOffset,
  -- })
end

theSunMod:AddCallback(ModCallbacks.MC_POST_KNIFE_INIT, theSunMod.HandleKnifeInit)



--- @param tear EntityTear
function theSunMod:HandleFireTear(tear)
  -- log.Value("tear fired", {
  --   Variant = log.Enum("tear", tear.Variant),
  --   Flags = log.Flag("tear", tear.TearFlags),
  --   frameCount = tear.FrameCount,
  -- })
  
end
theSunMod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, theSunMod.HandleFireTear)

--- @param tear EntityLaser
function theSunMod:HandleFireTechLaser(tear, player)
  log.Value("laser", {
    Variant = log.Enum("tear", tear.Variant),
    Flags = log.Flag("tear", tear.TearFlags),
    timeout = tear.Timeout,
  })
end

theSunMod:AddCallback(ModCallbacks.MC_POST_FIRE_TECH_X_LASER, theSunMod.HandleFireTechLaser)


local RADIUS = 30 -- píxeles aprox. (ajústalo a gusto)
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, function(_, player)
  if not Game():GetHUD():IsVisible() then return end
  if Game():IsPaused() then return end

  local activeBars = PlayerUtils.GetPlayerData(player).activeBars
  local keys = {}          -- para mantener un orden estable
  for k in pairs(activeBars) do table.insert(keys, k) end
  table.sort(keys)

  local n = #keys
  for i, id in ipairs(keys) do
    if i > 8 then break end                        -- seguridad; nunca más de 8
    local angle = (i - 1) * 45                    -- 0°, 45°, 90°…
    local offset = Vector.FromAngle(angle):Resized(RADIUS)
    local scrPos = Isaac.WorldToScreen(player.Position + offset)

    local bar = activeBars[id]
    local charging = bar.charge > 0           -- lógica de ejemplo
    
    bar:render(scrPos, charging)
  end
end)

---@param entity Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdownFrames integer
function theSunMod:OnTakeDamage(entity, amount, flags, source, countdownFrames)
  local player = entity:ToPlayer()
  if not player or not Utils.HasOrbit(player) then return end

  -- Verifica que no esté muerto ni en animaciones raras
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
theSunMod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, theSunMod.OnTakeDamage, EntityType.ENTITY_PLAYER)

local color = Color(1, 1, 1, 1, 0, 0, 0, 0, 0, 0)
local function ForceColorEveryFrame()
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
end
theSunMod:AddCallback(ModCallbacks.MC_POST_UPDATE, ForceColorEveryFrame)
--------------------------------------------------------------------------------------------------





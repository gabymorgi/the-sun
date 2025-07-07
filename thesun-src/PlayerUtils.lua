---@type Store
local Store = require("thesun-src.Store")
---@type Const
local Const = require("thesun-src.Const") --
---@type Utils
local Utils = require("thesun-src.Utils")
---@type ChargeBar
local ChargeBar = require("thesun-src.ChargeBar") --
local Orbit = require("thesun-src.Orbit") --
---@type Orbit<EntityTear>
local TearOrbit = Orbit.TearOrbit
---@type Orbit<EntityProjectile>
local ProjectileOrbit = Orbit.ProjectileOrbit
---@type Orbit<EntityEffect>
local EffectOrbit = Orbit.EffectOrbit

---@class Ludovico 
---@field Tear EntityTear
---@field BaseDamage number
---@field Multiplier number
---@field ExpFrames number[]
---@field Index number

---@class PlayerData
---@field tearOrbit Orbit<EntityTear>
---@field projOrbit Orbit<EntityProjectile>
---@field effectOrbit Orbit<EntityEffect>
---@field orbitRange { min: number, max: number, act: number }
---@field cacheCollectibles Dict<number | boolean>
---@field activeBars Dict<ChargeBar>
---@field kidneyStoneFrame number
---@field leadPencilCount number
---@field tornCardCount number
---@field friendlySpiderCount number
---@field wizardRemainingFrames number
---@field technologyTwoLaser EntityLaser | nil
---@field antigravityTears Dict<EntityTear>
---@field ludodivo Ludovico | nil

---@class PlayerUtils
---@field GetPlayerData fun(player: EntityPlayer): PlayerData
---@field HandleNewRoom fun(player: EntityPlayer)
---@field CachePlayerCollectibles fun(player: EntityPlayer)
---@field FirePoopTear fun(player: EntityPlayer, pos: Vector, poopVariant: number)
---@field FireLaserTear fun(player: EntityPlayer, pos: Vector, vel: Vector, laserVariant: number, amount?: number): Orbital<EntityTear>
---@field FireLaserFromTear fun(player: EntityPlayer, orb: Orbital<EntityOrbital>, angle: number): EntityLaser

local ABSORB_ORBIT_VARIANT = Isaac.GetEntityVariantByName("Absorb orbit")

local PlayerUtils = {}

---@param player EntityPlayer
---@return PlayerData
function PlayerUtils.GetPlayerData(player)
  local playerHash = GetPtrHash(player)
  if not Store.PlayerData[playerHash] then
    Store.PlayerData[playerHash] = {
      tearOrbit = TearOrbit:new(),
      projOrbit = ProjectileOrbit:new(),
      effectOrbit = EffectOrbit:new(),
      orbitRange = {
        min = Const.GRID_SIZE,
        max = 90,
        act = Const.GRID_SIZE,
      },
      cacheCollectibles = {},
      activeBars = {},
      kidneyStoneFrame = 0,
      leadPencilCount = 0,
      tornCardCount = 0,
      friendlySpiderCount = 0,
      wizardRemainingFrames = 0,
      antigravityTears = {},
    }
  end
  return Store.PlayerData[playerHash]
end

--- @param player EntityPlayer
function AddLudoTear(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local tear = player:FireTear(
    player.Position,
    player.Velocity,
    false,
    true,
    true,
    player,
    1
  )
  tear:AddTearFlags(TearFlags.TEAR_LUDOVICO)
  tear.Scale = 2
  playerData.ludodivo = {
    Tear = tear,
    BaseDamage = tear.CollisionDamage,
    Multiplier = 0.5,
    ExpFrames = {},
    Index = 1,
  }
end

---@param player EntityPlayer
function PlayerUtils.HandleNewRoom(player)
  Store.roomCleared = false
  local absorbEffect = Utils.SpawnEntity(
    EntityType.ENTITY_EFFECT,
    ABSORB_ORBIT_VARIANT,
    player.Position,
    Vector(0, 0),
    player
  ):ToEffect()
  if absorbEffect then
    absorbEffect.SpriteOffset = Vector(0, -10)
    absorbEffect.Position = player.Position
    absorbEffect:FollowParent(player)
  end

  local playerData = PlayerUtils.GetPlayerData(player)
  playerData.tearOrbit = TearOrbit:new()
  playerData.projOrbit = ProjectileOrbit:new()
  playerData.effectOrbit = EffectOrbit:new()
  playerData.antigravityTears = {}

  if (player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE)) then
    AddLudoTear(player)
  end

  if Utils.IsPluto(player) then
    player:ClearCostumes()
  elseif Utils.IsTheSun(player) then
    -- mother chase
    if player:HasCurseMistEffect() then
      player:AddNullCostume(Const.HairCostume)
    end
  end
end

---@param value? boolean
---@param playerData PlayerData
local function changeMinRange(value, playerData)
  playerData.orbitRange.min = value and 100 or Const.GRID_SIZE
  playerData.orbitRange.act = Utils.Clamp(playerData.orbitRange.act, playerData.orbitRange.min, playerData.orbitRange.max)
end

---@param collectibleType number
---@param maxCharge number
---@return fun(value: boolean, playerData: PlayerData)
local function changeChargeBarFactory(collectibleType, maxCharge)
  return function(value, playerData)
    if value then
      playerData.activeBars[collectibleType] = ChargeBar:new(maxCharge)
    else
      playerData.activeBars[collectibleType] = nil
    end
  end
end

---@param value? boolean
---@param playerData PlayerData
---@param player EntityPlayer
local function changeLudoTear(value, playerData, player)
  if value then
    if not playerData.ludodivo then
      AddLudoTear(player)
    end
  else
    if playerData.ludodivo then
      playerData.ludodivo.Tear:Remove()
      playerData.ludodivo = nil
    end
  end
end

---@param value? boolean
local function changePrismCachedCount(value)
  if value then
    Store.prismCachedCount = Store.prismCachedCount + 1
  else
    Store.prismCachedCount = Store.prismCachedCount - 1
  end
end

local collectibles = {
  [CollectibleType.COLLECTIBLE_DR_FETUS] = changeMinRange,
  [CollectibleType.COLLECTIBLE_EPIC_FETUS] = changeMinRange,
  [CollectibleType.COLLECTIBLE_IPECAC] = changeMinRange,
  [CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = changeLudoTear,
  [CollectibleType.COLLECTIBLE_ANGELIC_PRISM] = changePrismCachedCount,
  [CollectibleType.COLLECTIBLE_CURSED_EYE] = changeChargeBarFactory(CollectibleType.COLLECTIBLE_CURSED_EYE, 5),
  [CollectibleType.COLLECTIBLE_NEPTUNUS] = changeChargeBarFactory(CollectibleType.COLLECTIBLE_NEPTUNUS, 3 * Const.FPS),
}

---@param player EntityPlayer
function PlayerUtils.CachePlayerCollectibles(player)
  local playerData = PlayerUtils.GetPlayerData(player)

  for collectibleType, handler in pairs(collectibles) do
    local hasItem = player:HasCollectible(collectibleType) and true or nil
    if hasItem ~= playerData.cacheCollectibles[collectibleType] then
      playerData.cacheCollectibles[collectibleType] = hasItem
      handler(hasItem, playerData, player)
    end
  end
  playerData.cacheCollectibles[CollectibleType.COLLECTIBLE_TRACTOR_BEAM] = player:HasCollectible(CollectibleType.COLLECTIBLE_TRACTOR_BEAM)
end

---@param player EntityPlayer
---@param pos Vector
---@param poopVariant number
function PlayerUtils.FirePoopTear(player, pos, poopVariant)
  local multiplier = 1
  if poopVariant > 6 and poopVariant < 11 then
    multiplier = 4
  end
  local tear = player:FireTear(
    pos,
    Vector(0, 0),
    false,
    true,
    true,
    player,
    multiplier
  )
  if not tear then return end
  if poopVariant == 0 then -- normal poop
    tear:ChangeVariant(TearVariant.BALLOON_BOMB)
  elseif poopVariant == 1 then -- red poop
    tear:ChangeVariant(TearVariant.BLOOD)
  elseif poopVariant == 2 then -- corny poop
    tear:ChangeVariant(TearVariant.BALLOON_BOMB)
    tear:AddTearFlags(TearFlags.TEAR_ECOLI)
  elseif poopVariant == 3 then -- gold poop
    tear:ChangeVariant(TearVariant.COIN)
  elseif poopVariant == 4 then -- rainbow poop
  tear:ChangeVariant(TearVariant.GODS_FLESH)
    local rnd = Const.rng:RandomInt(4)
    if rnd == 0 then
      tear:AddTearFlags(TearFlags.TEAR_SQUARE)
    elseif rnd == 1 then
      tear:AddTearFlags(TearFlags.TEAR_WIGGLE)
    elseif rnd == 2 then
      tear:AddTearFlags(TearFlags.TEAR_SPIRAL)
    elseif rnd == 3 then
      tear:AddTearFlags(TearFlags.TEAR_BIG_SPIRAL)
    end
  elseif poopVariant == 5 then -- black poop
    tear:ChangeVariant(TearVariant.NEEDLE)
    tear:AddTearFlags(TearFlags.TEAR_NEEDLE)
  elseif poopVariant == 6 then -- rainbow poop
    tear:AddTearFlags(TearFlags.TEAR_GLOW)
    tear:AddTearFlags(TearFlags.TEAR_HOMING)
  elseif poopVariant == 11 then -- charm poop
    tear:ChangeVariant(TearVariant.BALLOON_BOMB)
    tear:AddTearFlags(TearFlags.TEAR_CHARM)
  else -- gigantic poop
    tear:AddTearFlags(TearFlags.TEAR_PERSISTENT)
  end
  local playerData = PlayerUtils.GetPlayerData(player)

  playerData.tearOrbit:add(player, tear)
end

local laserSize = {
  [LaserVariant.LASER_NULL] = 0.15,
  [LaserVariant.THICK_RED] = 0.25,
  [LaserVariant.THIN_RED] = 0.15,
  [LaserVariant.SHOOP] = 0.25,
  [LaserVariant.PRIDE] = 0.25,
  [LaserVariant.LIGHT_BEAM] = 0.25,
  [LaserVariant.GIANT_RED] = 1,
  [LaserVariant.TRACTOR_BEAM] = 0.15,
  [LaserVariant.LIGHT_RING] = 0.25,
  [LaserVariant.BRIM_TECH] = 0.25,
  [LaserVariant.ELECTRIC] = 0.15,
  [LaserVariant.THICKER_RED] = 0.5,
  [LaserVariant.THICK_BROWN] = 0.25,
  [LaserVariant.BEAST] = 2,
  [LaserVariant.THICKER_BRIM_TECH] = 0.5,
  [LaserVariant.GIANT_BRIM_TECH] = 1,
}

---@param player EntityPlayer
---@param pos Vector
---@param vel Vector
---@param laserVariant number
function PlayerUtils.FireLaserTear(player, pos, vel, laserVariant)
  local amount = laserSize[laserVariant] or 0.15
  local fakeLaser = player:FireTear(
    pos,
    vel,
    false,
    true,
    true,
    player,
    amount
  )

  local playerData = PlayerUtils.GetPlayerData(player)
  fakeLaser:AddTearFlags(TearFlags.TEAR_LUDOVICO)
  fakeLaser.Scale = amount * 4
  local sprite = fakeLaser:GetSprite()
  sprite:Load("gfx/1000.113_brimstone ball.anm2", true)
  sprite:Play("Idle", true)
  sprite.Scale = Vector(0.8, 0.8) * math.min(amount, 1.1)
  local orb = playerData.tearOrbit:add(player, fakeLaser)
  orb.flags = orb.flags | Const.CustomFlags.TEAR_LUDOVICO | Const.CustomFlags.TEAR_TECH
  orb.variant = laserVariant
  return orb
end

local function roundToNearest45(angle)
  local normalized = angle % 360
  local rounded = math.floor((normalized + 22) / 45) * 45
  return rounded % 360
end

---@param player EntityPlayer
---@param orb Orbital<EntityOrbital>
---@param angle number
function PlayerUtils.FireLaserFromTear(player, orb, angle)
  local timeout = (orb.variant == LaserVariant.THIN_RED) and 1 or laserSize[orb.variant] * 40
  if orb.variant == LaserVariant.BEAST then
    angle = roundToNearest45(angle)
    local laser = EntityLaser.ShootAngle(
      orb.variant,
      orb.entity.Position,
      angle,
      timeout,
      Vector(0, 0),
      player
    )
    laser.DisableFollowParent = true
    orb.variant = LaserVariant.GIANT_BRIM_TECH
  end
  local laser = EntityLaser.ShootAngle(
    orb.variant,
    orb.entity.Position,
    angle,
    timeout,
    Vector(0, 0),
    player
  )
  laser.DisableFollowParent = true
  return laser
end

return PlayerUtils

---@type Store
local Store = require("thesun-src.Store")
---@type Const
local Const = require("thesun-src.Const")
---@type Utils
local Utils = include("thesun-src.Utils")
---@type ChargeBar
local ChargeBar = include("thesun-src.ChargeBar")
local Orbit = include("thesun-src.Orbit")
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
        act = 100,
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

return PlayerUtils

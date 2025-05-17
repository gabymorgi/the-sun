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

---@class PlayerUtils
---@field GetPlayerData fun(player: EntityPlayer): PlayerData
---@field HandleNewRoom fun(player: EntityPlayer)
---@field CachePlayerCollectibles fun(player: EntityPlayer)

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
      leadPencilCount = 0,
      friendlySpiderCount = 0,
      wizardRemainingFrames = 0,
      ludodivo = nil,
    }
  end
  return Store.PlayerData[playerHash]
end

---@param player EntityPlayer
function PlayerUtils.HandleNewRoom(player)
  local playerData = PlayerUtils.GetPlayerData(player)
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

---@param value number
---@param playerData PlayerData
local function changeMinRange(value, playerData)
  playerData.orbitRange.min = value and 100 or Const.GRID_SIZE
  playerData.orbitRange.act = Utils.Clamp(playerData.orbitRange.act, playerData.orbitRange.min, playerData.orbitRange.max)
end

---@param player EntityPlayer
function PlayerUtils.CachePlayerCollectibles(player)
  local playerData = PlayerUtils.GetPlayerData(player)
  local collectibles = {
    [CollectibleType.COLLECTIBLE_DR_FETUS] = changeMinRange,
    [CollectibleType.COLLECTIBLE_EPIC_FETUS] = changeMinRange,
    [CollectibleType.COLLECTIBLE_IPECAC] = changeMinRange,
    [CollectibleType.COLLECTIBLE_KIDNEY_STONE] = function(value)
      if value then
        playerData.activeBars[CollectibleType.COLLECTIBLE_KIDNEY_STONE] = ChargeBar:new(75)
      else
        playerData.activeBars[CollectibleType.COLLECTIBLE_KIDNEY_STONE] = nil
      end
    end,
    [CollectibleType.COLLECTIBLE_CURSED_EYE] = function(value)
      if value then
        playerData.activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE] = ChargeBar:new(5)
      else
        playerData.activeBars[CollectibleType.COLLECTIBLE_CURSED_EYE] = nil
      end
    end,
  }

  for collectibleType, handler in pairs(collectibles) do
    local hasItem = player:HasCollectible(collectibleType) and true or nil
    if hasItem ~= playerData.cacheCollectibles[collectibleType] then
      playerData.cacheCollectibles[collectibleType] = hasItem
      handler(hasItem)
    end
  end
end

return PlayerUtils

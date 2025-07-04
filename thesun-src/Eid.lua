---@type Utils
local Utils = include("thesun-src.utils")
---@type Const
local Const = include("thesun-src.Const")

if EID then
  local preDesc = {
    [Const.TheSunType] = "#{{Blank}} #{{TheSun}} ",
    [Const.PlutoType] = "#{{Blank}} #{{Pluto}} ",
  }

  local theSunIcon, plutoIcon = Sprite(), Sprite()
  theSunIcon:Load("gfx/ui/eid/eid_thesun_icons.anm2", true)
  plutoIcon:Load("gfx/ui/eid/eid_pluto_icons.anm2", true)

  EID:addIcon("TheSun", "TheSun", 0, 14, 12, 0, 0, theSunIcon)
  EID:addIcon("Pluto", "Pluto", 0, 14, 12, 0, 0, plutoIcon)
  EID:addBirthright(Const.TheSunType, "Enemy projectiles inherit all your tears' modifiers")
  EID:addBirthright(Const.PlutoType, "Wall projectiles become friendly")

  local synergyDesc = {
    -- items
    ["5.100." .. CollectibleType.COLLECTIBLE_20_20] = "+1 to wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_INNER_EYE] = "+2 to wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_MUTANT_SPIDER] = "+3 to wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_LOKIS_HORNS] = "Chance to extra wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_EYE_SORE] = "Chance to extra wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_LEAD_PENCIL] = "Cluster wall shot.",
    ["5.100." .. CollectibleType.COLLECTIBLE_MONSTROS_LUNG] = "Cluster wall shot.",
    ["5.100." .. CollectibleType.COLLECTIBLE_MOMS_EYE] = "Chance to extra wall bullet train.",
    ["5.100." .. CollectibleType.COLLECTIBLE_CHEMICAL_PEEL] = "Bonus applies to clockwise-absorbed projectiles.",
    ["5.100." .. CollectibleType.COLLECTIBLE_BLOOD_CLOT] = "Bonus applies to clockwise-absorbed projectiles.",
    ["5.100." .. CollectibleType.COLLECTIBLE_EPIC_FETUS] = "All orbiting tears explode when firing.",
    ["5.100." .. CollectibleType.COLLECTIBLE_DR_FETUS] = "Minimum orbit radius increased.#explosion countdown increased significantly.#bomb explode 1 sec after hitting an enemy",
    ["5.100." .. CollectibleType.COLLECTIBLE_CHOCOLATE_MILK] = "More orbiting tears = less damage.",
    ["5.100." .. CollectibleType.COLLECTIBLE_CURSED_EYE] = "Teleports when 1-4 orbiting tears.",
    ["5.100." .. CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE] = "Each absorbed tear briefly boosts damage.",
    ["5.100." .. CollectibleType.COLLECTIBLE_NEPTUNUS] = "Charges up when orbit is empty.",
    ["5.100." .. CollectibleType.COLLECTIBLE_SPIRIT_SWORD] = "x3 damage multiplier.",
    ["5.100." .. CollectibleType.COLLECTIBLE_THE_WIZ] = "Affects wall projectiles.",
    ["5.100." .. CollectibleType.COLLECTIBLE_TRACTOR_BEAM] = "Flatten orbit.",
    ["5.100." .. CollectibleType.COLLECTIBLE_PROPTOSIS] = "Damage is reduced at a much slower pace",
    ["5.100." .. CollectibleType.COLLECTIBLE_PSY_FLY] = "blocked projectiles are absorbed into orbit",
    ["5.100." .. CollectibleType.COLLECTIBLE_SULFUR] = "Do you dare to use it 16 times?",
    -- trinkets
    ["5.350." .. TrinketType.TRINKET_BRAIN_WORM] = "tears released towards nearby enemies.",
  }

  local function modifierCondition()
    if Utils.AnyoneHasOrbit() then return true end
  end

  local function modifierCallback(descObj)
    local playerType = Utils.AnyoneHasOrbit()
    if synergyDesc[descObj.fullItemString] and playerType then
      EID:appendToDescription(descObj, preDesc[playerType] .. synergyDesc[descObj.fullItemString])
    end
    return descObj
  end

  EID:addDescriptionModifier("theSunDesc", modifierCondition, modifierCallback)
end

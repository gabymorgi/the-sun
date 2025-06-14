local log = {}

local flags = {
  tearFlags = {
    [0] = "TEAR_NORMAL",
    "TEAR_SPECTRAL",
    "TEAR_PIERCING",
    "TEAR_HOMING",
    "TEAR_SLOW",
    "TEAR_POISON",
    "TEAR_FREEZE",
    "TEAR_SPLIT",
    "TEAR_GROW",
    "TEAR_BOOMERANG",
    "TEAR_PERSISTENT",
    "TEAR_WIGGLE",
    "TEAR_MULLIGAN",
    "TEAR_EXPLOSIVE",
    "TEAR_CHARM",
    "TEAR_CONFUSION",
    "TEAR_HP_DROP",
    "TEAR_ORBIT",
    "TEAR_WAIT",
    "TEAR_QUADSPLIT",
    "TEAR_BOUNCE",
    "TEAR_FEAR",
    "TEAR_SHRINK",
    "TEAR_BURN",
    "TEAR_ATTRACTOR",
    "TEAR_KNOCKBACK",
    "TEAR_PULSE",
    "TEAR_SPIRAL",
    "TEAR_FLAT",
    "TEAR_SAD_BOMB",
    "TEAR_BUTT_BOMB",
    "TEAR_SQUARE",
    "TEAR_GLOW",
    "TEAR_GISH",
    "TEAR_MYSTERIOUS_LIQUID_CREEP",
    "TEAR_SHIELDED",
    "TEAR_GLITTER_BOMB",
    "TEAR_SCATTER_BOMB",
    "TEAR_STICKY",
    "TEAR_CONTINUUM",
    "TEAR_LIGHT_FROM_HEAVEN",
    "TEAR_COIN_DROP",
    "TEAR_BLACK_HP_DROP",
    "TEAR_TRACTOR_BEAM",
    "TEAR_GODS_FLESH",
    "TEAR_GREED_COIN",
    "TEAR_CROSS_BOMB",
    "TEAR_BIG_SPIRAL",
    "TEAR_PERMANENT_CONFUSION",
    "TEAR_BOOGER",
    "TEAR_EGG",
    "TEAR_ACID",
    "TEAR_BONE",
    "TEAR_BELIAL",
    "TEAR_MIDAS",
    "TEAR_NEEDLE",
    "TEAR_JACOBS",
    "TEAR_HORN",
    "TEAR_LASER",
    "TEAR_POP",
    "TEAR_ABSORB",
    "TEAR_LASERSHOT",
    "TEAR_HYDROBOUNCE",
    "TEAR_BURSTSPLIT",
    "TEAR_CREEP_TRAIL",
    "TEAR_PUNCH",
    "TEAR_ICE",
    "TEAR_MAGNETIZE",
    "TEAR_BAIT",
    "TEAR_OCCULT",
    "TEAR_ORBIT_ADVANCED",
    "TEAR_ROCK",
    "TEAR_TURN_HORIZONTAL",
    "TEAR_BLOOD_BOMB",
    "TEAR_ECOLI",
    "TEAR_COIN_DROP_DEATH",
    "TEAR_BRIMSTONE_BOMB",
    "TEAR_RIFT",
    "TEAR_SPORE",
    "TEAR_GHOST_BOMB",
    "TEAR_CARD_DROP_DEATH",
    "TEAR_RUNE_DROP_DEATH",
    "TEAR_TELEPORT",
    "TEAR_DECELERATE",
    "TEAR_ACCELERATE",
    "TEAR_EFFECT_COUNT",
    "TEAR_BOUNCE_WALLSONLY",
    "TEAR_NO_GRID_DAMAGE",
    "TEAR_BACKSTAB",
    "TEAR_FETUS_SWORD",
    "TEAR_FETUS_BONE",
    "TEAR_FETUS_KNIFE",
    "TEAR_FETUS_TECHX",
    "TEAR_FETUS_TECH",
    "TEAR_FETUS_BRIMSTONE",
    "TEAR_FETUS_BOMBER",
    "TEAR_FETUS",
    "TEAR_REROLL_ROCK_WISP",
    "TEAR_MOM_STOMP_WISP",
    "TEAR_ENEMY_TO_WISP",
    "TEAR_REROLL_ENEMY",
    "TEAR_GIGA_BOMB",
    "TEAR_EXTRA_GORE",
    "TEAR_RAINBOW",
    "TEAR_DETONATE",
    "TEAR_CHAIN",
    "TEAR_DARK_MATTER",
    "TEAR_GOLDEN_BOMB",
    "TEAR_FAST_BOMB",
    "TEAR_LUDOVICO"
  },
  tearVariant = {
    [0] = "BLUE",
    "BLOOD",
    "TOOTH",
    "METALLIC",
    "BOBS_HEAD",
    "FIRE_MIND",
    "DARK_MATTER",
    "MYSTERIOUS",
    "SCHYTHE",
    "CHAOS_CARD",
    "LOST_CONTACT",
    "LUE",
    "LOOD",
    "NAIL",
    "PUPULA",
    "PUPULA_BLOOD",
    "GODS_FLESH",
    "GODS_FLESH_BLOOD",
    "DIAMOND",
    "EXPLOSIVO",
    "COIN",
    "ENSIONAL",
    "STONE",
    "NAIL_BLOOD",
    "GLAUCOMA",
    "GLAUCOMA_BLOOD",
    "BOOGER",
    "EGG",
    "RAZOR",
    "BONE",
    "BLACK_TOOTH",
    "NEEDLE",
    "BELIAL",
    "EYE",
    "EYE_BLOOD",
    "BALLOON",
    "HUNGRY",
    "BALLOON_BRIMSTONE",
    "BALLOON_BOMB",
    "FIST",
    "GRIDENT",
    "ICE",
    "ROCK",
    "KEY",
    "KEY_BLOOD",
    "ERASER",
    "FIRE",
    "SWORD_BEAM",
    "SPORE",
    "TECH_SWORD_BEAM",
    "FETUS"
  },
  effectVariant = {
    [0] = "EFFECT_NULL",
    "BOMB_EXPLOSION",
    "BLOOD_EXPLOSION",
    "FLY_EXPLOSION",
    "ROCK_PARTICLE",
    "BLOOD_PARTICLE",
    "DEVIL",
    "BLOOD_SPLAT",
    "LADDER",
    "ANGEL",
    "BLUE_FLAME",
    "BULLET_POOF",
    "TEAR_POOF_A",
    "TEAR_POOF_B",
    "RIPPLE_POOF",
    "POOF01",
    "POOF02",
    "POOF04",
    "BOMB_CRATER",
    "CRACK_THE_SKY",
    "SCYTHE_BREAK",
    "TINY_BUG",
    "CREEP_RED",
    "CREEP_GREEN",
    "CREEP_YELLOW",
    "CREEP_WHITE",
    "CREEP_BLACK",
    "WOOD_PARTICLE",
    "MONSTROS_TOOTH",
    "MOM_FOOT_STOMP",
    "TARGET",
    "ROCKET",
    "PLAYER_CREEP_LEMON_MISHAP",
    "TINY_FLY",
    "FART",
    "TOOTH_PARTICLE",
    "XRAY_WALL",
    "PLAYER_CREEP_HOLYWATER",
    "SPIDER_EXPLOSION",
    "HEAVEN_LIGHT_DOOR",
    "STARFLASH",
    "WATER_DROPLET",
    "BLOOD_GUSH",
    "POOP_EXPLOSION",
    "PLAYER_CREEP_WHITE",
    "PLAYER_CREEP_BLACK",
    "PLAYER_CREEP_RED",
    "TRINITY_SHIELD",
    "BATTERY",
    "HEART",
    "LASER_IMPACT",
    "HOT_BOMB_FIRE",
    "RED_CANDLE_FLAME",
    "PLAYER_CREEP_GREEN",
    "PLAYER_CREEP_HOLYWATER_TRAIL",
    "SPIKE",
    "CREEP_BROWN",
    "PULLING_EFFECT",
    "POOP_PARTICLE",
    "DUST_CLOUD",
    "BOOMERANG",
    "SHOCKWAVE",
    "ROCK_EXPLOSION",
    "WORM",
    "BEETLE",
    "WISP",
    "EMBER_PARTICLE",
    "SHOCKWAVE_DIRECTIONAL",
    "WALL_BUG",
    "BUTTERFLY",
    "BLOOD_DROP",
    "BRIMSTONE_SWIRL",
    "CRACKWAVE",
    "SHOCKWAVE_RANDOM",
    "ISAACS_CARPET",
    "BAR_PARTICLE",
    "DICE_FLOOR",
    "LARGE_BLOOD_EXPLOSION",
    "PLAYER_CREEP_LEMON_PARTY",
    "TEAR_POOF_SMALL",
    "TEAR_POOF_VERYSMALL",
    "FRIEND_BALL",
    "WOMB_TELEPORT",
    "SPEAR_OF_DESTINY",
    "EVIL_EYE",
    "DIAMOND_PARTICLE",
    "NAIL_PARTICLE",
    "FALLING_EMBER",
    "DARK_BALL_SMOKE_PARTICLE",
    "ULTRA_GREED_FOOTPRINT",
    "PLAYER_CREEP_PUDDLE_MILK",
    "MOMS_HAND",
    "PLAYER_CREEP_BLACKPOWDER",
    "PENTAGRAM_BLACKPOWDER",
    "CREEP_SLIPPERY_BROWN",
    "GOLD_PARTICLE",
    "HUSH_LASER",
    "IMPACT",
    "COIN_PARTICLE",
    "WATER_SPLASH",
    "HUSH_ASHES",
    "HUSH_LASER_UP",
    "BULLET_POOF_HUSH",
    "ULTRA_GREED_BLING",
    "FIREWORKS",
    "BROWN_CLOUD",
    "FART_RING",
    "BLACK_HOLE",
    "MR_ME",
    "DEATH_SKULL",
    "ENEMY_BRIMSTONE_SWIRL",
    "HAEMO_TRAIL",
    "HALLOWED_GROUND",
    "BRIMSTONE_BALL",
    "FORGOTTEN_CHAIN",
    "BROKEN_SHOVEL_SHADOW",
    "DIRT_PATCH",
    "FORGOTTEN_SOUL",
    "SMALL_ROCKET",
    "TIMER",
    "SPAWNER",
    "LIGHT",
    "BIG_HORN_HOLE_HELPER",
    "HALO",
    "TAR_BUBBLE",
    "BIG_HORN_HAND",
    "TECH_DOT",
    "MAMA_MEGA_EXPLOSION",
    "OPTION_LINE",
    "LEECH_EXPLOSION",
    "MAGGOT_EXPLOSION",
    "BIG_SPLASH",
    "WATER_RIPPLE",
    "PEDESTAL_RIPPLE",
    "RAIN_DROP",
    "GRID_ENTITY_PROJECTILE_HELPER",
    "WORMWOOD_HOLE",
    "MIST",
    "TRAPDOOR_COVER",
    "BACKDROP_DECORATION",
    "SMOKE_CLOUD",
    "WHIRLPOOL",
    "FARTWAVE",
    "ENEMY_GHOST",
    "ROCK_POOF",
    "DIRT_PILE",
    "FIRE_JET",
    "FIRE_WAVE",
    "BIG_ROCK_EXPLOSION",
    "BIG_CRACKWAVE",
    "BIG_ATTRACT",
    "HORNFEL_ROOM_CONTROLLER",
    "OCCULT_TARGET",
    "DOOR_OUTLINE",
    "CREEP_SLIPPERY_BROWN_GROWING",
    "TALL_LADDER",
    "WILLO_SPAWNER",
    "TADPOLE",
    "LIL_GHOST",
    "BISHOP_SHIELD",
    "PORTAL_TELEPORT",
    "HERETIC_PENTAGRAM",
    "CHAIN_GIB",
    "SIREN_RING",
    "CHARM_EFFECT",
    "SPRITE_TRAIL",
    "CHAIN_LIGHTNING",
    "COLOSTOMIA_PUDDLE",
    "CREEP_STATIC",
    "DOGMA_DEBRIS",
    "DOGMA_BLACKHOLE",
    "DOGMA_ORB",
    "CRACKED_ORB_POOF",
    "SHOP_SPIKES",
    "KINETI_BEAM",
    "CLEAVER_SLASH",
    "REVERSE_EXPLOSION",
    "URN_OF_SOULS",
    "ENEMY_SOUL",
    "RIFT",
    "LAVA_SPAWNER",
    "BIG_KNIFE",
    "MOTHER_SHOCKWAVE",
    "WORM_FRIEND_SNARE",
    "REDEMPTION",
    "HUNGRY_SOUL",
    "EXPLOSION_WAVE",
    "DIVINE_INTERVENTION",
    "PURGATORY",
    "MOTHER_TRACER",
    "PICKUP_GHOST",
    "FISSURE_SPAWNER",
    "ANIMA_CHAIN",
    "DARK_SNARE",
    "CREEP_LIQUID_POOP",
    "GROUND_GLOW",
    "DEAD_BIRD",
    "GENERIC_TRACER",
    "ULTRA_DEATH_SCYTHE"
  },
  damageFlags = {
    [0] = "DAMAGE_NOKILL",
    "DAMAGE_FIRE",
    "DAMAGE_EXPLOSION",
    "DAMAGE_LASER",
    "DAMAGE_ACID",
    "DAMAGE_RED_HEARTS",
    "DAMAGE_COUNTDOWN",
    "DAMAGE_SPIKES",
    "DAMAGE_CLONES",
    "DAMAGE_POOP",
    "DAMAGE_DEVIL",
    "DAMAGE_ISSAC_HEART",
    "DAMAGE_TNT",
    "DAMAGE_INVINCIBLE",
    "DAMAGE_SPAWN_FLY",
    "DAMAGE_POISON_BURN",
    "DAMAGE_CURSED_DOOR",
    "DAMAGE_TIMER",
    "DAMAGE_IV_BAG",
    "DAMAGE_PITFALL",
    "DAMAGE_CHEST",
    "DAMAGE_FAKE",
    "DAMAGE_BOOGER",
    "DAMAGE_SPAWN_BLACK_HEART",
    "DAMAGE_CRUSH",
    "DAMAGE_NO_MODIFIERS",
    "DAMAGE_SPAWN_RED_HEART",
    "DAMAGE_SPAWN_COIN",
    "DAMAGE_NO_PENALTIES",
    "DAMAGE_SPAWN_TEMP_HEART",
    "DAMAGE_IGNORE_ARMOR",
    "DAMAGE_SPAWN_CARD",
    "DAMAGE_SPAWN_RUNE",
  }
}

--- Devuelve los flags activos para un valor dado de BitSet128
--- @param type string
--- @param bitSet BitSet128 | any
--- @return string
function log.Flag(type, bitSet)
  local flagKey = type .. "Flags"
  local result = {}
  local map = flags[flagKey]
  if not map then
    return "Unknown"
  end

  if bitSet.l == 0 and bitSet.h == 0 then
    table.insert(result, map[0])
  end
  for i = 0, 63 do
    if bitSet.l & (1 << i) ~= 0 then
      table.insert(result, map[i + 1])
    end
  end
  for i = 64, 127 do
    if bitSet.h & (1 << (i - 64)) ~= 0 then
      table.insert(result, map[i + 1])
    end
  end

  return table.concat(result, ", ")
end

--- @param type string
--- @param enumValue number
--- @return string
function log.Enum(type, enumValue)
  local flagKey = type .. "Variant"
  local map = flags[flagKey]
  if not map then
    return "Unknown"
  end

  return map[enumValue] or "Unknown"
end

--- @param tbl table
--- @param indent? number
function log.Table(tbl, indent)
  indent = indent or 0
  local str = string.rep("  ", indent) .. "{\n"
  for k, v in pairs(tbl) do
    local kStr = tostring(k)
    local vStr = type(v) == "table" and log.Table(v, indent + 1) or tostring(v)
    str = str .. string.rep("  ", indent + 1) .. kStr .. " = " .. vStr .. ",\n"
  end
  str = str .. string.rep("  ", indent) .. "}"
  return str
end

--- @param tag string
--- @param value any
function log.Value(tag, value)
  if type(value) == "table" then
    Isaac.DebugString("the-sun " .. tag .. ": " .. log.Table(value))
  else
    Isaac.DebugString("the-sun " .. tag .. ": " .. tostring(value))
  end
end

return log

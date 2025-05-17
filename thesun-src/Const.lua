---@class Const
---@field TheSunType number
---@field HairCostume number
---@field RADIUS_STEP_MULTIPLIER number
---@field GRID_SIZE number
---@field game Game
---@field rng RNG
---@field HALF_PI number
---@field TWO_PI number
---@field FPS number

local Const = {}

Const.TheSunType = Isaac.GetPlayerTypeByName("TheSun", false)
Const.HairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2")
Const.RADIUS_STEP_MULTIPLIER = 3
Const.GRID_SIZE = 40
Const.game = Game()
Const.rng = RNG()
Const.HALF_PI = math.pi / 2
Const.TWO_PI = math.pi * 2
Const.FPS = 25

return Const
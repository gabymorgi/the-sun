local PI = math.pi
local BASE_OFFSET_X = 8 * PI
local AMPLITUDE_X = 8 * PI
local AMPLITUDE_Y = 20
local SPEED = 6

local function GetParametricPosition(t)
  local x = SPEED * t + BASE_OFFSET_X - AMPLITUDE_X * math.cos(t)
  local y = AMPLITUDE_Y * math.sin(t)
  return Vector(x, y)
end
local Utils = {}

--- @param playerPos Vector
--- @param proj Entity
--- @return number -1 = clockwise, 1 = counter-clockwise
function Utils.GetClockWiseSign(playerPos, proj)
  local toProj = (proj.Position - playerPos):Normalized()
  local velocity = proj.Velocity:Normalized()

  local sign = velocity.X * toProj.Y - velocity.Y * toProj.X
  if sign > 0 then
    return -1
  else
    return 1
  end
end

--- @param pos1 Vector
--- @param pos2 Vector
--- @return number
function Utils.GetAngle(pos1, pos2)
  return math.atan(pos2.Y - pos1.Y, pos2.X - pos1.X)
end

---@param value number
---@param min number
---@param max number
---@return number
function Utils.Clamp(value, min, max)
  return math.max(min, math.min(value, max))
end

Utils.colorOffsets = {
  Red = { colorOffset = { 0.61, -0.39, -0.39 }, rangeMultiplier = 1.38 },
  Yellow = { colorOffset = { 0.54, 0.61, -0.4 }, rangeMultiplier = 1.13 },
  Green = { colorOffset = { -0.4, 0.61, -0.26 }, rangeMultiplier = 0.88 },
  Cyan = { colorOffset = { -0.39, 0.4, 0.61 }, rangeMultiplier = 0.63 },
}

--- @param tear EntityTear
function Utils.GetColorOffset(tear)
  for color, values in pairs(Utils.colorOffsets) do
    if (
      math.abs(tear.Color.RO - values.colorOffset[1]) < 0.01 and
      math.abs(tear.Color.GO - values.colorOffset[2]) < 0.01 and
      math.abs(tear.Color.BO - values.colorOffset[3]) < 0.01
    ) then
      return color
    end
  end
  return nil
end

return Utils
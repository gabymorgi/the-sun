local log = {}

--- Returns active flags
--- @param bitSet BitSet128 | any
--- @return string
function log.Flag(bitSet)
  local result = {}

  local function extractBits(number, offset)
    for i = 0, 63 do
      if number & (1 << i) ~= 0 then
        table.insert(result, i + 1 + offset)
      end
    end
  end

  if type(bitSet) ~= "table" then
    if bitSet == 0 then
      table.insert(result, 0)
    else
      extractBits(bitSet, 0)
    end
  else
    if bitSet.l == 0 and bitSet.h == 0 then
      table.insert(result, 0)
    else
      extractBits(bitSet.l, 0)
      extractBits(bitSet.h, 64)
    end
  end

  return table.concat(result, ", ")
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

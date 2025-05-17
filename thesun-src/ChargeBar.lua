---@class ChargeBar
---@field maxCharge number
---@field charge number
---@field sprite Sprite
---@field get fun(self: ChargeBar): number
---@field set fun(self: ChargeBar, value: number): nil
---@field add fun(self: ChargeBar, delta: number): nil
---@field isFull fun(self: ChargeBar): boolean
---@field percent fun(self: ChargeBar): number
---@field render fun(self: ChargeBar, screenPos: Vector, isCharging: boolean): nil
---@field new fun(self: ChargeBar, maxCharge: number, spritePath: string?): ChargeBar
---@field __index ChargeBar

---@type ChargeBar
local ChargeBar = {}
ChargeBar.__index = ChargeBar

-- Crea una nueva barra; por defecto usa la animación de la UI vanilla
---@param maxCharge number
---@param spritePath string?
function ChargeBar:new(maxCharge, spritePath)
  local obj = setmetatable({
    maxCharge = maxCharge or 100,
    charge = 0,
    sprite = Sprite(),
  }, self)

  obj.sprite:Load(spritePath or "gfx/chargebar.anm2", true)

  return obj
end
---@return number
function ChargeBar:get()
  return self.charge
end
---@param value number
function ChargeBar:set(value)
  self.charge = math.min(value, self.maxCharge)
end
---@param delta number
function ChargeBar:add(delta)
  self:set(self.charge + delta)
end
function ChargeBar:isFull()
  return self.charge >= self.maxCharge
end
function ChargeBar:percent()
  return self.charge / self.maxCharge * 100
end

---@param screenPos Vector
---@param isCharging boolean
function ChargeBar:render(screenPos, isCharging)
  local p = self:percent()

  if isCharging then
    if p < 99 then
      self.sprite:SetFrame("Charging", math.floor(p))
    elseif not self.sprite:IsPlaying("Charged") then
      self.sprite:Play("Charged", true)
    end
  elseif not self.sprite:IsPlaying("Disappear") then
    self.sprite:Play("Disappear", true)
  end

  self.sprite:Render(screenPos, Vector.Zero, Vector.Zero)
  self.sprite:Update()
end

return ChargeBar

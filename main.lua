local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2") -- Exact path, with the "resources" folder as the root

local game = Game() -- We only need to get the game object once. It's good forever!
local rng = RNG()

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
    if player:GetPlayerType() ~= theSunType then
        return -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
    end

    player:AddNullCostume(hairCostume)
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.GiveCostumesOnInit)

-- -@param cacheFlag CacheFlag
---@param player EntityPlayer
function theSunMod:onEvaluateCacheFlight(player)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    player.CanFly = true
    
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFlight, CacheFlag.CACHE_FLYING)



--- @param player EntityPlayer
local function FireFromWall(player)
    local room = game:GetRoom()
    local shape = room:GetRoomShape()
    local roomPos = room:GetTopLeftPos()
    local roomSize = room:GetBottomRightPos() - roomPos

    logValue("Room Shape", shape)
    
    local wall = rng:RandomInt(4) -- 0=Top, 1=Bottom, 2=Left, 3=Right
    local spawnPos, velocity
    
    if wall == 0 then
        spawnPos = Vector(roomPos.X + roomSize.X / 2, roomPos.Y + 5)
        velocity = Vector(0, 8)
    elseif wall == 1 then
        spawnPos = Vector(roomPos.X + roomSize.X / 2, roomPos.Y + roomSize.Y - 5)
        velocity = Vector(0, -8)
    elseif wall == 2 then
        spawnPos = Vector(roomPos.X + 5, roomPos.Y + roomSize.Y / 2)
        velocity = Vector(8, 0)
    elseif wall == 3 then
        spawnPos = Vector(roomPos.X + roomSize.X - 5, roomPos.Y + roomSize.Y / 2)
        velocity = Vector(-8, 0)
    end

    local proj = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, 0, 0, spawnPos, velocity, player):ToProjectile()
    proj.FallingAccel = -0.1
    proj.Height = -10
end

function theSunMod:OnUpdate()
    for i = 0, Game():GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player:GetShootingInput():Length() > 0 then
            FireFromWall(player)
        end
    end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_UPDATE, theSunMod.OnUpdate)

--------------------------------------------------------------------------------------------------

local PLUTO_TYPE = Isaac.GetPlayerTypeByName("Pluto", true)
local HOLY_OUTBURST_ID = Isaac.GetItemIdByName("Holy Outburst")

---@param player EntityPlayer
function theSunMod:PlutoInit(player)
    if player:GetPlayerType() ~= PLUTO_TYPE then
        return
    end

    player:SetPocketActiveItem(HOLY_OUTBURST_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(HOLY_OUTBURST_ID)
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.PlutoInit)

function theSunMod:HolyOutburstUse(_, _, player)
    local spawnPos = player.Position

    local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER, 0, spawnPos, Vector.Zero, player):ToEffect()
    creep.Scale = 2
    creep:Update()

    return true
end

theSunMod:AddCallback(ModCallbacks.MC_USE_ITEM, theSunMod.HolyOutburstUse, HOLY_OUTBURST_ID)




--- @param tbl table
--- @param indent? number
function debugTable(tbl, indent)
    indent = indent or 0
    local str = string.rep("  ", indent) .. "{\n"
    for k, v in pairs(tbl) do
        local kStr = tostring(k)
        local vStr = type(v) == "table" and debugTable(v, indent + 1) or tostring(v)
        str = str .. string.rep("  ", indent + 1) .. kStr .. " = " .. vStr .. ",\n"
    end
    str = str .. string.rep("  ", indent) .. "}"
    return str
end

--- @param tag string
--- @param value any
function logValue(tag, value)
    if type(value) == "table" then
        Isaac.DebugString(tag .. ": " .. debugTable(value))
    else
        Isaac.DebugString(tag .. ": " .. tostring(value))
    end
end

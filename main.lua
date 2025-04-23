local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2") -- Exact path, with the "resources" folder as the root

local game = Game() -- We only need to get the game object once. It's good forever!
local rng = RNG()
local fireCooldown = 0
local orbitals = {} -- Lista de lágrimas absorbidas

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
    if player:GetPlayerType() ~= theSunType then
        return -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
    end

    player:AddNullCostume(hairCostume)
end
theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.GiveCostumesOnInit)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheRange(player)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    player.TearRange = player.TearRange / 2
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheRange, CacheFlag.CACHE_RANGE)

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFlight(player)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    player.CanFly = true
    
end
theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFlight, CacheFlag.CACHE_FLYING)

function HandleRoomEnter()
    local player = Isaac.GetPlayer(0)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    local room = game:GetRoom()
    local roomShape = room:GetRoomShape()
    local roomPos = room:GetTopLeftPos()
    local roomSize = room:GetBottomRightPos() - roomPos
    local type = room:GetType()

    logValue("RoomShape", roomShape)
    logValue("RoomType", room:GetType())
    logValue("RoomCenter", room:GetCenterPos())
    logValue("roomSize", roomSize)

    if roomShape == RoomShape.ROOMSHAPE_1x1 then
        local center = room:GetCenterPos()
        -- Isaac.Spawn(809, 0, 0, Vector(center.X, center.Y - 96), Vector(0, 0), player)
    end
end
-- theSunMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HandleRoomEnter)

--- @param player EntityPlayer
function FireFromWall(player)
    local room = game:GetRoom()
    local roomPos = room:GetTopLeftPos()
    local roomSize = room:GetBottomRightPos() - roomPos

    local wall = rng:RandomInt(4) -- 0=Top, 1=Bottom, 2=Left, 3=Right
    local spawnPos, velocity

    if wall == 0 then -- top
        local x = rng:RandomFloat() * roomSize.X + roomPos.X
        spawnPos = Vector(x, roomPos.Y + 1)
        velocity = Vector(0, 4)
    elseif wall == 1 then -- bottom
        local x = rng:RandomFloat() * roomSize.X + roomPos.X
        spawnPos = Vector(x, roomPos.Y + roomSize.Y - 1)
        velocity = Vector(0, -4)
    elseif wall == 2 then -- left
        local y = rng:RandomFloat() * roomSize.Y + roomPos.Y
        spawnPos = Vector(roomPos.X + 1, y)
        velocity = Vector(4, 0)
    elseif wall == 3 then -- right
        local y = rng:RandomFloat() * roomSize.Y + roomPos.Y
        spawnPos = Vector(roomPos.X + roomSize.X - 1, y)
        velocity = Vector(-4, 0)
    end

    local proj = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, 0, 0, spawnPos, velocity, player):ToProjectile()
    -- ProjectileFlags.CANT_HIT_PLAYER
    proj.ProjectileFlags = proj.ProjectileFlags | ProjectileFlags.GHOST | ProjectileFlags.CANT_HIT_PLAYER
    -- proj.ChangeTimeout(60)
    proj.FallingAccel = -0.1
    proj.Height = -10
end

--- @param playerPos Vector
--- @param proj EntityProjectile
local function IsProjectileBehindPlayer(playerPos, proj)
    local toProj = (proj.Position - playerPos):Normalized()
    local velocity = proj.Velocity:Normalized()

    local infoToLog = {
        playerPos = playerPos,
        projPos = proj.Position,
        toProj = toProj,
        velocity = velocity,
        dotProduct = velocity:Dot(toProj),
    }

    -- 0 = side, 1 = back, -1 = front
    return velocity:Dot(toProj) > 0.5
end

--- @param player EntityPlayer
function TryAbsorbTears(player)
    local input = player:GetShootingInput()
    if input:Length() == 0 then return end

    local radius = player.TearRange
    local nearby = Isaac.FindInRadius(player.Position, player.TearRange, EntityPartition.BULLET)
    for _, ent in ipairs(nearby) do
        local proj = ent:ToProjectile()
        if proj and IsProjectileBehindPlayer(player.Position, proj) then
            table.insert(orbitals, proj)
            proj:Remove() -- Eliminamos el proyectil para evitar daño
        end
    end
end

function theSunMod:OnUpdate()
    for i = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(i)
        if player:GetPlayerType() ~= theSunType then
            goto continue -- Skip to the next iteration of the loop if the player is not The Sun.
        end
        local room = game:GetRoom()

        -- if not room:IsClear() then -- TOMOD
        if room:IsClear() then
            fireCooldown = fireCooldown + 1
            -- local fireRate = math.max(10, math.floor(30 / (player.FireDelay + 1)))

            -- if fireCooldown > player.MaxFireDelay then -- TOMOD
            if fireCooldown > 60 then
                FireFromWall(player)
                fireCooldown = 0
            end
        else
            fireCooldown = 0 -- reset si se limpia la sala
        end

        if player:GetShootingInput():Length() > 0 then
            TryAbsorbTears(player)
        end
        ::continue::
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
        Isaac.DebugString("the-sun " .. tag .. ": " .. debugTable(value))
    else
        Isaac.DebugString("the-sun " .. tag .. ": " .. tostring(value))
    end
end

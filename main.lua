local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2") -- Exact path, with the "resources" folder as the root

local game = Game() -- We only need to get the game object once. It's good forever!
local rng = RNG()
local fireCooldown = 0
--- @type { [number]: { tear: EntityTear, direction: number, radius: number, angle: number } }
local orbitingTears = {}
local orbitingTearsCount = 0
local MIN_ORBITING_RADIUS = 10
local orbitingRadius = MIN_ORBITING_RADIUS
local MAX_ORBITING_TEARS = 1
local RADIUS_STEP_MULTIPLIER = 2
local ANGLE_STEP_MULTIPLIER = 0.1

---@param player EntityPlayer
---@return boolean
local function IsTheSun(player)
    if (player:GetPlayerType() == theSunType) then
        return true
    end
    return false
end

---@param players EntityPlayer[]
---@return boolean
local function SomePlayerWithOrbital(players)
    for _, player in pairs(players) do
        if player:GetPlayerType() == theSunType then
            return true
        end
    end
    return false
end

-- for _,player in pairs(GetPlayers()) do
--- @return EntityPlayer[]
local function GetPlayers()
    local players = {}
    for i = 0, game:GetNumPlayers() - 1 do
        local player = Game():GetPlayer(i)
        -- index = player.GetCollectibleRNG(CollectibleType.COLLECTIBLE_SAD_ONION)
        players[i] = player
    end
    return players
end

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
    if not IsTheSun(player) then
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

local function HandleRoomEnter()
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
local function FireFromWall(player)
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
    -- proj.CollisionDamage = player.Damage
    proj.Size = player.Damage
end

--- @param playerPos Vector
--- @param proj EntityProjectile
local function IsProjectileBehindPlayer(playerPos, proj)
    local toProj = (proj.Position - playerPos):Normalized()
    local velocity = proj.Velocity:Normalized()

    -- 0 = side, 1 = back, -1 = front
    return velocity:Dot(toProj) > 0.5
end

--- @param playerPos Vector
--- @param proj EntityProjectile
--- @return number
--- -1 = clockwise, 1 = counter-clockwise
local function GetClockWiseSign(playerPos, proj)
    local toProj = (proj.Position - playerPos):Normalized()
    local velocity = proj.Velocity:Normalized()

    -- negative = clockwise, positive = counter-clockwise
    local sign = velocity.X * toProj.Y - velocity.Y * toProj.X
    if sign > 0 then
        return -1 -- counter-clockwise
    else
        return 1 -- clockwise
    end
end

--- @param player EntityPlayer
local function TryAbsorbTears(player)
    local input = player:GetShootingInput()
    if input:Length() == 0 then return end

    local radius = player.TearRange
    local nearby = Isaac.FindInRadius(player.Position, player.TearRange, EntityPartition.BULLET)
    for _, ent in ipairs(nearby) do
        local proj = ent:ToProjectile()
        if proj and IsProjectileBehindPlayer(player.Position, proj) then
            logValue("orbitingTears", #orbitingTears)
            if orbitingTearsCount > MAX_ORBITING_TEARS then
                proj:Remove()
                return
            end
            local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, 0, 0, proj.Position, Vector.Zero, player):ToTear()
            tear.CollisionDamage = 50 -- proj.CollisionDamage * 5
            proj:Remove() -- Eliminamos el proyectil para evitar daño
            if tear == nil then return end
            tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
            tear.FallingAcceleration = -0.1
            tear.Height = -10
            tear.Scale = player.Damage
            orbitingTears[GetPtrHash(tear)] = {
                tear = tear,
                direction = GetClockWiseSign(player.Position, proj),
                radius = (tear.Position - player.Position):Length(),
                angle = math.atan(tear.Position.Y - player.Position.Y, tear.Position.X - player.Position.X),
            }
            orbitingTearsCount = orbitingTearsCount + 1
        end
    end
end

local function UpdateOrbitingTears(player)
    local shotSpeed = player.ShotSpeed
    local maxRadius = orbitingRadius
    local center = player.Position + player.Velocity * 0.5

    for hash, orb in pairs(orbitingTears) do
        local tear = orb.tear
        if not (tear and tear:Exists() and not tear:IsDead()) then
            logValue("Removing tear", hash)
            orbitingTears[hash] = nil
            orbitingTearsCount = orbitingTearsCount - 1
        else
            if orb.radius < maxRadius then
                orb.radius = orb.radius + shotSpeed * RADIUS_STEP_MULTIPLIER
            end
            if orb.radius > maxRadius then
                orb.radius = maxRadius
            end
            orb.angle = orb.angle + orb.direction * shotSpeed * ANGLE_STEP_MULTIPLIER
            local offset = Vector(math.cos(orb.angle), math.sin(orb.angle)) * orb.radius
            tear.Position = center + offset
            tear.Velocity = Vector.Zero
        end
    end
end

function theSunMod:OnUpdate()
    local players = GetPlayers()

    if SomePlayerWithOrbital(players) then
        local room = game:GetRoom()
        -- if not room:IsClear() then -- TOMOD
        if true then
            fireCooldown = fireCooldown + 1
            -- local fireRate = math.max(10, math.floor(30 / (player.FireDelay + 1)))

            -- TODO: select the correct player
            if fireCooldown > players[0].MaxFireDelay then
                FireFromWall(players[0])
                fireCooldown = 0
            end
        else
            fireCooldown = 0 -- reset si se limpia la sala
        end
    end
    for _,player in pairs(players) do
        if not IsTheSun(player) then
            goto continue -- Skip to the next iteration of the loop if the player is not The Sun.
        end

        if player:GetShootingInput():Length() > 0 then
            TryAbsorbTears(player)
            if (orbitingRadius < player.TearRange) then
                orbitingRadius = orbitingRadius + RADIUS_STEP_MULTIPLIER
            end
        else
            if (orbitingRadius > MIN_ORBITING_RADIUS) then
                orbitingRadius = orbitingRadius - RADIUS_STEP_MULTIPLIER
            end
        end

        UpdateOrbitingTears(player)
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

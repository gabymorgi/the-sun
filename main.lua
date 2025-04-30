local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2") -- Exact path, with the "resources" folder as the root

local game = Game() -- We only need to get the game object once. It's good forever!
local rng = RNG()
local fireCooldown = 0
--- @type { [number]: { tear: EntityTear | EntityProjectile, direction: number, radius: number, angle: number, time: number } }
local orbitingTears = {}
local orbitingTearsCount = 0
local MIN_ORBITING_RADIUS = 40
local orbitingRadius = MIN_ORBITING_RADIUS
local MAX_ORBITING_TEARS = 60
local MAX_ORBITING_PROJ = MAX_ORBITING_TEARS * 2
local RADIUS_STEP_MULTIPLIER = 2
local VELOCITY_MULTIPLIER = 1
local PROJECTILE_SPAWN_OFFSET = 40

local roomMultiplier = {
    [RoomShape.ROOMSHAPE_1x1] = 1,
    [RoomShape.ROOMSHAPE_IH] = 0.8,
    [RoomShape.ROOMSHAPE_IV] = 0.8,
    [RoomShape.ROOMSHAPE_1x2] = 1.4,
    [RoomShape.ROOMSHAPE_IIV] = 1.2,
    [RoomShape.ROOMSHAPE_2x1] = 1.4,
    [RoomShape.ROOMSHAPE_IIH] = 1.2,
    [RoomShape.ROOMSHAPE_2x2] = 2,
    [RoomShape.ROOMSHAPE_LTL] = 1.7,
    [RoomShape.ROOMSHAPE_LTR] = 1.7,
    [RoomShape.ROOMSHAPE_LBL] = 1.7,
    [RoomShape.ROOMSHAPE_LBR] = 1.7,
}
local roomFireDelay = 10

---@param player EntityPlayer
local function calculateRoomFireDelay(player)
    local room = game:GetRoom()
    local roomShape = room:GetType()

    roomFireDelay = player.MaxFireDelay * (roomMultiplier[roomShape] or 1)
    -- LogValue("roomFireDelay", roomFireDelay)
end

---@param maxFireDelay number
---@return number
local function GetMaxOrbitingTears(maxFireDelay)
    local maxTears = math.floor(maxFireDelay / 2) -- 2 is the number of frames between each tear
    if maxTears > MAX_ORBITING_TEARS then
        return MAX_ORBITING_TEARS
    end
    return maxTears
end

---@param damage number
---@return number
local function GetProjectileScale(damage)
    return 0.046 * damage + 0.854
end

---@param damage number
---@return number
local function GetProjectileSize(damage)
    return 0.322 * damage + 5.979
end

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

    player.TearRange = player.TearRange / 3
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

---@param player EntityPlayer
function theSunMod:onEvaluateCacheFireDelay(player)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    calculateRoomFireDelay(player)
end

theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCacheFireDelay, CacheFlag.CACHE_FIREDELAY)

local function HandleRoomEnter()
    local player = Isaac.GetPlayer(0)
    if player:GetPlayerType() ~= theSunType then
        return
    end

    calculateRoomFireDelay(player)
end
theSunMod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HandleRoomEnter)

---@param tear EntityTear
---@param collider Entity
function theSunMod:OnTearCollision(tear, collider)
    LogValue("tear colllision", tear.Type)
    if collider:ToNPC() then
        orbitingTears[GetPtrHash(tear)] = nil
        orbitingTearsCount = orbitingTearsCount - 1
    end
end

theSunMod:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, theSunMod.OnTearCollision)

--- @param player EntityPlayer
local function FireFromWall(player)
    local room = game:GetRoom()
    local roomPos = room:GetTopLeftPos()
    local roomSize = room:GetBottomRightPos() - roomPos

    local wall = rng:RandomInt(4) -- 0=Top, 1=Bottom, 2=Left, 3=Right
    local spawnPos, velocity

    if wall == 0 then -- top
        local x = rng:RandomFloat() * roomSize.X + roomPos.X
        spawnPos = Vector(x, roomPos.Y - PROJECTILE_SPAWN_OFFSET)
        velocity = Vector(0, 4)
    elseif wall == 1 then -- bottom
        local x = rng:RandomFloat() * roomSize.X + roomPos.X
        spawnPos = Vector(x, roomPos.Y + roomSize.Y + PROJECTILE_SPAWN_OFFSET)
        velocity = Vector(0, -4)
    elseif wall == 2 then -- left
        local y = rng:RandomFloat() * roomSize.Y + roomPos.Y
        spawnPos = Vector(roomPos.X - PROJECTILE_SPAWN_OFFSET, y)
        velocity = Vector(4, 0)
    elseif wall == 3 then -- right
        local y = rng:RandomFloat() * roomSize.Y + roomPos.Y
        spawnPos = Vector(roomPos.X + roomSize.X + PROJECTILE_SPAWN_OFFSET, y)
        velocity = Vector(-4, 0)
    end

    --ProjectileVariant.PROJECTILE_TEAR
    local proj = Isaac.Spawn(EntityType.ENTITY_PROJECTILE, ProjectileVariant.PROJECTILE_RING, 0, spawnPos, velocity,
    player):ToProjectile()
    proj:GetData().isTheSunProjectile = true
    proj.ProjectileFlags = proj.ProjectileFlags | ProjectileFlags.GHOST | ProjectileFlags.CANT_HIT_PLAYER
    proj.FallingAccel = -0.1
    proj.FallingSpeed = 0.01
    -- proj.CollisionDamage = player.Damage
    -- proj.Size = 3 --GetProjectileSize(player.Damage)
    -- proj.Scale = 3 --GetProjectileScale(player.Damage)
end

--- @param playerPos Vector
--- @param proj EntityProjectile
local function IsProjectileBehindPlayer(playerPos, proj)
    local toProj = (proj.Position - playerPos):Normalized()
    local velocity = proj.Velocity:Normalized()

    -- 0 = side, 1 = back, -1 = front
    return velocity:Dot(toProj) > 0.1
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
    local nearby = Isaac.FindInRadius(player.Position, 80, EntityPartition.BULLET)
    for _, ent in ipairs(nearby) do
        local proj = ent:ToProjectile()
        if proj and not orbitingTears[GetPtrHash(proj)] and IsProjectileBehindPlayer(player.Position, proj) then
            if (proj:GetData().isTheSunProjectile) then
                if orbitingTearsCount > MAX_ORBITING_TEARS then
                    proj:Remove()
                    return
                end
                local tear = player:FireTear(proj.Position, Vector.Zero, true, true, true)
                proj:Remove() -- Eliminamos el proyectil para evitar daño
                -- LogEnum("tearVariant", tear.Variant)
                -- LogFlag("tearFlags", tear.TearFlags)
                if tear == nil then return end
                tear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
                tear.FallingAcceleration = -0.1
                tear.FallingSpeed = 0
                tear.Height = -10
                orbitingTears[GetPtrHash(tear)] = {
                    tear = tear,
                    direction = GetClockWiseSign(player.Position, proj),
                    radius = (tear.Position - player.Position):Length(),
                    angle = math.atan(tear.Position.Y - player.Position.Y, tear.Position.X - player.Position.X),
                    time = 0,
                }
                orbitingTearsCount = orbitingTearsCount + 1
                return -- No absorvemos los proyectiles que ya son nuestros
            else
                if orbitingTearsCount > MAX_ORBITING_PROJ then
                    return
                end
                proj:AddProjectileFlags(ProjectileFlags.HIT_ENEMIES | ProjectileFlags.CANT_HIT_PLAYER)
                -- proj.FallingAcceleration = -0.1
                orbitingTears[GetPtrHash(proj)] = {
                    tear = proj,
                    direction = GetClockWiseSign(player.Position, proj),
                    radius = (proj.Position - player.Position):Length(),
                    angle = math.atan(proj.Position.Y - player.Position.Y, proj.Position.X - player.Position.X),
                    time = 0,
                }
                proj.FallingAccel = -0.1
                proj.FallingSpeed = 0
                -- proj.Velocity = Vector.Zero
                -- proj.Height = -50
                orbitingTearsCount = orbitingTearsCount + 1
            end

        end
    end
end

local function UpdateOrbitingTears(player)
    for hash, orb in pairs(orbitingTears) do
        local tear = orb.tear
        orb.time = orb.time + 1

        if not (tear and tear:Exists() and not tear:IsDead()) then
            orbitingTears[hash] = nil
            orbitingTearsCount = orbitingTearsCount - 1
        elseif orb.time > 120 then
            if orb.tear.Type == EntityType.ENTITY_TEAR then
                -- orb.tear.FallingAcceleration = 0.01
                orb.tear.FallingSpeed = 0.3
                -- orb.tear.Velocity = Vector(orb.tear.Velocity.X * 1.9, orb.tear.Velocity.Y * 1.9)
            else
                orb.tear.FallingAccel = 0.1
                tear.FallingSpeed = 1
            end
        else
            if orb.radius < orbitingRadius then
                orb.radius = orb.radius + player.ShotSpeed * RADIUS_STEP_MULTIPLIER
            end
            if orb.radius > orbitingRadius then
                orb.radius = orbitingRadius
            end
            local vel = (player.ShotSpeed * VELOCITY_MULTIPLIER) / math.sqrt(orb.radius)
            orb.angle = orb.angle + orb.direction * vel
            local offset = Vector(math.cos(orb.angle), math.sin(orb.angle)) * orb.radius
            tear.Position = player.Position + offset
            local tangentAngle = orb.angle + orb.direction * (math.pi / 2)
            -- tear orientation
            tear.Velocity = Vector(math.cos(tangentAngle), math.sin(tangentAngle)) * vel * 60
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
            if fireCooldown > roomFireDelay then
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

        -- TryAbsorbTears(player)
        if player:GetShootingInput():Length() > 0 then
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


--- Tabla de flags de ejemplo
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
        "TEAR_EFFECT_COUNT"
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
    }
}

--- Devuelve los flags activos para un valor dado de BitSet128
--- @param flagKey string
--- @param bitSet BitSet128 | any
function LogFlag(flagKey, bitSet)
    local result = {}
    local map = flags[flagKey]
    if not map then
        LogValue("logFlag", "No se encontró la clave de bandera: " .. flagKey)
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

    LogValue(flagKey, table.concat(result, ", "))
end

--- @param flagKey string
--- @param enumValue number
function LogEnum(flagKey, enumValue)
    local map = flags[flagKey]
    if not map then
        LogValue("logEnum", "No se encontró la clave del enum: " .. flagKey)
    end

    LogValue(flagKey, map[enumValue])
end

--- @param tbl table
--- @param indent? number
function LogTable(tbl, indent)
    indent = indent or 0
    local str = string.rep("  ", indent) .. "{\n"
    for k, v in pairs(tbl) do
        local kStr = tostring(k)
        local vStr = type(v) == "table" and LogTable(v, indent + 1) or tostring(v)
        str = str .. string.rep("  ", indent + 1) .. kStr .. " = " .. vStr .. ",\n"
    end
    str = str .. string.rep("  ", indent) .. "}"
    return str
end

--- @param tag string
--- @param value any
function LogValue(tag, value)
    if type(value) == "table" then
        Isaac.DebugString("the-sun " .. tag .. ": " .. LogTable(value))
    else
        Isaac.DebugString("the-sun " .. tag .. ": " .. tostring(value))
    end
end

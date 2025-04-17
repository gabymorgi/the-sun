local theSunMod = RegisterMod("The Sun Character Mod", 1)

local theSunType = Isaac.GetPlayerTypeByName("TheSun", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/thesun_hair.anm2") -- Exact path, with the "resources" folder as the root

---@param player EntityPlayer
function theSunMod:GiveCostumesOnInit(player)
    if player:GetPlayerType() ~= theSunType then
        return -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
    end

    player:AddNullCostume(hairCostume)
    print("The Sun has been initialized!")
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, theSunMod.GiveCostumesOnInit)

---@param player EntityPlayer
---@param cacheFlag CacheFlag
function theSunMod:onEvaluateCache(player, cacheFlag)
    if player:GetPlayerType() == theSunType then
        if cacheFlag == CacheFlag.CACHE_FLYING then
            player.CanFly = true
        end
    end
end

theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.onEvaluateCache)

--------------------------------------------------------------------------------------------------


local game = Game() -- We only need to get the game object once. It's good forever!
local DAMAGE_REDUCTION = 0.6
function theSunMod:HandleStartingStats(player, flag)
    if player:GetPlayerType() ~= theSunType then
        return -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
    end

    if flag == CacheFlag.CACHE_DAMAGE then
        -- Every time the game reevaluates how much damage the player should have, it will reduce the player's damage by DAMAGE_REDUCTION, which is 0.6
        player.Damage = player.Damage - DAMAGE_REDUCTION
    end
end

theSunMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, theSunMod.HandleStartingStats)

function theSunMod:HandleHolyWaterTrail(player)
    if player:GetPlayerType() ~= theSunType then
        return -- End the function early. The below code doesn't run, as long as the player isn't The Sun.
    end

    -- Every 4 frames. The percentage sign is the modulo operator, which returns the remainder of a division operation!
    -- if game:GetFrameCount() % 4 == 0 then
    --     -- Vector.Zero is the same as Vector(0, 0). It is a constant!
    --     local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL, 0, player.Position, Vector.Zero, player):ToEffect()
    --     creep.SpriteScale = Vector(0.5, 0.5) -- Make it smaller!
    --     creep:Update() -- Update it to get rid of the initial red animation that lasts a single frame.
    -- end
end

theSunMod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, theSunMod.HandleHolyWaterTrail)

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

theSunMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, MyCharacterMod.PlutoInit)

function MyCharacterMod:HolyOutburstUse(_, _, player)
    local spawnPos = player.Position

    local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER, 0, spawnPos, Vector.Zero, player):ToEffect()
    creep.Scale = 2
    creep:Update()

    return true
end

MyCharacterMod:AddCallback(ModCallbacks.MC_USE_ITEM, MyCharacterMod.HolyOutburstUse, HOLY_OUTBURST_ID)
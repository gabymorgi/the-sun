
--[[ to disallow player to shoot
content/players.xml
set canShoot to false
<player name="TheSun" id="0" canShoot="false" variant="0" type="0" skin="0" />

-- to check if player is shooting, on post update:
local ShootingInput = player:GetShootingInput()
				local IsInput = false
				if ShootingInput.X ~= 0 or ShootingInput.Y ~= 0 then
					IsInput = true
				end
				if IsInput == true then

-- mei functin to check if player is shooting
	local function IsPlayerFiring( player )
		return player:GetLastActionTriggers() & ActionTriggers.ACTIONTRIGGER_SHOOTING ~= 0
	end
  	local function IsPlayerInputFiring( player )
		return player:GetShootingInput():Length() ~= 0
	end


-- to collect tear in range

for i,projectile in pairs(Isaac.FindInRadius(player.Position,Moses.birthrightMaxDistance,EntityPartition.BULLET)) do
	if math.abs(((projectile.Position - player.Position):Rotated(-repulsevector:GetAngleDegrees() + 180):GetAngleDegrees()%360)-180) < Moses.birthrightConeAngle then
		projectile:ToProjectile().ProjectileFlags = projectile:ToProjectile().ProjectileFlags | ProjectileFlags.HIT_ENEMIES |  	ProjectileFlags.CANT_HIT_PLAYER
		projectile.Velocity = (projectile.Position - player.Position ):Resized(player.ShotSpeed * 10)
	end
end


-- to spawn grimaces on room

local center = Game():GetRoom():GetCenterPos()
local shape = Game():GetRoom():GetRoomShape()
if shape == RoomShape.ROOMSHAPE_1x1 then Isaac.Spawn(809, 0, 0, Vector(center.X, center.Y - 96), Vector(0,0), p) end

--]]


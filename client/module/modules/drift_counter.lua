Modules.DriftCounter = {}
Modules.DriftCounter.IsDrifting = false
Modules.DriftCounter.CurrentPoints = 15487
Modules.DriftCounter.CurrentAngle = 0 -- Only refreshed when the player is drifting
Modules.DriftCounter.ChainCooldown = ConfigShared.DriftChainTime
Modules.DriftCounter.ChainLoopStarted = false
Modules.DriftCounter.ChainTimeLeft = ConfigShared.DriftChainTime
Modules.DriftCounter.GlobalAlpha = 255
Modules.DriftCounter.InAnimation = false



-- Source: https://github.com/Blumlaut/FiveM-DriftCounter/blob/master/driftcounter_c.lua
-- Lot of math stuff i don't understand, thanks Blumlaut
function Modules.DriftCounter.GetCurrentAngle()
    if Modules.Player.IsPedInAnyVehicle() then
        local veh = Modules.Player.GetCurrentVehicle()
        local vx,vy,_ = table.unpack(GetEntityVelocity(veh))
        local modV = math.sqrt(vx*vx + vy*vy)


        local _,_,rz = table.unpack(GetEntityRotation(veh,0))
        local sn,cs = -math.sin(math.rad(rz)), math.cos(math.rad(rz))

        if GetEntitySpeed(veh)* 3.6 < 25 or GetVehicleCurrentGear(veh) == 0 then return 0,modV end --speed over 25 km/h

        local cosX = (sn*vx + cs*vy)/modV
        return math.deg(math.acos(cosX))*0.5, modV
    else
        return 0
    end
end

function Modules.DriftCounter.IsPlayerDrifting()
    if Modules.Player.IsPedInAnyVehicle() then
        local pVeh = Modules.Player.GetCurrentVehicle()
        if GetEntityHeightAboveGround(pVeh) <= 1.5 then
            if Modules.Player.GetPed() == GetPedInVehicleSeat(pVeh, -1) then
                Modules.DriftCounter.CurrentAngle = Modules.DriftCounter.GetCurrentAngle()
                if Modules.DriftCounter.CurrentAngle > 10 then
                    return true
                else
                    return false
                end
            else
                return false
            end
        else
            return false
        end
    else
        return false
    end
end

function Modules.DriftCounter.StartChainBreakLoop()
    if not Modules.DriftCounter.ChainLoopStarted then
        Modules.DriftCounter.ChainLoopStarted = true
        Modules.DriftCounter.FadeInHud()
        Citizen.CreateThread(function()
            Modules.Utils.RealWait(Modules.DriftCounter.ChainCooldown, function(cb, timeLeft)
                Modules.DriftCounter.ChainTimeLeft = timeLeft - (timeLeft * 2) -- Duh
                if Modules.DriftCounter.IsDrifting then
                    cb(false, ConfigShared.DriftChainTime)
                end
            end)
            Modules.DriftCounter.FadeOutHud()
            --TODO: Submit point to API
            Modules.DriftCounter.ChainCooldown = ConfigShared.DriftChainTime
            Modules.DriftCounter.ChainLoopStarted = false
            Modules.DriftCounter.CurrentPoints = 0
            Modules.DriftCounter.CurrentAngle = 0
            Modules.DriftCounter.ChainTimeLeft = 0
        end)
    end
end

function Modules.DriftCounter.FadeInHud()
    Citizen.CreateThread(function()
        Modules.DriftCounter.InAnimation = true
        while Modules.DriftCounter.GlobalAlpha < 255 do
            Modules.DriftCounter.GlobalAlpha = Modules.DriftCounter.GlobalAlpha + (0.5 * Modules.Utils.TimeFrame)
            Wait(0)
        end
        Modules.DriftCounter.InAnimation = false
        Modules.DriftCounter.GlobalAlpha = 255
    end)
end

function Modules.DriftCounter.FadeOutHud()
    Citizen.CreateThread(function()
        Modules.DriftCounter.InAnimation = true
        while Modules.DriftCounter.GlobalAlpha > 0 do
            Modules.DriftCounter.GlobalAlpha = Modules.DriftCounter.GlobalAlpha - (0.5 * Modules.Utils.TimeFrame)
            Wait(0)
        end
        Modules.DriftCounter.InAnimation = false
        Modules.DriftCounter.GlobalAlpha = 0
    end)
end

Citizen.CreateThread(function()
    while true do
        if Modules.DriftCounter.IsPlayerDrifting() then
            Modules.DriftCounter.IsDrifting = true
            Modules.DriftCounter.StartChainBreakLoop()
            if Modules.DriftCounter.CurrentAngle > 10 then
                if ConfigShared.AddPointBasedOnAngle then
                    Modules.DriftCounter.CurrentPoints = math.floor(Modules.DriftCounter.CurrentPoints + (Modules.DriftCounter.CurrentAngle / 100) * Modules.Utils.TimeFrame) -- This fix the issue where player with low fps would get less point then player with high fps count.
                end

                if ConfigShared.AddStaticPointOnDrifting then
                    Modules.DriftCounter.CurrentPoints = math.floor(Modules.DriftCounter.CurrentPoints + ConfigShared.StaticPointToAdd * Modules.Utils.TimeFrame) -- This fix the issue where player with low fps would get less point then player with high fps count. 
                end
            end
        else
            Modules.DriftCounter.IsDrifting = false
            if Modules.DriftCounter.ChainLoopStarted then
                Wait(0) -- Chain active, so we need to check if the player start drifting again or not as fast as possible
            else
                Wait(100) -- Could be longer i guess, but will take more time to detect if the player is drifting or not.
            end
        end
        Wait(0)
    end
end)
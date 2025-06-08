local onDuty = false -- Track the player's duty status
local dutyBlip = nil -- Store the player's own blip ID
local coworkerBlips = {} -- Store coworker blips
local callBlips = {} -- Store call blips
local onDutyUIVisible = false -- Track UI visibility
local towCooldown = false -- Track cooldown state for the /tow command

RegisterCommand("dutydot", function()
    onDuty = not onDuty -- Toggle duty status
    TriggerServerEvent("dutydot:toggleDuty", onDuty) -- Notify the server of duty status

    if onDuty then
        exports['okokNotify']:Alert("Info", "You are now on duty!", 5000, 'info')
        -- Create a blip for the player
        dutyBlip = AddBlipForEntity(PlayerPedId())
        SetBlipSprite(dutyBlip, 351) -- Use a wrench icon
        SetBlipDisplay(dutyBlip, 4)
        SetBlipScale(dutyBlip, 0.8)
        SetBlipColour(dutyBlip, 3) -- Green color
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("On Duty")
        EndTextCommandSetBlipName(dutyBlip)
    else
        exports['okokNotify']:Alert("Info", "You are now off duty!", 5000, 'info')
        -- Remove the player's own blip
        if dutyBlip then
            RemoveBlip(dutyBlip)
            dutyBlip = nil
        end
    end
end, false)

RegisterCommand("ondutylist", function()
    if onDutyUIVisible then
        -- Hide the UI and unlock the mouse
        SendNUIMessage({ type = "hide" })
        SetNuiFocus(false, false)
        onDutyUIVisible = false
        print("UI hidden and mouse focus unlocked.")
    else
        -- Request the updated on-duty list from the server
        TriggerServerEvent("dutydot:requestOnDutyList")
    end
end, false)

RegisterNetEvent("dutydot:updateOnDutyList")
AddEventHandler("dutydot:updateOnDutyList", function(onDutyPlayers)
    -- Debug print to verify the received list
    print("Received on-duty players:", json.encode(onDutyPlayers))

    -- Filter out invalid entries (e.g., null values)
    local validPlayers = {}
    for _, player in pairs(onDutyPlayers) do
        if player and player.name then
            table.insert(validPlayers, player)
        end
    end

    -- Ensure the on-duty list is valid
    if #validPlayers == 0 then
        exports['okokNotify']:Alert("Error", "No valid on-duty players found!", 5000, 'error')
        return
    end

    -- Send the filtered on-duty list to the NUI
    SendNUIMessage({
        type = "updatePlayerList",
        players = validPlayers
    })

    -- Show the UI and lock the mouse
    SendNUIMessage({ type = "show" })
    SetNuiFocus(true, true) -- Lock the mouse and keyboard focus
    onDutyUIVisible = true
    print("UI should now be visible, and mouse focus is locked.")
end)

RegisterNetEvent("dutydot:updateCoworkers")
AddEventHandler("dutydot:updateCoworkers", function(coworkers)
    -- Remove existing coworker blips
    for _, blip in pairs(coworkerBlips) do
        RemoveBlip(blip)
    end
    coworkerBlips = {}

    -- Add new blips for coworkers
    for _, coworker in pairs(coworkers) do
        if coworker.source ~= GetPlayerServerId(PlayerId()) then -- Exclude the player's own blip
            local blip = AddBlipForCoord(coworker.coords.x, coworker.coords.y, coworker.coords.z)
            SetBlipSprite(blip, 351) -- Use a wrench icon
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.8)
            SetBlipColour(blip, 5) -- Yellow color for coworkers
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Coworker")
            EndTextCommandSetBlipName(blip)
            table.insert(coworkerBlips, blip)
        end
    end
end)

RegisterNetEvent("dutydot:showOnDutyList")
AddEventHandler("dutydot:showOnDutyList", function(onDutyPlayers)
    print("Received on-duty list:", json.encode(onDutyPlayers)) -- Debug print

    -- Ensure the NUI message is sent correctly
    SendNUIMessage({
        action = "show",
        players = onDutyPlayers
    })

    -- Debug print to confirm NUI message is sent
    print("NUI message sent to show on-duty list.")

    -- Set NUI focus to allow interaction
    SetNuiFocus(true, true)
    onDutyUIVisible = true -- Track UI visibility
end)

RegisterNetEvent("dutydot:showCallBlip")
AddEventHandler("dutydot:showCallBlip", function(callerCoords, callerName)
    -- Debug print to verify the event data
    print("Received DOT call from:", callerName, "at coords:", callerCoords)

    -- Create a blip for the DOT call
    local callBlip = AddBlipForCoord(callerCoords.x, callerCoords.y, callerCoords.z)
    SetBlipSprite(callBlip, 280) -- Use a waypoint icon
    SetBlipDisplay(callBlip, 4)
    SetBlipScale(callBlip, 1.0)
    SetBlipColour(callBlip, 1) -- Red color
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("DOT Call: " .. callerName)
    EndTextCommandSetBlipName(callBlip)

    -- Store the blip and remove it after 5 minutes
    table.insert(callBlips, callBlip)
    CreateThread(function()
        Wait(300000) -- 5 minutes
        RemoveBlip(callBlip)
    end)

    -- Notify the player with okokNotify
    exports['okokNotify']:Alert(
        "Incoming DOT Call",
        string.format("?? Caller: %s\n?? Location: %s", callerName, "Check your map for the blip."),
        10000, -- Duration in milliseconds
        "info"
    )
end)

RegisterNetEvent("dutydot:fixAndUnflipVehicle")
AddEventHandler("dutydot:fixAndUnflipVehicle", function(vehicleNetId)
    local vehicle = NetToVeh(vehicleNetId)
    if DoesEntityExist(vehicle) then
        -- Fix the vehicle
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleUndriveable(vehicle, false)

        -- Unflip the vehicle (ensure it lands on its tires)
        local coords = GetEntityCoords(vehicle)
        SetEntityCoords(vehicle, coords.x, coords.y, coords.z + 1.0, false, false, false, true)
        SetEntityRotation(vehicle, 0.0, 0.0, 0.0, 2, true) -- Reset pitch, roll, and yaw
    else
        print("Vehicle does not exist or is not valid.")
    end
end)

RegisterNUICallback("close", function()
    -- Close the UI and unlock the mouse
    SendNUIMessage({ type = "hide" })
    SetNuiFocus(false, false) -- Unlock the mouse and keyboard focus
    onDutyUIVisible = false -- Update UI visibility status

    -- Debug print to confirm UI is being hidden
    print("UI has been hidden, and mouse focus is unlocked.")
end)

-- Add a keybind to close the UI when ESC is pressed
CreateThread(function()
    while true do
        Wait(0)
        if onDutyUIVisible and IsControlJustPressed(0, 322) then -- 322 is the control ID for ESC
            SendNUIMessage({ type = "hide" })
            SetNuiFocus(false, false)
            onDutyUIVisible = false

            -- Debug print to confirm ESC key was pressed
            print("ESC key pressed. UI hidden and mouse focus unlocked.")
        end
    end
end)

local function drawProgressBar(text, progress)
    -- Draw background bar
    DrawRect(0.5, 0.9, 0.3, 0.02, 50, 50, 50, 200)
    -- Draw progress bar
    DrawRect(0.5 - (0.3 / 2) + (progress * 0.3 / 2), 0.9, progress * 0.3, 0.02, 0, 150, 255, 255)
    -- Draw label text
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.88)
    -- Draw percentage text
    SetTextFont(4)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(string.format("%d%%", math.floor(progress * 100)))
    EndTextCommandDisplayText(0.5, 0.92)
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = string.len(text) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

-- Ensure /fixcar always fully repairs the car
RegisterCommand("fixcar", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed, true)
    local closestVehicle = nil
    local closestDistance = 5.0

    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)
        if distance < closestDistance then
            closestVehicle = vehicle
            closestDistance = distance
        end
    end

    if not closestVehicle then
        exports['okokNotify']:Alert("Error", "No vehicle found nearby to repair!", 5000, 'error')
        return
    end

    -- Lock the vehicle globally and make it undriveable
    local vehicleNetId = NetworkGetNetworkIdFromEntity(closestVehicle)
    TriggerServerEvent("dutydot:lockVehicle", vehicleNetId, true)
    SetVehicleUndriveable(closestVehicle, true)
    exports['okokNotify']:Alert("Info", "The vehicle is locked and undriveable during the repair process.", 5000, 'info')

    -- Open the front hood
    SetVehicleDoorOpen(closestVehicle, 4, false, false)

    -- Notify the player that the repair process has started
    exports['okokNotify']:Alert("Info", "You started fixing the vehicle! Press 'X' to stop.", 5000, 'info')

    -- Play emote animation (mechanic4)
    local emotePlayed = false
    print("[fixcar] Trying to play emote: mechanic4")
    TriggerEvent("rpemote:playEmote", "mechanic4", function(success)
        print("[fixcar] Emote callback, success:", success)
        emotePlayed = success
    end)
    Wait(600)
    if not emotePlayed then
        print("[fixcar] Emote failed, using fallback anim")
        RequestAnimDict("mini@repair")
        while not HasAnimDictLoaded("mini@repair") do
            Wait(100)
        end
        TaskPlayAnim(PlayerPedId(), "mini@repair", "fixing_a_ped", 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    -- Show progress bar and allow stopping with 'X'
    local repairTime = 5000 -- 5 seconds
    local startTime = GetGameTimer()
    local repairing = true

    CreateThread(function()
        while repairing do
            if IsControlJustPressed(0, 73) then -- 73 is the control ID for 'X'
                repairing = false
                ClearPedTasks(playerPed)
                TriggerServerEvent("dutydot:lockVehicle", vehicleNetId, false)
                SetVehicleUndriveable(closestVehicle, false)
                exports['okokNotify']:Alert("Info", "You stopped repairing the vehicle. It is now unlocked.", 5000, 'info')
                return
            end

            local currentCoords = GetEntityCoords(playerPed, true)
            local distance = #(currentCoords - GetEntityCoords(closestVehicle, true))
            if distance > 5.0 then
                repairing = false
                ClearPedTasks(playerPed)
                TriggerServerEvent("dutydot:lockVehicle", vehicleNetId, false)
                SetVehicleUndriveable(closestVehicle, false)
                exports['okokNotify']:Alert("Error", "You moved too far from the vehicle. Repair stopped. It is now unlocked.", 5000, 'error')
                return
            end

            Wait(0)
        end
    end)

    while repairing and GetGameTimer() - startTime < repairTime do
        local progress = (GetGameTimer() - startTime) / repairTime
        drawProgressBar("Repairing Vehicle", progress)
        Wait(0)
    end

    ClearPedTasks(playerPed)
    TriggerEvent("rpemote:stopEmote")
    if not repairing then return end

    -- Fully repair the vehicle
    SetVehicleFixed(closestVehicle)
    SetVehicleDeformationFixed(closestVehicle)
    SetVehicleUndriveable(closestVehicle, false)
    SetVehicleEngineHealth(closestVehicle, 1000.0)
    SetVehicleBodyHealth(closestVehicle, 1000.0)
    SetVehicleDirtLevel(closestVehicle, 0.0)
    -- Ensure all doors are shut (do NOT call SetVehicleDoorBroken)
    for i = 0, GetNumberOfVehicleDoors(closestVehicle) - 1 do
        SetVehicleDoorShut(closestVehicle, i, false)
    end

    -- Unlock the vehicle globally after repair
    TriggerServerEvent("dutydot:lockVehicle", vehicleNetId, false)
    exports['okokNotify']:Alert("Success", "The vehicle has been fully repaired and unlocked!", 5000, 'success')

    -- Notify the server to synchronize the repair
    TriggerServerEvent("dutydot:syncVehicleRepair", vehicleNetId)
end, false)

-- Register all mechanic commands
RegisterCommand("fixtires", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        local distance = #(playerCoords - vehCoords)
        if distance < 5.0 then
            vehicle = veh
            break
        end
    end
    if not vehicle then
        exports['okokNotify']:Alert("Error", "You are not near a vehicle!", 5000, 'error')
        return
    end
    exports['okokNotify']:Alert("Info", "You started fixing the tires!", 5000, 'info')
    -- Play emote animation (mechanic2)
    local emotePlayed = false
    print("[fixtires] Trying to play emote: mechanic2")
    TriggerEvent("rpemote:playEmote", "mechanic2", function(success)
        print("[fixtires] Emote callback, success:", success)
        emotePlayed = success
    end)
    Wait(600)
    if not emotePlayed then
        print("[fixtires] Emote failed, using fallback anim")
        RequestAnimDict("mini@repair")
        while not HasAnimDictLoaded("mini@repair") do
            Wait(100)
        end
        TaskPlayAnim(PlayerPedId(), "mini@repair", "fixing_a_ped", 8.0, -8.0, -1, 49, 0, false, false, false)
    end
    local repairTime = 15000
    local startTime = GetGameTimer()
    while GetGameTimer() - startTime < repairTime do
        local progress = (GetGameTimer() - startTime) / repairTime
        drawProgressBar("Fixing Tires", progress)
        Wait(0)
    end
    TriggerEvent("rpemote:stopEmote")
    ClearPedTasks(PlayerPedId())
    for i = 0, 5 do
        if IsVehicleTyreBurst(vehicle, i, false) then
            SetVehicleTyreFixed(vehicle, i)
        end
    end
    exports['okokNotify']:Alert("Success", "The tires have been repaired!", 5000, 'success')
end, false)

RegisterCommand("clean", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        local distance = #(playerCoords - vehCoords)
        if distance < 5.0 then
            vehicle = veh
            break
        end
    end
    if not vehicle then
        exports['okokNotify']:Alert("Error", "You are not near a vehicle to clean!", 5000, 'error')
        return
    end
    -- No emote, just progress bar
    local cleanTime = 5000
    local startTime = GetGameTimer()
    while GetGameTimer() - startTime < cleanTime do
        local progress = (GetGameTimer() - startTime) / cleanTime
        drawProgressBar("Cleaning Vehicle", progress)
        Wait(0)
    end
    SetVehicleDirtLevel(vehicle, 0.0)
    exports['okokNotify']:Alert("Success", "The vehicle has been cleaned!", 5000, 'success')
end, false)

RegisterCommand("refuel", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        local distance = #(playerCoords - vehCoords)
        if distance < 5.0 then
            vehicle = veh
            break
        end
    end
    if not vehicle then
        exports['okokNotify']:Alert("Error", "You are not near a vehicle to refuel!", 5000, 'error')
        return
    end
    -- No emote, just progress bar
    local refuelTime = 5000
    local startTime = GetGameTimer()
    while GetGameTimer() - startTime < refuelTime do
        local progress = (GetGameTimer() - startTime) / refuelTime
        drawProgressBar("Refueling Vehicle", progress)
        Wait(0)
    end
    SetVehicleFuelLevel(vehicle, 100.0)
    exports['okokNotify']:Alert("Success", "The vehicle has been refueled!", 5000, 'success')
end, false)

RegisterCommand("unlock", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        local distance = #(playerCoords - vehCoords)
        if distance < 5.0 then
            vehicle = veh
            break
        end
    end
    if not vehicle then
        exports['okokNotify']:Alert("Error", "You are not near a vehicle to unlock!", 5000, 'error')
        return
    end
    -- No emote, just progress bar
    local unlockTime = 3000
    local startTime = GetGameTimer()
    while GetGameTimer() - startTime < unlockTime do
        local progress = (GetGameTimer() - startTime) / unlockTime
        drawProgressBar("Unlocking Vehicle", progress)
        Wait(0)
    end
    SetVehicleDoorsLocked(vehicle, 1)
    exports['okokNotify']:Alert("Success", "The vehicle has been unlocked!", 5000, 'success')
end, false)

RegisterCommand("fasttow", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to use this command!", 5000, 'error')
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicle = nil
    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(veh)
        local distance = #(playerCoords - vehCoords)
        if distance < 5.0 then
            vehicle = veh
            break
        end
    end
    if not vehicle then
        exports['okokNotify']:Alert("Error", "No vehicle found nearby to tow!", 5000, 'error')
        return
    end
    -- No emote, just progress bar
    local towTime = 4000
    local startTime = GetGameTimer()
    while GetGameTimer() - startTime < towTime do
        local progress = (GetGameTimer() - startTime) / towTime
        drawProgressBar("Towing Vehicle", progress)
        Wait(0)
    end
    DeleteEntity(vehicle)
    exports['okokNotify']:Alert("Success", "The vehicle has been towed away instantly!", 5000, 'success')
    print("Vehicle deleted successfully.")
end, false)

-- Mechanic menu UI integration
RegisterCommand("openmc", function()
    if not onDuty then
        exports['okokNotify']:Alert("Error", "You must be on duty to open the mechanic menu!", 5000, 'error')
        return
    end
    SendNUIMessage({ type = "showMechanicMenu" })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback("closeMechanicMenu", function(data, cb)
    print("NUI: closeMechanicMenu called")
    SendNUIMessage({ type = "hideMechanicMenu" })
    SetNuiFocus(false, false)
    if cb then cb('ok') end
end)

RegisterNUICallback("mechanicAction", function(data, cb)
    print("NUI: mechanicAction called with action:", data and data.action)
    if data and data.action then
        ExecuteCommand(data.action)
    end
    if cb then cb('ok') end
end)

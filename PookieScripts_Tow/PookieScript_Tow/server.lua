-- Configuration for Discord integration
local server_config = {
    discordServerToken = "MTM1OTkzNDg5MDQwOTMyODcxMA.GK58SL.mD4pVlkzBRL-PmwUPNRK2DOo3icOpiQcrtLuxM", -- Discord bot token for permissions
    guildId = "1348436825949208607", -- Discord guild ID
    requiredRoleId = "123456789012345678" -- Replace with the exact Discord role ID
}

local onDutyPlayers = {} -- Track players who are on duty

RegisterServerEvent("dutydot:toggleDuty")
AddEventHandler("dutydot:toggleDuty", function(isOnDuty)
    local src = source
    local playerName = GetPlayerName(src) -- Get the player's name

    -- Check if the player has the required Discord role (mocked for now)
    local hasRequiredRole = true -- Replace with actual Discord role verification logic
    if not hasRequiredRole then
        TriggerClientEvent("okokNotify:Alert", src, "Permission Denied", "You do not have the required Discord role to go on duty.", 5000, "error")
        return
    end

    if isOnDuty then
        -- Add the player to the on-duty list
        onDutyPlayers[src] = { id = src, name = playerName }
        print(playerName .. " is now on duty.") -- Debug print
    else
        -- Remove the player from the on-duty list
        onDutyPlayers[src] = nil
        print(playerName .. " is now off duty.") -- Debug print
    end

    -- Notify the requesting player about the updated on-duty list
    TriggerClientEvent("dutydot:updateOnDutyList", src, onDutyPlayers)
end)

RegisterServerEvent("dutydot:requestCoworkers")
AddEventHandler("dutydot:requestCoworkers", function()
    local src = source
    local coworkers = {}

    for playerId, _ in pairs(onDutyPlayers) do
        if playerId ~= src then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then -- Ensure the ped exists
                local coords = GetEntityCoords(playerPed)
                table.insert(coworkers, { source = playerId, coords = coords })
            end
        end
    end

    TriggerClientEvent("dutydot:updateCoworkers", src, coworkers)
end)

RegisterServerEvent("dutydot:requestOnDutyList")
AddEventHandler("dutydot:requestOnDutyList", function()
    local src = source
    -- Send the current on-duty list to the requesting client
    TriggerClientEvent("dutydot:updateOnDutyList", src, onDutyPlayers)
end)

RegisterServerEvent("dutydot:callDot")
AddEventHandler("dutydot:callDot", function()
    local src = source
    local callerName = GetPlayerName(src)
    local callerCoords = GetEntityCoords(GetPlayerPed(src))

    -- Debug print to verify the event data
    print("DOT call triggered by:", callerName, "at coords:", callerCoords)

    -- Notify all on-duty players about the call
    for playerId, _ in pairs(onDutyPlayers) do
        if playerId ~= src then -- Ensure the caller doesn't receive their own notification
            TriggerClientEvent("dutydot:showCallBlip", playerId, callerCoords, callerName)
            TriggerClientEvent("okokNotify:Alert", playerId, "DOT Call", callerName .. " has requested DOT assistance!", 5000, "info")
            print("Notified on-duty player:", playerId) -- Debug print
        end
    end
end)

RegisterServerEvent("dutydot:fixAndUnflipVehicle")
AddEventHandler("dutydot:fixAndUnflipVehicle", function(vehicleNetId)
    local src = source
    -- Notify the client to fix and unflip the vehicle
    TriggerClientEvent("dutydot:fixAndUnflipVehicle", src, vehicleNetId)
end)

RegisterNetEvent("dutydot:syncVehicleRepair")
AddEventHandler("dutydot:syncVehicleRepair", function(vehicleNetId)
    -- Broadcast the repair event to all clients
    TriggerClientEvent("dutydot:repairVehicle", -1, vehicleNetId)
    print("Broadcasted full vehicle repair to all clients.") -- Debug log
end)

RegisterNetEvent("dutydot:lockVehicle")
AddEventHandler("dutydot:lockVehicle", function(vehicleNetId, lock)
    -- Broadcast the lock state to all clients
    TriggerClientEvent("dutydot:lockVehicleClient", -1, vehicleNetId, lock)
end)

RegisterCommand("dutydot", function(source, args, rawCommand)
    local src = source
    local onDuty = args[1] == "on" -- Check if the argument is "on" to toggle duty

    TriggerServerEvent("dutydot:toggleDuty", onDuty) -- Notify the server of duty status
end, false)

RegisterCommand("ondutylist", function(source, args, rawCommand)
    local src = source
    local onDutyList = {}

    for playerId, playerData in pairs(onDutyPlayers) do
        -- Add ACE permissions data (mocked for now)
        local acePermissions = {
            discordName = "DiscordUser#1234", -- Replace with actual Discord username retrieval logic
            roles = { "Role1", "Role2" } -- Replace with actual role retrieval logic
        }

        table.insert(onDutyList, {
            id = playerId,
            name = playerData.name,
            acePermissions = acePermissions
        })
    end

    -- Debug print to verify the list being sent
    print("Sending on-duty list to player via /ondutylist:", src, json.encode(onDutyList))

    -- Trigger the client event to show the UI with the on-duty list
    TriggerClientEvent("dutydot:updateOnDutyList", src, onDutyList)

    -- Debug print to confirm the event was triggered
    print("Triggered 'dutydot:updateOnDutyList' event for player:", src)
end, false)

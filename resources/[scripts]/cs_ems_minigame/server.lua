RegisterNetEvent('ems-minigame:reviveSuccess', function(targetServerId)
    local source = source
    local sourceName = GetPlayerName(source)
    local targetName = 'NPC'
    
    if targetServerId then
        targetName = GetPlayerName(targetServerId) or 'Unknown Player'
    end
    
    print(string.format('[EMS Mini-Game] player_revived(source=%d, target=%s)', source, targetServerId or 'NPC'))
    print(string.format('[EMS Mini-Game] %s (ID: %d) successfully revived %s (ID: %s)', 
        sourceName, source, targetName, targetServerId or 'NPC'))
end)

RegisterNetEvent('ems-minigame:reviveFailed', function(reason)
    local source = source
    local sourceName = GetPlayerName(source)
    
    print(string.format('[EMS Mini-Game] revive_failed(source=%d, reason=%s)', source, reason or 'Unknown'))
    print(string.format('[EMS Mini-Game] %s (ID: %d) failed revive attempt: %s', 
        sourceName, source, reason or 'Unknown error'))
end)

RegisterNetEvent('ems-minigame:revivePlayer', function(targetServerId)
    local source = source
    
    if not targetServerId or not GetPlayerPing(targetServerId) then
        print(string.format('[EMS Mini-Game] Invalid target server ID: %s', targetServerId))
        return
    end
    
    TriggerClientEvent('ems-minigame:reviveClient', targetServerId)
    
    print(string.format('[EMS Mini-Game] Reviving player %d (triggered by %d)', targetServerId, source))
end)

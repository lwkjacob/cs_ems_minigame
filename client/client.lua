local playerCooldowns = {}
local isTreating = false
local currentTarget = nil
local currentAnimDict = nil
local currentAnimClip = nil

local function IsPedDowned(ped)
    if not DoesEntityExist(ped) then return false end
    return IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) or IsEntityDead(ped)
end

local function GetDistanceBetweenEntities(entity1, entity2)
    local coords1 = GetEntityCoords(entity1)
    local coords2 = GetEntityCoords(entity2)
    return #(coords1 - coords2)
end

local function PlayAnimation(dict, clip, flag, blendIn, blendOut, duration)
    if not dict or not clip then return false end
    
    local ped = PlayerPedId()
    lib.requestAnimDict(dict)
    
    if not HasAnimDictLoaded(dict) then
        return false
    end
    
    currentAnimDict = dict
    currentAnimClip = clip
    
    TaskPlayAnim(ped, dict, clip, blendIn or 3.0, blendOut or 1.0, duration or -1, flag or 1, 0, false, false, false)
    return true
end

local function StopAnimation()
    local ped = PlayerPedId()
    if currentAnimDict and currentAnimClip then
        StopAnimTask(ped, currentAnimDict, currentAnimClip, 1.0)
        Wait(0)
        currentAnimDict = nil
        currentAnimClip = nil
    else
        ClearPedTasks(ped)
    end
end

local function FindClosestDownedTarget()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestTarget = nil
    local closestDistance = Config.Target.MaxDistance
    local closestServerId = nil
    
    local players = GetActivePlayers()
    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed and DoesEntityExist(targetPed) then
            if IsPedDowned(targetPed) then
                local distance = GetDistanceBetweenEntities(playerPed, targetPed)
                if distance < closestDistance then
                    closestDistance = distance
                    closestTarget = targetPed
                    closestServerId = GetPlayerServerId(playerId)
                end
            end
        end
    end
    
    if Config.Revive.AllowNPCs then
        local handle, ped = FindFirstPed()
        local success
        
        repeat
            if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
                if IsPedDowned(ped) then
                    local distance = GetDistanceBetweenEntities(playerPed, ped)
                    if distance < closestDistance then
                        closestDistance = distance
                        closestTarget = ped
                        closestServerId = nil
                    end
                end
            end
            success, ped = FindNextPed(handle)
        until not success
        
        EndFindPed(handle)
    end
    
    return closestTarget, closestServerId
end

local function PositionPlayerNearTarget(targetPed)
    local playerPed = PlayerPedId()
    TaskLookAtEntity(playerPed, targetPed, -1, 2048, 2)
end

local function Stage1_CPR()
    local anim = Config.Animations.CPR
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    local difficulties = {}
    for i = 1, Config.CPR.CheckCount do
        table.insert(difficulties, Config.Difficulty.CPR)
    end
    
    local success = lib.skillCheck(difficulties, {'w', 'a', 's', 'd'})
    
    StopAnimation()
    return success == true
end

local function Stage2_Bleeding()
    local anim = Config.Animations.Bandaging
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    for i = 1, Config.Bleeding.CheckCount do
        local difficulty
        if Config.Bleeding.RandomizeDifficulty then
            local randomIndex = math.random(1, #Config.Bleeding.DifficultyOptions)
            difficulty = Config.Bleeding.DifficultyOptions[randomIndex]
        else
            difficulty = Config.Difficulty.Bleeding
        end
        
        local inputs = {'w', 'a', 's', 'd'}
        local randomInputs = {}
        for j = 1, math.random(2, 4) do
            table.insert(randomInputs, inputs[math.random(1, #inputs)])
        end
        
        local success = lib.skillCheck({difficulty}, randomInputs)
        
        if not success then
            StopAnimation()
            return false
        end
        
        Wait(200)
    end
    
    StopAnimation()
    return true
end

local function Stage3_Stabilization()
    local anim = Config.Animations.Stabilization
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    local duration = math.random(Config.Stabilization.Duration.min, Config.Stabilization.Duration.max)
    
    local success = lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = 'Stabilizing patient...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        },
        anim = {
            dict = anim.dict,
            clip = anim.clip,
            flag = anim.flag
        }
    })
    
    StopAnimation()
    return success == true
end

local function HandleSuccess(targetPed, targetServerId)
    StopAnimation()
    
    if targetServerId then
        TriggerServerEvent('ems-minigame:revivePlayer', targetServerId)
    else
        if DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local targetHeading = GetEntityHeading(targetPed)
            
            SetEntityInvincible(targetPed, true)
            FreezeEntityPosition(targetPed, true)
            
            ResurrectPed(targetPed)
            SetPedCanRagdoll(targetPed, false)
            ClearPedTasksImmediately(targetPed)
            
            RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
            
            local startZ = targetCoords.z + 100.0
            local groundZ = targetCoords.z
            local found, z = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, startZ, false)
            if found then
                groundZ = z
            else
                local raycast = StartShapeTestRay(targetCoords.x, targetCoords.y, startZ, targetCoords.x, targetCoords.y, targetCoords.z - 100.0, -1, 0, 0)
                local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
                if hit == 1 then
                    groundZ = endCoords.z
                end
            end
            
            SetEntityCoordsNoOffset(targetPed, targetCoords.x, targetCoords.y, groundZ, false, false, false, true)
            SetEntityHeading(targetPed, targetHeading)
            
            SetEntityCollision(targetPed, true, true)
            SetEntityInvincible(targetPed, true)
            
            local time = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(targetPed) and (GetGameTimer() - time) < 3000 do
                Wait(0)
            end
            
            Wait(500)
            
            local verifyCoords = GetEntityCoords(targetPed)
            local verifyGroundZ = verifyCoords.z
            local found2, z2 = GetGroundZFor_3dCoord(verifyCoords.x, verifyCoords.y, verifyCoords.z + 100.0, false)
            if found2 then
                verifyGroundZ = z2
            else
                local raycast2 = StartShapeTestRay(verifyCoords.x, verifyCoords.y, verifyCoords.z + 100.0, verifyCoords.x, verifyCoords.y, verifyCoords.z - 100.0, -1, 0, 0)
                local retval2, hit2, endCoords2 = GetShapeTestResult(raycast2)
                if hit2 == 1 then
                    verifyGroundZ = endCoords2.z
                end
            end
            
            SetEntityCoordsNoOffset(targetPed, verifyCoords.x, verifyCoords.y, verifyGroundZ, false, false, false, true)
            
            SetEntityMaxHealth(targetPed, 200)
            SetEntityHealth(targetPed, Config.Revive.HealthAmount)
            SetPedArmour(targetPed, 0)
            
            SetBlockingOfNonTemporaryEvents(targetPed, true)
            SetPedFleeAttributes(targetPed, 0, false)
            SetPedCombatAttributes(targetPed, 46, true)
            
            TaskStandStill(targetPed, 1000)
            Wait(500)
            
            SetPedCanRagdoll(targetPed, true)
            FreezeEntityPosition(targetPed, false)
            SetEntityCollision(targetPed, true, true)
            
            Wait(2000)
            SetEntityInvincible(targetPed, false)
        end
    end
    
    local anim = Config.Animations.Revive
    if anim and anim.dict and anim.clip then
        PlayAnimation(anim.dict, anim.clip, anim.flag, 3.0, 1.0, 3000)
        Wait(3000)
        StopAnimation()
    end
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Patient successfully revived!',
        type = 'success',
        duration = 5000
    })
    
    TriggerServerEvent('ems-minigame:reviveSuccess', targetServerId)
    
    currentTarget = nil
    isTreating = false
end

local function HandleFailure(reason)
    StopAnimation()
    
    if lib.skillCheckActive() then
        lib.cancelSkillCheck()
    end
    
    if lib.progressActive() then
        lib.cancelProgress()
    end
    
    lib.notify({
        title = 'EMS Treatment',
        description = reason or 'Treatment failed!',
        type = 'error',
        duration = 5000
    })
    
    TriggerServerEvent('ems-minigame:reviveFailed', reason or 'Unknown error')
    
    currentTarget = nil
    isTreating = false
end

local function StartMiniGame(targetPed, targetServerId)
    if isTreating then
        lib.notify({
            title = 'EMS Treatment',
            description = 'You are already treating someone!',
            type = 'error'
        })
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        lib.notify({
            title = 'EMS Treatment',
            description = 'Target is no longer valid!',
            type = 'error'
        })
        return
    end
    
    isTreating = true
    currentTarget = targetPed
    
    PositionPlayerNearTarget(targetPed)
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 1: Performing CPR...',
        type = 'info',
        duration = 3000
    })
    
    if not Stage1_CPR() then
        HandleFailure('CPR rhythm check failed')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 2: Controlling bleeding...',
        type = 'info',
        duration = 3000
    })
    
    if not Stage2_Bleeding() then
        HandleFailure('Bleeding control check failed')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 3: Stabilizing patient...',
        type = 'info',
        duration = 3000
    })
    
    if not Stage3_Stabilization() then
        HandleFailure('Stabilization interrupted or failed')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    HandleSuccess(targetPed, targetServerId)
end

RegisterCommand('treat', function()
    local playerId = GetPlayerServerId(PlayerId())
    local currentTime = GetGameTimer()
    
    if playerCooldowns[playerId] and (currentTime - playerCooldowns[playerId]) < Config.Cooldown.Player then
        local remainingTime = math.ceil((Config.Cooldown.Player - (currentTime - playerCooldowns[playerId])) / 1000)
        lib.notify({
            title = 'EMS Treatment',
            description = string.format('You must wait %d seconds before treating again!', remainingTime),
            type = 'error'
        })
        return
    end
    
    if isTreating then
        lib.notify({
            title = 'EMS Treatment',
            description = 'You are already treating someone!',
            type = 'error'
        })
        return
    end
    
    local targetPed, targetServerId = FindClosestDownedTarget()
    
    if not targetPed then
        lib.alertDialog({
            header = 'No Target Found',
            content = 'No downed player or NPC found within ' .. Config.Target.MaxDistance .. ' meters.',
            centered = true,
            cancel = false
        })
        return
    end
    
    StartMiniGame(targetPed, targetServerId)
    
    playerCooldowns[playerId] = currentTime
end, false)

RegisterNetEvent('ems-minigame:reviveClient', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, false)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, Config.Revive.HealthAmount)
    Wait(100)
    SetPedCanRagdoll(ped, true)
    ClearPedTasksImmediately(ped)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        StopAnimation()
        if lib.skillCheckActive() then
            lib.cancelSkillCheck()
        end
        if lib.progressActive() then
            lib.cancelProgress()
        end
    end
end)


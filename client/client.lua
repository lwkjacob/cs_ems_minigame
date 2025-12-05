local playerCooldowns = {}
local isTreating = false
local currentTarget = nil
local currentAnimDict = nil
local currentAnimClip = nil
local currentCondition = nil
local currentInjury = nil
local currentBiometrics = nil
local injuryModifiers = {}
local conditionModifiers = {}
local treatmentStartTime = 0
local complicationsOccurred = 0

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

local function HasLineOfSight(entity1, entity2)
    local coords1 = GetEntityCoords(entity1)
    local coords2 = GetEntityCoords(entity2)
    local distance = #(coords1 - coords2)
    
    if distance < 1.5 then
        return true
    end
    
    local boneIndex1 = GetPedBoneIndex(entity1, 31086)
    local boneIndex2 = GetPedBoneIndex(entity2, 31086)
    
    local boneCoords1 = GetWorldPositionOfEntityBone(entity1, boneIndex1)
    local boneCoords2 = GetWorldPositionOfEntityBone(entity2, boneIndex2)
    
    local flags = -1
    local raycast = StartShapeTestRay(boneCoords1.x, boneCoords1.y, boneCoords1.z, boneCoords2.x, boneCoords2.y, boneCoords2.z, flags, entity1, 7)
    
    Wait(0)
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
    
    if retval == 2 then
        Wait(0)
        retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(raycast)
    end
    
    return hit == 0 or entityHit == entity2
end

local function CheckPatientAccess(targetPed)
    if not DoesEntityExist(targetPed) then
        return false, 'Patient no longer exists'
    end
    
    local playerPed = PlayerPedId()
    local distance = GetDistanceBetweenEntities(playerPed, targetPed)
    
    if distance > Config.Interrupt.MaxDistance then
        return false, 'Too far from patient'
    end
    
    if distance < 1.5 then
        return true
    end
    
    if not HasLineOfSight(playerPed, targetPed) then
        return false, 'Line of sight broken'
    end
    
    return true
end

local function GenerateConditionReport()
    local totalWeight = 0
    for _, condition in ipairs(Config.Assessment.Conditions) do
        totalWeight = totalWeight + condition.weight
    end
    
    local random = math.random(1, totalWeight)
    local currentWeight = 0
    
    for _, condition in ipairs(Config.Assessment.Conditions) do
        currentWeight = currentWeight + condition.weight
        if random <= currentWeight then
            return condition
        end
    end
    
    return Config.Assessment.Conditions[#Config.Assessment.Conditions]
end

local function DetectInjuryType(targetPed)
    if not DoesEntityExist(targetPed) then
        return 'unknown'
    end
    
    local pedCoords = GetEntityCoords(targetPed)
    local groundZ = pedCoords.z
    local found, z = GetGroundZFor_3dCoord(pedCoords.x, pedCoords.y, pedCoords.z + 10.0, false)
    if found then
        groundZ = z
    end
    
    if pedCoords.z - groundZ > 5.0 then
        return 'fall'
    end
    
    if IsEntityOnFire(targetPed) then
        return 'fire'
    end
    
    local lastDamageBone = GetPedLastDamageBone(targetPed)
    if lastDamageBone == 0 then
        return 'unknown'
    end
    
    local success, weaponHash = pcall(function()
        return GetPedCauseOfDeath(targetPed)
    end)
    
    if success and weaponHash and weaponHash ~= 0 then
        local success2, weaponGroup = pcall(function()
            return GetWeapontypeGroup(weaponHash)
        end)
        
        if success2 and weaponGroup then
            if weaponGroup == 416676503 or weaponGroup == 860033945 then
                return 'gunshot'
            elseif weaponGroup == 1567045032 then
                return 'explosion'
            elseif weaponGroup == 1548507267 or weaponGroup == -728555052 then
                return 'melee'
            end
        end
    end
    
    return 'unknown'
end

local function ApplyInjuryModifiers(injuryType)
    injuryModifiers = {}
    
    if Config.InjuryModifiers[injuryType] then
        local modifiers = Config.InjuryModifiers[injuryType]
        injuryModifiers = modifiers
    end
end

local function ApplyConditionModifiers(condition)
    conditionModifiers = {}
    
    if condition.modifiers then
        conditionModifiers = condition.modifiers
    end
end

local function GenerateBiometrics(condition, injury)
    local pulse = math.random(Config.Biometrics.Pulse.min, Config.Biometrics.Pulse.max)
    local respirations = math.random(Config.Biometrics.Respirations.min, Config.Biometrics.Respirations.max)
    local consciousness = math.random(Config.Biometrics.Consciousness.min, Config.Biometrics.Consciousness.max)
    
    local bleedingLevel = 'Low'
    if condition and condition.name == 'Severe bleeding present' then
        bleedingLevel = 'Severe'
    elseif injury == 'gunshot' or injury == 'explosion' then
        bleedingLevel = 'Moderate'
    end
    
    return {
        pulse = pulse,
        respirations = respirations,
        consciousness = consciousness,
        bleeding = bleedingLevel
    }
end

local function ShowBiometricsReport(vitals, title)
    local report = string.format(
        'Pulse: %d bpm\nRespirations: %d/min\nBleeding: %s\nConsciousness: %d%%',
        vitals.pulse,
        vitals.respirations,
        vitals.bleeding,
        vitals.consciousness
    )
    
    lib.alertDialog({
        header = title or 'Patient Vitals',
        content = report,
        centered = true,
        cancel = false
    })
end

local function UpdateBiometrics()
    if not currentBiometrics then return end
    
    local improvement = math.random(5, 15)
    currentBiometrics.pulse = math.min(Config.Biometrics.Pulse.max, currentBiometrics.pulse + improvement)
    currentBiometrics.respirations = math.min(Config.Biometrics.Respirations.max, currentBiometrics.respirations + math.random(1, 3))
    currentBiometrics.consciousness = math.min(100, currentBiometrics.consciousness + improvement)
    
    ShowBiometricsReport(currentBiometrics, 'Vitals Update')
end

local function AssessPatient(targetPed)
    local duration = math.random(Config.Assessment.Duration.min, Config.Assessment.Duration.max)
    
    local success = lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = 'Assessing Patient Condition...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
            mouse = false
        }
    })
    
    if not success then
        return false
    end
    
    local condition = GenerateConditionReport()
    currentCondition = condition
    
    ApplyConditionModifiers(condition)
    
    lib.notify({
        title = 'Assessment Complete',
        description = 'Condition: ' .. condition.name,
        type = condition.name == 'No major complications detected' and 'success' or 'warning',
        duration = 5000
    })
    
    return true
end

local function CheckComplication(stage)
    local complication = Config.Complications[stage]
    if not complication then return false end
    
    local roll = math.random(1, 100)
    if roll <= complication.chance then
        complicationsOccurred = complicationsOccurred + 1
        lib.notify({
            title = 'Complication',
            description = complication.name,
            type = 'warning',
            duration = 4000
        })
        return true
    end
    
    return false
end

local function Stage1_CPR(targetPed)
    local anim = Config.Animations.CPR
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    local cprDifficulty = Config.Difficulty.CPR
    if conditionModifiers.cprDifficulty then
        cprDifficulty = conditionModifiers.cprDifficulty
    end
    
    if injuryModifiers.cprSpeed then
        cprDifficulty = {
            areaSize = cprDifficulty.areaSize or 50,
            speedMultiplier = (cprDifficulty.speedMultiplier or 1.0) * injuryModifiers.cprSpeed
        }
    end
    
    local checkCount = Config.CPR.CheckCount
    if CheckComplication('CPR') then
        checkCount = checkCount + 1
    end
    
    local difficulties = {}
    for i = 1, checkCount do
        table.insert(difficulties, cprDifficulty)
    end
    
    if injuryModifiers.screenShake then
        CreateThread(function()
            while lib.skillCheckActive() do
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.1)
                Wait(100)
            end
        end)
    end
    
    local success = lib.skillCheck(difficulties, {'w', 'a', 's', 'd'})
    
    StopAnimation()
    return success == true
end

local function Stage2_Bleeding(targetPed)
    local anim = Config.Animations.Bandaging
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    local checkCount = Config.Bleeding.CheckCount
    
    if conditionModifiers.bleedingQTE then
        checkCount = checkCount + conditionModifiers.bleedingQTE
    end
    
    if injuryModifiers.bleedingQTE then
        local extra = math.random(injuryModifiers.bleedingQTE.min, injuryModifiers.bleedingQTE.max)
        checkCount = checkCount + extra
    end
    
    if CheckComplication('Bleeding') then
        checkCount = checkCount + Config.Complications.Bleeding.qteCount
    end
    
    for i = 1, checkCount do
        local access, reason = CheckPatientAccess(targetPed)
        if not access then
            StopAnimation()
            return false
        end
        
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

local function Stage3_Stabilization(targetPed)
    local anim = Config.Animations.Stabilization
    if not PlayAnimation(anim.dict, anim.clip, anim.flag) then
        return false
    end
    
    local duration = math.random(Config.Stabilization.Duration.min, Config.Stabilization.Duration.max)
    
    if conditionModifiers.stabilizationDuration then
        duration = math.floor(duration * conditionModifiers.stabilizationDuration)
    end
    
    if injuryModifiers.stabilizationDuration then
        duration = math.floor(duration * injuryModifiers.stabilizationDuration)
    end
    
    local speedMultiplier = 1.0
    if CheckComplication('Stabilization') then
        speedMultiplier = speedMultiplier - Config.Complications.Stabilization.speedReduction
    end
    
    local success = lib.progressCircle({
        duration = math.floor(duration / speedMultiplier),
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
    
    local treatmentTime = GetGameTimer() - treatmentStartTime
    local treatmentSeconds = math.floor(treatmentTime / 1000)
    
    local performanceRating = 'Stable Condition'
    if treatmentSeconds < 30 and complicationsOccurred == 0 then
        performanceRating = 'Perfect Treatment'
    elseif treatmentSeconds < 45 and complicationsOccurred <= 1 then
        performanceRating = 'Good Work'
    end
    
    local successMessages = {
        'Patient stabilized and breathing!',
        'Revival successful - patient responsive!',
        'Treatment complete - patient recovering!',
        'Patient revived - vitals stable!',
        'Emergency response successful!'
    }
    
    local randomMessage = successMessages[math.random(1, #successMessages)]
    
    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = 500
        while GetGameTimer() - startTime < duration do
            local elapsed = GetGameTimer() - startTime
            local alpha = math.floor(50 * (1 - (elapsed / duration)))
            DrawRect(0.5, 0.5, 1.0, 1.0, 0, 255, 0, alpha)
            Wait(0)
        end
    end)
    
    lib.notify({
        title = 'EMS Treatment',
        description = string.format('%s\n%s (Time: %ds)', randomMessage, performanceRating, treatmentSeconds),
        type = 'success',
        duration = 6000
    })
    
    TriggerServerEvent('ems-minigame:reviveSuccess', targetServerId)
    
    currentTarget = nil
    treatmentStartTime = 0
    complicationsOccurred = 0
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
    currentCondition = nil
    currentInjury = nil
    currentBiometrics = nil
    injuryModifiers = {}
    conditionModifiers = {}
    treatmentStartTime = 0
    complicationsOccurred = 0
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
    treatmentStartTime = GetGameTimer()
    complicationsOccurred = 0
    
    PositionPlayerNearTarget(targetPed)
    
    if not AssessPatient(targetPed) then
        HandleFailure('Assessment cancelled')
        return
    end
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    currentInjury = DetectInjuryType(targetPed)
    ApplyInjuryModifiers(currentInjury)
    
    currentBiometrics = GenerateBiometrics(currentCondition, currentInjury)
    ShowBiometricsReport(currentBiometrics, 'Initial Patient Assessment')
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 1: Performing CPR...',
        type = 'info',
        duration = 3000
    })
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    if not Stage1_CPR(targetPed) then
        local access, reason = CheckPatientAccess(targetPed)
        if not access then
            HandleFailure(reason or 'You lost access to the patient.')
        else
            HandleFailure('CPR rhythm check failed')
        end
        return
    end
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    UpdateBiometrics()
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 2: Controlling bleeding...',
        type = 'info',
        duration = 3000
    })
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    if not Stage2_Bleeding(targetPed) then
        local access, reason = CheckPatientAccess(targetPed)
        if not access then
            HandleFailure(reason or 'You lost access to the patient.')
        else
            HandleFailure('Bleeding control check failed')
        end
        return
    end
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    UpdateBiometrics()
    
    lib.notify({
        title = 'EMS Treatment',
        description = 'Stage 3: Stabilizing patient...',
        type = 'info',
        duration = 3000
    })
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    local interruptThread = CreateThread(function()
        local lastCheckTime = GetGameTimer()
        while lib.progressActive() do
            if GetGameTimer() - lastCheckTime >= Config.Interrupt.CheckInterval then
                local access, reason = CheckPatientAccess(targetPed)
                if not access then
                    lib.cancelProgress()
                    HandleFailure(reason or 'You lost access to the patient.')
                    return
                end
                lastCheckTime = GetGameTimer()
            end
            Wait(0)
        end
    end)
    
    if not Stage3_Stabilization(targetPed) then
        local access, reason = CheckPatientAccess(targetPed)
        if not access then
            HandleFailure(reason or 'You lost access to the patient.')
        else
            HandleFailure('Stabilization interrupted or failed')
        end
        return
    end
    
    local access, reason = CheckPatientAccess(targetPed)
    if not access then
        HandleFailure(reason or 'You lost access to the patient.')
        return
    end
    
    if not DoesEntityExist(targetPed) or not IsPedDowned(targetPed) then
        HandleFailure('Target moved or is no longer downed')
        return
    end
    
    UpdateBiometrics()
    
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


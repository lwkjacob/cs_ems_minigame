Config = {}

Config.Difficulty = {
    CPR = { areaSize = 50, speedMultiplier = 1.0 },
    Bleeding = { areaSize = 50, speedMultiplier = 1.0 },
    Stabilization = { areaSize = 50, speedMultiplier = 1.0 }
}

Config.CPR = {
    CheckCount = 5,
}

Config.Bleeding = {
    CheckCount = 4,
    RandomizeDifficulty = true,
    DifficultyOptions = {
        { areaSize = 60, speedMultiplier = 1.0 },
        { areaSize = 50, speedMultiplier = 1.0 },
        { areaSize = 30, speedMultiplier = 1.0 }
    },
}

Config.Stabilization = {
    Duration = {min = 3000, max = 5000},
}

Config.Revive = {
    HealthAmount = 100,
    AllowNPCs = true,
}

Config.Cooldown = {
    Player = 5000,
}

Config.Target = {
    MaxDistance = 3.0,
}

Config.Animations = {
    CPR = {
        dict = 'mini@cpr@char_a@cpr_str',
        clip = 'cpr_pumpchest',
        flag = 1,
    },
    Bandaging = {
        dict = 'amb@medic@standing@kneel@base',
        clip = 'base',
        flag = 1,
    },
    Stabilization = {
        dict = 'amb@medic@standing@kneel@base',
        clip = 'base',
        flag = 1,
    },
    Revive = {
        dict = 'mini@cpr@char_a@cpr_str',
        clip = 'cpr_success',
        flag = 1,
    },
    Kneel = {
        dict = 'amb@medic@standing@kneel@base',
        clip = 'base',
        flag = 1,
    }
}


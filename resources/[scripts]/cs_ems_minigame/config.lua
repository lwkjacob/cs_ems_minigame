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

Config.Assessment = {
    Duration = {min = 3000, max = 5000},
    Conditions = {
        {
            name = 'Weak pulse detected',
            weight = 20,
            modifiers = {
                cprDifficulty = {areaSize = 45, speedMultiplier = 1.0}
            }
        },
        {
            name = 'Severe bleeding present',
            weight = 15,
            modifiers = {
                bleedingQTE = 2
            }
        },
        {
            name = 'Airway obstructed',
            weight = 10,
            modifiers = {
                cprDifficulty = {areaSize = 40, speedMultiplier = 1.1}
            }
        },
        {
            name = 'Unstable vitals',
            weight = 15,
            modifiers = {
                stabilizationDuration = 1.4
            }
        },
        {
            name = 'No major complications detected',
            weight = 40,
            modifiers = {}
        }
    }
}

Config.InjuryModifiers = {
    gunshot = {
        bleedingQTE = {min = 1, max = 2}
    },
    explosion = {
        stabilizationDuration = 1.5,
        screenShake = true
    },
    fall = {
        stabilizationDuration = 1.3
    },
    fire = {
        cprSpeed = 1.2
    },
    melee = {}
}

Config.Complications = {
    CPR = {
        chance = 15,
        name = 'Possible Rib Fracture',
        effect = 'addCheck'
    },
    Bleeding = {
        chance = 20,
        name = 'Arterial Bleed Discovered',
        effect = 'addQTE',
        qteCount = 2
    },
    Stabilization = {
        chance = 10,
        name = 'Patient Entering Shock',
        effect = 'reduceSpeed',
        speedReduction = 0.3
    }
}

Config.Biometrics = {
    Pulse = {min = 30, max = 80},
    Respirations = {min = 4, max = 12},
    Consciousness = {min = 0, max = 25}
}

Config.Interrupt = {
    MaxDistance = 3.0,
    CheckInterval = 100
}


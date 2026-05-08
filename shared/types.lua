--[[
    rde_props_interact — shared/types.lua  v1.0.5
    Central enums, constants, shared helpers
]]

RDE_INTERACT = {}

RDE_INTERACT.TYPE = {
    NORMAL   = 'normal',
    STASH    = 'stash',
    CRAFTING = 'crafting',
}

RDE_INTERACT.LOCK = {
    NONE     = 'none',
    OWNER    = 'owner',
    JOB      = 'job',
    GROUP    = 'group',
    PASSCODE = 'passcode',
}

RDE_INTERACT.CRACK = {
    NONE   = 'none',
    EASY   = 'easy',
    MEDIUM = 'medium',
    HARD   = 'hard',
}

RDE_INTERACT.SKILLCHECK = {
    easy   = { { areaSize = 60, speedMultiplier = 1.0 } },
    medium = { { areaSize = 40, speedMultiplier = 1.5 }, { areaSize = 35, speedMultiplier = 1.5 } },
    hard   = { { areaSize = 25, speedMultiplier = 2.0 }, { areaSize = 20, speedMultiplier = 2.5 }, { areaSize = 15, speedMultiplier = 3.0 } },
}

RDE_INTERACT.CRACK_TIME = {
    easy   = 5000,
    medium = 10000,
    hard   = 20000,
}

RDE_INTERACT.COOLDOWN = {
    CRACK     = 15000,
    CRAFT     = 1000,
    CONFIGURE = 2000,
}

RDE_INTERACT.DEFAULT_CRAFT_TIME = 5000
RDE_INTERACT.MAX_DISTANCE       = 5.0

function RDE_INTERACT.HashPasscode(input)
    local str  = tostring(input) .. 'rde_salt_6x66'
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) ~ string.byte(str, i)) & 0xFFFFFFFF
    end
    return string.format('%08x', hash)
end

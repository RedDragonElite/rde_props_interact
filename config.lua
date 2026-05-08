--[[
    rde_props_interact — config.lua  v1.0.5
]]

Config = {}

Config.Debug           = false
Config.DatabaseTable   = 'rde_props_interact'
Config.StashPrefix     = 'rde_prop_'
Config.StatebagPrefix  = 'rde_interact:'

-- MUST match rde_props config.lua → Config.StatebagPrefix
-- rde_props uses 'rde_prop_' (underscore, NOT colon!)
Config.PropsStatebagPrefix = 'rde_prop_'

-- Admin: ox_core groups + ace permission fallback
Config.AdminGroups = {
    ['admin']      = true,
    ['superadmin'] = true,
    ['moderator']  = true,
    ['owner']      = true,
}

Config.AdminAce = 'command'

-- Police alert
Config.CrackPoliceAlert = true
Config.CrackPoliceJob   = 'police'

-- Auto-type models
Config.AutoStashModels = {
    ['prop_safety_case_01'] = {
        slots     = 10,
        maxWeight = 5000,
        lockType  = RDE_INTERACT.LOCK.OWNER,
        crackDiff = RDE_INTERACT.CRACK.MEDIUM,
    },
    ['ex_prop_shopsafe_01'] = {
        slots     = 20,
        maxWeight = 20000,
        lockType  = RDE_INTERACT.LOCK.OWNER,
        crackDiff = RDE_INTERACT.CRACK.HARD,
    },
    ['prop_ld_case_01'] = {
        slots     = 5,
        maxWeight = 2000,
        lockType  = RDE_INTERACT.LOCK.NONE,
        crackDiff = RDE_INTERACT.CRACK.NONE,
    },
}

Config.AutoCraftingModels = {
    ['prop_weed_table_01']    = 'weed_table',
    ['prop_weed_table_02']    = 'weed_table',
    ['bkr_prop_meth_lab_equ'] = 'meth_lab',
    ['prop_drug_table_01']    = 'coke_table',
}

-- Recipe sets
Config.RecipeSets = {
    ['weed_table'] = {
        label   = '🌿 Weed Processing Table',
        recipes = {
            {
                id         = 'baggy_weed_small',
                label      = 'Small Baggy Weed',
                inputs     = { ['dry_weed'] = 3, ['empty_baggy'] = 1 },
                output     = { item = 'baggy_weed', count = 1 },
                time       = 6000,
                skillCheck = RDE_INTERACT.CRACK.EASY,
            },
            {
                id         = 'baggy_weed_large',
                label      = 'Large Baggy Weed',
                inputs     = { ['dry_weed'] = 8, ['empty_baggy'] = 1 },
                output     = { item = 'baggy_weed_large', count = 1 },
                time       = 10000,
                skillCheck = RDE_INTERACT.CRACK.MEDIUM,
            },
        },
    },
    ['meth_lab'] = {
        label   = '🧪 Meth Lab',
        recipes = {
            {
                id         = 'meth_bag',
                label      = 'Bag of Meth',
                inputs     = { ['pseudoephedrine'] = 5, ['chemical_supply'] = 3, ['empty_baggy'] = 1 },
                output     = { item = 'meth_bag', count = 1 },
                time       = 15000,
                skillCheck = RDE_INTERACT.CRACK.HARD,
            },
        },
    },
    ['coke_table'] = {
        label   = '❄️ Coke Cutting Table',
        recipes = {
            {
                id         = 'coke_bag',
                label      = 'Bag of Coke',
                inputs     = { ['raw_cocaine'] = 5, ['cut_agent'] = 2, ['empty_baggy'] = 1 },
                output     = { item = 'coke_bag', count = 1 },
                time       = 12000,
                skillCheck = RDE_INTERACT.CRACK.MEDIUM,
            },
        },
    },
}

Config.DefaultStash = {
    slots     = 15,
    maxWeight = 10000,
    lockType  = RDE_INTERACT.LOCK.OWNER,
    crackDiff = RDE_INTERACT.CRACK.MEDIUM,
}

Config.CrackRelockTime = 300000

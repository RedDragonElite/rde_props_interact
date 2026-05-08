--[[
    rde_props_interact — client/main.lua  v1.0.5

    ROOT CAUSE FIXES:
    ✅ StateBag prefix 'rde_prop_' (underscore!) — matches rde_props Config.StatebagPrefix
    ✅ Uses addLocalEntity to attach interact options to the SAME entity as rde_props
    ✅ Options appear in the SAME ox_target menu as rde_props options
    ✅ @ox_core/lib/init.lua in shared_scripts (same as rde_props fxmanifest)
    ✅ Admin check via lib.callback (server checks groups + ace)
    ✅ Auto-configure props based on Config.AutoStashModels / AutoCraftingModels
]]

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────

local InteractData    = {}  -- [propId] = { type, metadata }
local TrackedEntities = {}  -- [propId] = entityHandle (for removeLocalEntity)
local IsCrafting      = false
local IsCracking      = false
local CrackBlocked    = false
local CachedIsAdmin   = false

-- ─────────────────────────────────────────────
-- LOGGING
-- ─────────────────────────────────────────────

local function Log(msg, level)
    if not Config.Debug and level ~= 'ERROR' then return end
    local prefix = level == 'ERROR' and '^1' or level == 'WARN' and '^3' or '^2'
    print(string.format('%s[RDE Interact]^7 %s', prefix, msg))
end

-- ─────────────────────────────────────────────
-- ADMIN CHECK (cached from server via lib.callback)
-- ─────────────────────────────────────────────

local function IsAdmin()
    return CachedIsAdmin
end

local function RefreshAdmin()
    local ok, result = pcall(lib.callback.await, 'rde_interact:isAdmin', false)
    if ok then CachedIsAdmin = result == true end
    return CachedIsAdmin
end

-- ─────────────────────────────────────────────
-- HAS GROUP (for police alert)
-- ─────────────────────────────────────────────

local function HasGroup(name)
    if not player then return false end
    local ok, groups = pcall(player.getGroups)
    if not ok or not groups then return false end
    return groups[name] ~= nil
end

-- ─────────────────────────────────────────────
-- TARGET OPTIONS (interact options per prop)
-- ─────────────────────────────────────────────

local function GetInteractOptions(propId, data)
    local options = {}
    local itype   = data and data.type
    local meta    = data and data.metadata or {}
    local locked  = (meta.lockType and meta.lockType ~= RDE_INTERACT.LOCK.NONE)
                    and (not meta.crackedUntil or GetGameTimer() >= meta.crackedUntil)

    -- ── STASH ──
    if itype == RDE_INTERACT.TYPE.STASH then
        if not locked then
            options[#options+1] = {
                name      = 'rde_interact_open_stash',
                icon      = 'fas fa-box-open',
                iconColor = '#22c55e',
                label     = '📦 Open Stash',
                distance  = 2.0,
                onSelect  = function()
                    TriggerServerEvent('rde_interact:openStash', propId)
                end,
            }
        end
        if locked then
            local crackDiff = meta.crackDiff or RDE_INTERACT.CRACK.NONE
            if crackDiff ~= RDE_INTERACT.CRACK.NONE then
                options[#options+1] = {
                    name      = 'rde_interact_crack',
                    icon      = 'fas fa-unlock-alt',
                    iconColor = '#f59e0b',
                    label     = string.format('🔓 Crack (%s)', crackDiff),
                    distance  = 2.0,
                    onSelect  = function()
                        StartCrack(propId, crackDiff)
                    end,
                }
            end
            if meta.lockType == RDE_INTERACT.LOCK.PASSCODE then
                options[#options+1] = {
                    name      = 'rde_interact_passcode',
                    icon      = 'fas fa-key',
                    iconColor = '#3b82f6',
                    label     = '🔑 Enter Passcode',
                    distance  = 2.0,
                    onSelect  = function()
                        OpenPasscodeDialog(propId)
                    end,
                }
            end
        end
    end

    -- ── CRAFTING ──
    if itype == RDE_INTERACT.TYPE.CRAFTING then
        local setId     = meta.recipeSetId
        local recipeSet = setId and Config.RecipeSets[setId]
        if recipeSet then
            options[#options+1] = {
                name      = 'rde_interact_craft',
                icon      = 'fas fa-flask',
                iconColor = '#8b5cf6',
                label     = string.format('⚗️ %s', recipeSet.label),
                distance  = 2.0,
                onSelect  = function()
                    OpenCraftingMenu(propId, recipeSet)
                end,
            }
        end
    end

    -- ── ADMIN: CONFIGURE ──
    if IsAdmin() then
        options[#options+1] = {
            name      = 'rde_interact_configure',
            icon      = 'fas fa-cog',
            iconColor = '#ffd700',
            label     = '⚙️ Configure Interaction',
            distance  = 2.0,
            onSelect  = function()
                OpenConfigureMenu(propId)
            end,
        }
        if itype and itype ~= RDE_INTERACT.TYPE.NORMAL then
            options[#options+1] = {
                name      = 'rde_interact_reset',
                icon      = 'fas fa-trash',
                iconColor = '#ef4444',
                label     = '🗑️ Remove Interaction',
                distance  = 2.0,
                onSelect  = function()
                    local confirm = lib.alertDialog({
                        header   = 'Remove Interaction',
                        content  = 'Remove all interaction data from this prop?',
                        centered = true,
                        cancel   = true,
                        labels   = { confirm = 'Remove', cancel = 'Cancel' },
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('rde_interact:propDeleted', propId)
                    end
                end,
            }
        end
    end

    return options
end

-- ─────────────────────────────────────────────
-- ENTITY FINDING (find the entity rde_props created)
-- ─────────────────────────────────────────────

local function FindEntity(propData, callback)
    if not propData or not propData.position or not propData.model then return end
    local pos   = propData.position
    local model = joaat(propData.model)

    -- Stage 1: immediate
    local entity = GetClosestObjectOfType(pos.x, pos.y, pos.z, 2.0, model, false, false, false)
    if DoesEntityExist(entity) then callback(entity); return end

    -- Stage 2: delayed (rde_props might still be creating it)
    SetTimeout(500, function()
        entity = GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, model, false, false, false)
        if DoesEntityExist(entity) then callback(entity); return end

        -- Stage 3: game pool scan
        SetTimeout(500, function()
            local objects = GetGamePool('CObject')
            for _, obj in ipairs(objects) do
                if GetEntityModel(obj) == model then
                    local objPos = GetEntityCoords(obj)
                    if #(vector3(pos.x, pos.y, pos.z) - objPos) < 3.0 then
                        callback(obj)
                        return
                    end
                end
            end
            Log(string.format('Entity not found for prop (model: %s) at %.1f %.1f', propData.model, pos.x, pos.y), 'WARN')
        end)
    end)
end

-- ─────────────────────────────────────────────
-- ATTACH / DETACH INTERACT OPTIONS TO ENTITY
-- Uses addLocalEntity → options appear in SAME
-- ox_target menu as rde_props options!
-- ─────────────────────────────────────────────

local function DetachInteract(propId)
    local entity = TrackedEntities[propId]
    if entity and DoesEntityExist(entity) then
        pcall(function()
            exports.ox_target:removeLocalEntity(entity, {
                'rde_interact_open_stash',
                'rde_interact_crack',
                'rde_interact_passcode',
                'rde_interact_craft',
                'rde_interact_configure',
                'rde_interact_reset',
            })
        end)
    end
    TrackedEntities[propId] = nil
end

local function AttachInteract(propId, entity, data)
    DetachInteract(propId)
    if not DoesEntityExist(entity) then return end

    local options = GetInteractOptions(propId, data)
    if #options == 0 then return end

    pcall(function()
        exports.ox_target:addLocalEntity(entity, options)
    end)

    TrackedEntities[propId] = entity
    Log(string.format('Attached %d interact options to %s', #options, propId), 'INFO')
end

-- Helper: find entity for propId and attach
local function AttachForProp(propId, data)
    local propKey  = Config.PropsStatebagPrefix .. propId
    local propData = GlobalState[propKey]
    if not propData then
        Log(string.format('No GlobalState for %s', propKey), 'WARN')
        return
    end
    FindEntity(propData, function(entity)
        AttachInteract(propId, entity, data)
    end)
end

-- ─────────────────────────────────────────────
-- CONFIGURE MENUS (admin)
-- ─────────────────────────────────────────────

function OpenConfigureMenu(propId)
    lib.registerContext({
        id      = 'rde_interact_configure_' .. propId,
        title   = '⚙️ Configure Interaction',
        options = {
            {
                title       = '📦 Set as Stash',
                description = 'Configure this prop as a lockable inventory stash',
                icon        = 'box',
                onSelect    = function() OpenStashSetupMenu(propId) end,
            },
            {
                title       = '⚗️ Set as Crafting Station',
                description = 'Assign a recipe set to this prop',
                icon        = 'flask',
                onSelect    = function() OpenCraftingSetupMenu(propId) end,
            },
        },
    })
    lib.showContext('rde_interact_configure_' .. propId)
end

function OpenStashSetupMenu(propId)
    local input = lib.inputDialog('Configure Stash', {
        { type = 'input',  label = 'Stash Label',    required = true, placeholder = 'My Safe' },
        { type = 'number', label = 'Slots',           required = true, default = Config.DefaultStash.slots },
        { type = 'number', label = 'Max Weight (g)',  required = true, default = Config.DefaultStash.maxWeight },
        { type = 'select', label = 'Lock Type',       required = true,
            options = {
                { value = RDE_INTERACT.LOCK.NONE,     label = 'None (always open)' },
                { value = RDE_INTERACT.LOCK.OWNER,    label = 'Owner only'         },
                { value = RDE_INTERACT.LOCK.JOB,      label = 'Job'                },
                { value = RDE_INTERACT.LOCK.GROUP,    label = 'Group'              },
                { value = RDE_INTERACT.LOCK.PASSCODE, label = 'Passcode'           },
            },
        },
        { type = 'select', label = 'Crack Difficulty', required = true,
            options = {
                { value = RDE_INTERACT.CRACK.NONE,   label = 'Not crackable' },
                { value = RDE_INTERACT.CRACK.EASY,   label = 'Easy'          },
                { value = RDE_INTERACT.CRACK.MEDIUM, label = 'Medium'        },
                { value = RDE_INTERACT.CRACK.HARD,   label = 'Hard'          },
            },
        },
    })
    if not input then return end
    local meta = {
        label = input[1], slots = input[2], maxWeight = input[3],
        lockType = input[4], crackDiff = input[5], locked = true,
    }
    if meta.lockType == RDE_INTERACT.LOCK.PASSCODE then
        local c = lib.inputDialog('Set Passcode', {{ type = 'number', label = 'Passcode (numeric)', required = true }})
        if not c then return end
        meta.passcode = RDE_INTERACT.HashPasscode(c[1])
    end
    if meta.lockType == RDE_INTERACT.LOCK.JOB then
        local c = lib.inputDialog('Job Name', {{ type = 'input', label = 'ox_core Job Name', required = true, placeholder = 'police' }})
        if not c then return end
        meta.jobName = c[1]
    end
    if meta.lockType == RDE_INTERACT.LOCK.GROUP then
        local c = lib.inputDialog('Group Name', {{ type = 'input', label = 'ox_core Group Name', required = true, placeholder = 'gang_ballas' }})
        if not c then return end
        meta.groupName = c[1]
    end
    TriggerServerEvent('rde_interact:configure', propId, RDE_INTERACT.TYPE.STASH, meta)
end

function OpenCraftingSetupMenu(propId)
    local opts = {}
    for setId, recipeSet in pairs(Config.RecipeSets) do
        opts[#opts+1] = { value = setId, label = recipeSet.label }
    end
    local input = lib.inputDialog('Configure Crafting Station', {
        { type = 'select', label = 'Recipe Set', required = true, options = opts },
    })
    if not input then return end
    TriggerServerEvent('rde_interact:configure', propId, RDE_INTERACT.TYPE.CRAFTING, { recipeSetId = input[1] })
end

-- ─────────────────────────────────────────────
-- PASSCODE DIALOG
-- ─────────────────────────────────────────────

function OpenPasscodeDialog(propId)
    local input = lib.inputDialog('🔑 Enter Passcode', {
        { type = 'number', label = 'Passcode', required = true },
    })
    if not input then return end
    TriggerServerEvent('rde_interact:passcode', propId, RDE_INTERACT.HashPasscode(input[1]))
end

-- ─────────────────────────────────────────────
-- CRACK SYSTEM
-- ─────────────────────────────────────────────

function StartCrack(propId, difficulty)
    if IsCracking then
        lib.notify({ title = '⚠️ Busy', description = 'Already cracking', type = 'warning' })
        return
    end
    if CrackBlocked then
        lib.notify({ title = '⏱️ Cooldown', description = 'Wait before trying again', type = 'warning' })
        return
    end
    TriggerServerEvent('rde_interact:crackAttempt', propId)
    local profile  = RDE_INTERACT.SKILLCHECK[difficulty] or RDE_INTERACT.SKILLCHECK.medium
    local duration = RDE_INTERACT.CRACK_TIME[difficulty]  or 10000
    IsCracking = true
    local success = lib.progressBar({
        duration = duration, label = string.format('🔓 Cracking (%s)...', difficulty),
        useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop' },
    })
    if not success then
        IsCracking = false
        TriggerServerEvent('rde_interact:crackFailed', propId)
        lib.notify({ title = '❌ Cancelled', description = 'Cracking cancelled', type = 'error' })
        return
    end
    local passed = lib.skillCheck(profile, { 'w', 'a', 's', 'd' })
    IsCracking = false
    if passed then
        TriggerServerEvent('rde_interact:crackSuccess', propId)
        lib.notify({ title = '🔓 Cracked!', description = 'Stash unlocked', type = 'success' })
    else
        TriggerServerEvent('rde_interact:crackFailed', propId)
        lib.notify({ title = '❌ Failed', description = 'Crack attempt failed', type = 'error' })
    end
end

RegisterNetEvent('rde_interact:crackBlocked', function()
    CrackBlocked = true
    SetTimeout(RDE_INTERACT.COOLDOWN.CRACK, function() CrackBlocked = false end)
end)

-- ─────────────────────────────────────────────
-- CRAFTING
-- ─────────────────────────────────────────────

function OpenCraftingMenu(propId, recipeSet)
    if IsCrafting then
        lib.notify({ title = '⚠️ Busy', description = 'Already crafting', type = 'warning' })
        return
    end
    local options = {}
    for _, recipe in ipairs(recipeSet.recipes) do
        local parts = {}
        for item, count in pairs(recipe.inputs) do parts[#parts+1] = string.format('%dx %s', count, item) end
        options[#options+1] = {
            title       = recipe.label,
            description = table.concat(parts, ' + ') .. string.format(' → %dx %s', recipe.output.count, recipe.output.item),
            icon = 'flask', iconColor = '#8b5cf6',
            onSelect = function() StartCrafting(propId, recipe) end,
        }
    end
    lib.registerContext({ id = 'rde_interact_craft_' .. propId, title = recipeSet.label, options = options })
    lib.showContext('rde_interact_craft_' .. propId)
end

function StartCrafting(propId, recipe)
    IsCrafting = true
    local success = lib.progressBar({
        duration = recipe.time or RDE_INTERACT.DEFAULT_CRAFT_TIME,
        label = string.format('⚗️ Crafting %s...', recipe.label),
        useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_parking_meter@female@idle_a', clip = 'idle_a' },
    })
    if not success then
        IsCrafting = false
        lib.notify({ title = '❌ Cancelled', description = 'Crafting cancelled', type = 'inform' })
        return
    end
    if recipe.skillCheck and recipe.skillCheck ~= RDE_INTERACT.CRACK.NONE then
        local profile = RDE_INTERACT.SKILLCHECK[recipe.skillCheck]
        if profile then
            local passed = lib.skillCheck(profile, { 'w', 'a', 's', 'd' })
            if not passed then
                IsCrafting = false
                lib.notify({ title = '❌ Failed', description = 'Skillcheck failed', type = 'error' })
                return
            end
        end
    end
    IsCrafting = false
    TriggerServerEvent('rde_interact:craft', propId, recipe.id)
end

-- ─────────────────────────────────────────────
-- POLICE ALERT
-- ─────────────────────────────────────────────

RegisterNetEvent('rde_interact:policeAlert', function(data)
    if not HasGroup(data.job) then return end
    lib.notify({
        title = '🚨 Safe Cracking Attempt',
        description = string.format('Reported at %.1f, %.1f', data.coords.x, data.coords.y),
        type = 'error', duration = 10000,
    })
end)

RegisterNetEvent('rde_interact:sendCrackCoords', function(propId)
    local propData = GlobalState[Config.PropsStatebagPrefix .. propId]
    if propData and propData.position then
        TriggerServerEvent('rde_interact:crackCoords', propId, propData.position)
    end
end)

-- ─────────────────────────────────────────────
-- SYNC EVENTS FROM SERVER
-- ─────────────────────────────────────────────

RegisterNetEvent('rde_interact:loadAll', function(allData, isAdmin)
    InteractData  = allData or {}
    CachedIsAdmin = isAdmin == true
    Log(string.format('Loaded %d interact entries (admin: %s)', #allData or 0, tostring(CachedIsAdmin)), 'INFO')
end)

RegisterNetEvent('rde_interact:sync', function(propId, data)
    InteractData[propId] = data
    -- Re-attach interact options to entity
    AttachForProp(propId, data)
end)

RegisterNetEvent('rde_interact:remove', function(propId)
    InteractData[propId] = nil
    DetachInteract(propId)
end)

RegisterNetEvent('rde_interact:refreshZone', function(propId, data)
    InteractData[propId] = data
    AttachForProp(propId, data)
end)

-- ─────────────────────────────────────────────
-- HOOK INTO rde_props STATEBAG
-- Key fix: prefix is 'rde_prop_' (underscore!)
-- ─────────────────────────────────────────────

AddStateBagChangeHandler(Config.PropsStatebagPrefix, nil, function(bagName, key, value)
    if not value then return end
    local propId = key:gsub(Config.PropsStatebagPrefix, '')

    if value._deleted then
        DetachInteract(propId)
        return
    end

    -- Wait for rde_props to create the entity first (it processes the same statebag)
    SetTimeout(800, function()
        -- If this prop has interact data → attach options
        if InteractData[propId] then
            FindEntity(value, function(entity)
                AttachInteract(propId, entity, InteractData[propId])
            end)
            return
        end

        -- Check auto-configure models
        if value.model then
            if Config.AutoStashModels[value.model] or Config.AutoCraftingModels[value.model] then
                TriggerServerEvent('rde_interact:autoConfig', propId, value.model)
                Log(string.format('Auto-config triggered: %s (model: %s)', propId, value.model), 'INFO')
            end
        end

        -- Admin can see configure on unconfigured props
        if IsAdmin() then
            FindEntity(value, function(entity)
                AttachInteract(propId, entity, nil)
            end)
        end
    end)
end)

-- Also listen to rde_props direct events (backup for statebag)
RegisterNetEvent('rde_props:statebagUpdate', function(propId, propData)
    if not propData then return end
    SetTimeout(500, function()
        if InteractData[propId] then
            FindEntity(propData, function(entity)
                AttachInteract(propId, entity, InteractData[propId])
            end)
        elseif IsAdmin() then
            FindEntity(propData, function(entity)
                AttachInteract(propId, entity, nil)
            end)
        end
    end)
end)

RegisterNetEvent('rde_props:statebagDelete', function(propId)
    DetachInteract(propId)
end)

-- rde_props:loadAll — all props loaded on join
RegisterNetEvent('rde_props:loadAll', function(props)
    -- Wait for rde_props to finish creating entities
    SetTimeout(3000, function()
        for propId, propData in pairs(props or {}) do
            if InteractData[propId] then
                FindEntity(propData, function(entity)
                    AttachInteract(propId, entity, InteractData[propId])
                end)
            elseif propData.model then
                if Config.AutoStashModels[propData.model] or Config.AutoCraftingModels[propData.model] then
                    TriggerServerEvent('rde_interact:autoConfig', propId, propData.model)
                end
                if IsAdmin() then
                    FindEntity(propData, function(entity)
                        AttachInteract(propId, entity, nil)
                    end)
                end
            elseif IsAdmin() then
                FindEntity(propData, function(entity)
                    AttachInteract(propId, entity, nil)
                end)
            end
        end
        Log('Finished attaching interact options to existing props', 'INFO')
    end)
end)

-- ─────────────────────────────────────────────
-- INIT
-- ─────────────────────────────────────────────

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(3000)
    TriggerServerEvent('rde_interact:init')

    -- Refresh admin periodically
    while true do
        Wait(30000)
        RefreshAdmin()
    end
end)

print('^2[RDE Interact]^7 Client v1.0.5 loaded ✅')

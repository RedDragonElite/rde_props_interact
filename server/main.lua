--[[
    rde_props_interact — server/main.lua  v1.0.5

    ✅ Admin check matches rde_props exactly (ace + hasPermission + getGroups)
    ✅ RegisterStash correct API per coxdocs
    ✅ Passcode NOT double-hashed
    ✅ forceOpenInventory for stash opening
    ✅ Auto-configure from model
    ✅ lib.callback for client admin check
]]

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────

local InteractData   = {}
local CrackCooldowns = {}
local EventCooldowns = {}

-- ─────────────────────────────────────────────
-- LOGGING
-- ─────────────────────────────────────────────

local function Log(msg, level)
    if not Config.Debug and level ~= 'ERROR' then return end
    local prefix = level == 'ERROR' and '^1' or level == 'WARN' and '^3' or '^2'
    print(string.format('%s[RDE Interact]^7 %s', prefix, msg))
end

-- ─────────────────────────────────────────────
-- HELPERS (matches rde_props server.lua exactly)
-- ─────────────────────────────────────────────

local function GetIdentifier(source)
    local oxPlayer = Ox.GetPlayer(source)
    if not oxPlayer then return nil end
    if oxPlayer.stateId then return oxPlayer.stateId end
    if oxPlayer.charId  then return tostring(oxPlayer.charId) end
    if oxPlayer.userId  then return tostring(oxPlayer.userId) end
    return nil
end

--- Admin check: mirrors rde_props server.lua IsAdmin() exactly
local function IsAdmin(source)
    if not source or source == 0 then return true end
    -- 1. Ace permissions
    if Config.AdminAce then
        if IsPlayerAceAllowed(source, Config.AdminAce) or IsPlayerAceAllowed(source, 'admin') then
            return true
        end
    end
    -- 2. ox_core player
    local oxPlayer = Ox.GetPlayer(source)
    if not oxPlayer then return false end
    -- 3. hasPermission
    if oxPlayer.hasPermission and oxPlayer.hasPermission('admin') then return true end
    -- 4. getGroups
    if oxPlayer.getGroups then
        local groups = oxPlayer.getGroups()
        if groups then
            for groupName, _ in pairs(groups) do
                if Config.AdminGroups[groupName] then return true end
            end
        end
    end
    return false
end

local function Notify(source, title, description, ntype)
    if not source or source == 0 then return end
    TriggerClientEvent('ox_lib:notify', source, {
        title = title, description = description, type = ntype,
    })
end

-- ─────────────────────────────────────────────
-- CALLBACK: IS ADMIN (for client)
-- ─────────────────────────────────────────────

lib.callback.register('rde_interact:isAdmin', function(source)
    return IsAdmin(source)
end)

-- ─────────────────────────────────────────────
-- COOLDOWNS
-- ─────────────────────────────────────────────

local function IsOnCooldown(key)
    local e = EventCooldowns[key]
    return e and GetGameTimer() < e
end
local function SetCooldown(key, d)
    EventCooldowns[key] = GetGameTimer() + d
end
local function IsOnCrackCooldown(propId, id)
    local e = CrackCooldowns[propId .. ':' .. id]
    return e and GetGameTimer() < e
end
local function SetCrackCooldown(propId, id)
    CrackCooldowns[propId .. ':' .. id] = GetGameTimer() + RDE_INTERACT.COOLDOWN.CRACK
end

-- ─────────────────────────────────────────────
-- DISTANCE CHECK
-- ─────────────────────────────────────────────

local function IsNearProp(source, propId)
    local data = InteractData[propId]
    if not data or not data.metadata then return true end
    local pos = data.metadata.position
    if not pos then return true end
    local pc = GetEntityCoords(GetPlayerPed(source))
    return #(pc - vector3(pos.x, pos.y, pos.z)) <= RDE_INTERACT.MAX_DISTANCE
end

-- ─────────────────────────────────────────────
-- STATEBAG SYNC (interact data)
-- ─────────────────────────────────────────────

local function SyncInteract(propId, data)
    local key = Config.StatebagPrefix .. propId
    if data then
        GlobalState[key] = data
        TriggerClientEvent('rde_interact:sync', -1, propId, data)
    else
        GlobalState[key] = nil
        TriggerClientEvent('rde_interact:remove', -1, propId)
    end
end

-- ─────────────────────────────────────────────
-- STASH REGISTRATION (per coxdocs)
-- ─────────────────────────────────────────────

local function RegisterStash(propId, meta)
    local stashId = Config.StashPrefix .. propId
    exports.ox_inventory:RegisterStash(
        stashId,
        meta.label or ('Stash [' .. propId .. ']'),
        meta.slots     or Config.DefaultStash.slots,
        meta.maxWeight or Config.DefaultStash.maxWeight,
        meta.owner or false, nil, nil
    )
    Log(string.format('Stash registered: %s', stashId), 'INFO')
end

-- ─────────────────────────────────────────────
-- AUTO-CONFIGURE
-- ─────────────────────────────────────────────

local function AutoConfigureProp(propId, model, ownerIdentifier)
    if InteractData[propId] then return false end
    if not model then return false end

    local stashConfig = Config.AutoStashModels[model]
    if stashConfig then
        local meta = {
            label     = stashConfig.label or ('Auto Stash [' .. model .. ']'),
            slots     = stashConfig.slots     or Config.DefaultStash.slots,
            maxWeight = stashConfig.maxWeight or Config.DefaultStash.maxWeight,
            lockType  = stashConfig.lockType  or RDE_INTERACT.LOCK.NONE,
            crackDiff = stashConfig.crackDiff or RDE_INTERACT.CRACK.NONE,
            locked    = true,
            owner     = ownerIdentifier,
        }
        RDE_DB_Insert(propId, RDE_INTERACT.TYPE.STASH, meta)
        local data = { propId = propId, type = RDE_INTERACT.TYPE.STASH, metadata = meta }
        InteractData[propId] = data
        RegisterStash(propId, meta)
        SyncInteract(propId, data)
        Log(string.format('Auto-configured STASH: %s (model: %s)', propId, model), 'INFO')
        return true
    end

    local recipeSetId = Config.AutoCraftingModels[model]
    if recipeSetId and Config.RecipeSets[recipeSetId] then
        local meta = { recipeSetId = recipeSetId, owner = ownerIdentifier }
        RDE_DB_Insert(propId, RDE_INTERACT.TYPE.CRAFTING, meta)
        local data = { propId = propId, type = RDE_INTERACT.TYPE.CRAFTING, metadata = meta }
        InteractData[propId] = data
        SyncInteract(propId, data)
        Log(string.format('Auto-configured CRAFTING: %s (model: %s, set: %s)', propId, model, recipeSetId), 'INFO')
        return true
    end

    return false
end

-- ─────────────────────────────────────────────
-- LOAD ON START
-- ─────────────────────────────────────────────

local function LoadAll()
    RDE_DB_LoadAll(function(rows)
        local count = 0
        for propId, data in pairs(rows) do
            InteractData[propId] = data
            if data.type == RDE_INTERACT.TYPE.STASH then
                RegisterStash(propId, data.metadata)
            end
            SyncInteract(propId, data)
            count = count + 1
        end
        Log(string.format('Loaded %d interact props from DB', count), 'INFO')
    end)
end

-- ─────────────────────────────────────────────
-- LOCK / ACCESS
-- ─────────────────────────────────────────────

local function IsLocked(propId)
    local d = InteractData[propId]
    if not d or not d.metadata then return false end
    local m = d.metadata
    if (m.lockType or RDE_INTERACT.LOCK.NONE) == RDE_INTERACT.LOCK.NONE then return false end
    if m.crackedUntil and GetGameTimer() < m.crackedUntil then return false end
    return m.locked ~= false
end

local function CanAccess(source, propId)
    local d = InteractData[propId]
    if not d then return false end
    local m = d.metadata
    if (m.lockType or RDE_INTERACT.LOCK.NONE) == RDE_INTERACT.LOCK.NONE then return true end
    if IsAdmin(source) then return true end
    if not IsLocked(propId) then return true end
    local id = GetIdentifier(source)
    local ox = Ox.GetPlayer(source)
    if m.lockType == RDE_INTERACT.LOCK.OWNER then return m.owner == id end
    if m.lockType == RDE_INTERACT.LOCK.JOB then
        local g = ox and ox.getGroups and ox.getGroups() or {}
        return g[m.jobName] ~= nil
    end
    if m.lockType == RDE_INTERACT.LOCK.GROUP then
        local g = ox and ox.getGroups and ox.getGroups() or {}
        return g[m.groupName] ~= nil
    end
    return false
end

-- ─────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────

RegisterNetEvent('rde_interact:autoConfig', function(propId, model)
    local source = source
    local id = GetIdentifier(source)
    if not id then return end
    AutoConfigureProp(propId, model, id)
end)

RegisterNetEvent('rde_interact:configure', function(propId, itype, meta)
    local source = source
    if not IsAdmin(source) then Notify(source, '❌', 'No permission', 'error'); return end
    local ck = tostring(source) .. ':configure'
    if IsOnCooldown(ck) then Notify(source, '⏱️', 'Cooldown', 'warning'); return end
    SetCooldown(ck, RDE_INTERACT.COOLDOWN.CONFIGURE)
    if not propId or not itype then return end
    local id = GetIdentifier(source)
    meta = meta or {}
    meta.owner = meta.owner or id

    if InteractData[propId] then
        MySQL.query.await('UPDATE `' .. Config.DatabaseTable .. '` SET `type` = ?, `metadata` = ? WHERE `prop_id` = ?', { itype, json.encode(meta), propId })
    else
        RDE_DB_Insert(propId, itype, meta)
    end

    local data = { propId = propId, type = itype, metadata = meta }
    InteractData[propId] = data
    if itype == RDE_INTERACT.TYPE.STASH then RegisterStash(propId, meta) end
    SyncInteract(propId, data)
    TriggerClientEvent('rde_interact:refreshZone', source, propId, data)
    Notify(source, '✅ Configured', string.format('Prop set as %s', itype), 'success')
    Log(string.format('Configured: %s -> %s by %s', propId, itype, id), 'INFO')
end)

RegisterNetEvent('rde_interact:openStash', function(propId)
    local source = source
    if not IsNearProp(source, propId) then Notify(source, '❌', 'Too far', 'error'); return end
    if not CanAccess(source, propId) then Notify(source, '🔒', 'Locked', 'error'); return end
    exports.ox_inventory:forceOpenInventory(source, 'stash', Config.StashPrefix .. propId)
end)

RegisterNetEvent('rde_interact:passcode', function(propId, hashedInput)
    local source = source
    local d = InteractData[propId]
    if not d then return end
    if not IsNearProp(source, propId) then Notify(source, '❌', 'Too far', 'error'); return end
    local m = d.metadata
    if m.passcode and hashedInput == m.passcode then
        m.crackedUntil = GetGameTimer() + Config.CrackRelockTime
        InteractData[propId].metadata = m
        RDE_DB_UpdateMeta(propId, m)
        SyncInteract(propId, InteractData[propId])
        exports.ox_inventory:forceOpenInventory(source, 'stash', Config.StashPrefix .. propId)
        Notify(source, '🔓', 'Passcode correct', 'success')
    else
        Notify(source, '❌', 'Incorrect passcode', 'error')
    end
end)

RegisterNetEvent('rde_interact:crackAttempt', function(propId)
    local source = source
    local id = GetIdentifier(source)
    if not id then return end
    if IsOnCrackCooldown(propId, id) then
        Notify(source, '⏱️', 'Cooldown', 'warning')
        TriggerClientEvent('rde_interact:crackBlocked', source)
        return
    end
    if Config.CrackPoliceAlert then
        TriggerClientEvent('rde_interact:sendCrackCoords', source, propId)
    end
end)

RegisterNetEvent('rde_interact:crackSuccess', function(propId)
    local source = source
    local id = GetIdentifier(source)
    local d = InteractData[propId]
    if not d or d.type ~= RDE_INTERACT.TYPE.STASH or not id then return end
    if not IsNearProp(source, propId) then return end
    SetCrackCooldown(propId, id)
    local m = d.metadata
    m.crackedUntil = GetGameTimer() + Config.CrackRelockTime
    InteractData[propId].metadata = m
    RDE_DB_UpdateMeta(propId, m)
    SyncInteract(propId, InteractData[propId])
    exports.ox_inventory:forceOpenInventory(source, 'stash', Config.StashPrefix .. propId)
end)

RegisterNetEvent('rde_interact:crackFailed', function(propId)
    local source = source
    local id = GetIdentifier(source)
    if id then SetCrackCooldown(propId, id) end
end)

RegisterNetEvent('rde_interact:crackCoords', function(propId, coords)
    if not coords then return end
    TriggerClientEvent('rde_interact:policeAlert', -1, { propId = propId, coords = coords, job = Config.CrackPoliceJob })
end)

RegisterNetEvent('rde_interact:craft', function(propId, recipeId)
    local source = source
    local ck = tostring(source) .. ':craft'
    if IsOnCooldown(ck) then return end
    SetCooldown(ck, RDE_INTERACT.COOLDOWN.CRAFT)
    if not IsNearProp(source, propId) then Notify(source, '❌', 'Too far', 'error'); return end
    local d = InteractData[propId]
    if not d or d.type ~= RDE_INTERACT.TYPE.CRAFTING then return end
    local setId = d.metadata.recipeSetId
    local recipeSet = setId and Config.RecipeSets[setId]
    if not recipeSet then return end
    local recipe
    for _, r in ipairs(recipeSet.recipes) do if r.id == recipeId then recipe = r; break end end
    if not recipe then return end
    for item, count in pairs(recipe.inputs) do
        local has = exports.ox_inventory:GetItemCount(source, item)
        if not has or has < count then
            Notify(source, '❌', string.format('Need %dx %s', count, item), 'error')
            return
        end
    end
    for item, count in pairs(recipe.inputs) do exports.ox_inventory:RemoveItem(source, item, count) end
    exports.ox_inventory:AddItem(source, recipe.output.item, recipe.output.count)
    Notify(source, '✅', string.format('%dx %s', recipe.output.count, recipe.output.item), 'success')
end)

RegisterNetEvent('rde_interact:propDeleted', function(propId)
    local source = source
    if not InteractData[propId] then return end
    if not IsAdmin(source) then Notify(source, '❌', 'No permission', 'error'); return end
    RDE_DB_Delete(propId)
    InteractData[propId] = nil
    SyncInteract(propId, nil)
end)

RegisterNetEvent('rde_interact:init', function()
    local source = source
    TriggerClientEvent('rde_interact:loadAll', source, InteractData, IsAdmin(source))
end)

-- ─────────────────────────────────────────────
-- STARTUP
-- ─────────────────────────────────────────────

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    local attempts = 0
    while not Ox and attempts < 200 do Wait(100); attempts = attempts + 1 end
    if not Ox then
        print('^1[RDE Interact]^7 ox_core not found!')
        return
    end
    RDE_DB_Setup(function()
        LoadAll()
        print('^2[RDE Interact]^7 Server v1.0.5 loaded ✅')
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for propId in pairs(InteractData) do
        GlobalState[Config.StatebagPrefix .. propId] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        local now = GetGameTimer()
        for k, v in pairs(CrackCooldowns) do if now > v then CrackCooldowns[k] = nil end end
        for k, v in pairs(EventCooldowns) do if now > v then EventCooldowns[k] = nil end end
    end
end)

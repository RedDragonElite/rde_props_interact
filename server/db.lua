--[[
    rde_props_interact — server/db.lua  v1.0.5
]]

function RDE_DB_Setup(callback)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.DatabaseTable .. [[` (
            `prop_id`    VARCHAR(64)                        NOT NULL PRIMARY KEY,
            `type`       ENUM('stash','crafting')           NOT NULL,
            `metadata`   LONGTEXT                           NOT NULL DEFAULT '{}',
            `created_at` TIMESTAMP                          DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP                          DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `idx_type` (`type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], function()
        if callback then callback() end
    end)
end

function RDE_DB_LoadAll(callback)
    MySQL.query('SELECT * FROM `' .. Config.DatabaseTable .. '`', {}, function(rows)
        local result = {}
        for _, row in ipairs(rows or {}) do
            result[row.prop_id] = {
                propId   = row.prop_id,
                type     = row.type,
                metadata = json.decode(row.metadata) or {},
            }
        end
        callback(result)
    end)
end

function RDE_DB_Insert(propId, itype, metadata)
    return MySQL.query.await(
        'INSERT INTO `' .. Config.DatabaseTable .. '` (`prop_id`, `type`, `metadata`) VALUES (?, ?, ?)',
        { propId, itype, json.encode(metadata or {}) }
    )
end

function RDE_DB_UpdateMeta(propId, metadata)
    return MySQL.query.await(
        'UPDATE `' .. Config.DatabaseTable .. '` SET `metadata` = ? WHERE `prop_id` = ?',
        { json.encode(metadata), propId }
    )
end

function RDE_DB_Delete(propId)
    return MySQL.query.await(
        'DELETE FROM `' .. Config.DatabaseTable .. '` WHERE `prop_id` = ?',
        { propId }
    )
end

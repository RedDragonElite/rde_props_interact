fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'rde_props_interact'
author      'RedDragonElite | SerpentsByte'
version     '1.0.5'
description 'Stash + Crafting interaction layer for rde_props'
repository  'https://github.com/RedDragonElite/rde_props_interact'

dependencies {
    '/server:7290',
    'oxmysql',
    'ox_core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'rde_props',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'shared/types.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
}

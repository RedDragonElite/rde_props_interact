# 🔓 RDE Props Interact — Stash & Crafting Layer

[![Version](https://img.shields.io/badge/version-1.0.5-red?style=for-the-badge&logo=github)](https://github.com/RedDragonElite/rde_props_interact)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](LICENSE)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)](https://github.com/communityox/ox_core)
[![Requires](https://img.shields.io/badge/requires-rde__props-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_props)
[![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_props_interact)

**Turn any rde_props prop into a lockable stash or crafting station — with crack mechanics, passcode locks, minigame skillchecks, and full recipe systems.**  
Zero core modifications. Drop-in. Drop-out. Free forever.

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte*

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [How It Works](#-how-it-works)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Stash System](#-stash-system)
- [Crafting System](#-crafting-system)
- [Lock & Crack System](#-lock--crack-system)
- [Admin System](#-admin-system)
- [Developer API](#-developer-api)
- [Database](#-database)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [License](#-license)

---

## 🎯 Overview

**rde_props_interact** is a gameplay addon for [rde_props](https://github.com/RedDragonElite/rde_props) that transforms static props into interactive RP objects.

Place a safe → configure it as a lockable stash → players can crack it, enter a passcode, or own it exclusively.  
Place a table → configure it as a crafting station → assign recipes, set skillchecks, and make drugs.

No other prop system on the market does this natively for ox_core. **Free. Open. Yours.**

### Why rde_props_interact?

| Feature | Paid Scripts | rde_props_interact |
|---|---|---|
| Stash any prop | ❌ | ✅ |
| Lock types (Owner/Job/Group/Code) | ❌ | ✅ |
| Crack mechanics + minigame skillchecks | ❌ | ✅ |
| Crafting station on any prop | ❌ | ✅ |
| Hybrid auto-config + manual | ❌ | ✅ |
| Separate DB (no core changes) | ❌ | ✅ |
| Police alert on crack attempt | ❌ | ✅ |
| Passcode hashing | ❌ | ✅ |
| Rate limiting + cooldowns | ❌ | ✅ |
| Auto-configure by model | ❌ | ✅ |
| Price | 💸 Paid | ✅ Free forever |

---

## ✨ Features

### 📦 Stash System
- Any placed prop becomes a persistent ox_inventory stash
- Stash ID bound to **Prop ID** — never to coords, survives every reload
- Configurable slots and max weight per stash
- Auto-stash for predefined models (`Config.AutoStashModels`)

### 🔐 Lock System
- **None** — always open
- **Owner** — only the player who placed/configured it
- **Job** — specific ox_core job
- **Group** — specific ox_core group
- **Passcode** — numeric code, stored hashed in DB

### 🔓 Crack System
- Three difficulties: Easy / Medium / Hard
- ox_lib progressbar + **minigame skillcheck** chain per difficulty
- Per-prop, per-player cooldown (no spam)
- **Police alert fires on crack attempt** — not just success
- Auto-relock after configurable time (`Config.CrackRelockTime`)

### ⚗️ Crafting System
- Any prop becomes a crafting station
- Global recipe sets per model (`Config.AutoCraftingModels`)
- Per-prop custom recipe set override via admin menu
- ox_lib progressbar + optional **minigame skillcheck** per recipe
- Full input validation and item removal server-side

### 🎮 Minigame Skillchecks
- Integrated ox_lib skillCheck with WASD key inputs
- Three difficulty profiles with customizable area sizes and speed multipliers
- Crack attempts and crafting can both require skillchecks
- Fail = cooldown, no item loss exploit possible

### 🛡️ Security
- Server-side distance check on all stash/craft interactions
- Rate limiting on configure, craft, and crack events
- Passcode hashed client-side before transmission
- No exploitable client-authoritative actions
- Admin check: ox_core groups + ace permissions + hasPermission fallback

---

## 🔧 How It Works

rde_props_interact hooks into rde_props **without modifying a single line** of its code:

1. Listens to `AddStateBagChangeHandler('rde_prop_', ...)` — when rde_props spawns/updates a prop, the addon detects it
2. Checks if that prop has interact data in its own DB table (`rde_props_interact`)
3. If yes → attaches options via `ox_target:addLocalEntity` directly to the **same entity** — options appear in the same ox_target menu alongside rde_props' own options (Info, Delete, etc.)
4. Auto-configure: if the prop model matches `Config.AutoStashModels` or `Config.AutoCraftingModels`, the prop is automatically configured on placement
5. All interact state is synced via GlobalState StateBags separately from rde_props

This means rde_props_interact is **fully optional** — remove it and rde_props runs exactly as before.

---

## 📦 Dependencies

| Resource | Required | Notes |
|---|---|---|
| [rde_props](https://github.com/RedDragonElite/rde_props) | ✅ Required | Core prop system |
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ Required | Database layer |
| [ox_core](https://github.com/communityox/ox_core) | ✅ Required | Player/character framework |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ Required | UI, skillcheck, progressbar |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ Required | Stash registration |
| [ox_target](https://github.com/communityox/ox_target) | ✅ Required | Prop interaction zones |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_props_interact.git
```

### 2. Add to `server.cfg`

```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_inventory
ensure ox_target
ensure rde_props
ensure rde_props_interact
```

> **Order matters.** `rde_props_interact` must start **after** `rde_props` and all shared dependencies.

### 3. Database

The `rde_props_interact` table is created automatically on first start. No manual SQL import needed.

### 4. Configure

Edit `config.lua` to set your auto-models, recipe sets, lock defaults, and police job name.

### 5. Restart

```
restart rde_props_interact
```

Then place a prop with `/props`, look at it, and use ox_target — you'll see the ⚙️ Configure Interaction option if you're an admin, or ⚗️ Crafting / 📦 Open Stash if the prop is auto-configured.

---

## ⚙️ Configuration

### General

```lua
Config.Debug           = false
Config.DatabaseTable   = 'rde_props_interact'
Config.StashPrefix     = 'rde_prop_'         -- stashId = rde_prop_{propId}
Config.CrackPoliceAlert = true
Config.CrackPoliceJob   = 'police'
Config.CrackRelockTime  = 300000             -- 5 minutes after crack
```

### Important: StateBag Prefix

```lua
-- MUST match rde_props config.lua → Config.StatebagPrefix
-- rde_props uses 'rde_prop_' (underscore!)
Config.PropsStatebagPrefix = 'rde_prop_'
```

### Admin Groups

Must match your `rde_props` config. Additionally supports ace permissions as fallback:

```lua
Config.AdminGroups = {
    ['admin']      = true,
    ['superadmin'] = true,
    ['moderator']  = true,
    ['owner']      = true,
}

Config.AdminAce = 'command'  -- FiveM ace permission fallback (set false to disable)
```

### Auto-Stash Models

Props placed with these models are automatically configured as stashes:

```lua
Config.AutoStashModels = {
    ['prop_safety_case_01'] = {
        slots     = 10,
        maxWeight = 5000,
        lockType  = RDE_INTERACT.LOCK.OWNER,
        crackDiff = RDE_INTERACT.CRACK.MEDIUM,
    },
}
```

### Auto-Crafting Models

Props placed with these models are automatically configured as crafting stations:

```lua
Config.AutoCraftingModels = {
    ['prop_weed_table_01'] = 'weed_table',  -- value = recipeSetId
}
```

### Recipe Sets

```lua
Config.RecipeSets = {
    ['weed_table'] = {
        label   = '🌿 Weed Processing Table',
        recipes = {
            {
                id         = 'baggy_weed_small',
                label      = 'Small Baggy Weed',
                inputs     = { ['dry_cannabis'] = 3, ['empty_baggy'] = 1 },
                output     = { item = 'baggy_weed_small', count = 1 },
                time       = 6000,          -- progressbar duration (ms)
                skillCheck = 'easy',        -- 'none' / 'easy' / 'medium' / 'hard'
            },
        },
    },
}
```

---

## 📦 Stash System

### How stashes work

1. Admin places a prop with `/props`
2. Looks at prop → ox_target → **⚙️ Configure Interaction** → **📦 Set as Stash**
3. Fills in label, slots, weight, lock type, crack difficulty
4. Stash is registered with ox_inventory as `rde_prop_{propId}`
5. Other players see **📦 Open Stash** option (if unlocked) or **🔓 Crack** / **🔑 Enter Passcode**

### Stash persistence

- Stash content is stored by ox_inventory using the stash ID
- Stash ID is always `rde_prop_{propId}` — the same prop ID from the DB
- Deleting the prop removes the interact config; stash contents persist in ox_inventory until manually cleared

---

## ⚗️ Crafting System

### How crafting works

1. Admin places a prop (or it auto-configures based on model)
2. Configures it as a crafting station → selects recipe set
3. Players see **⚗️ [Station Name]** in ox_target
4. Menu shows all available recipes with input/output preview
5. Player selects recipe → progressbar → optional minigame skillcheck → items exchanged server-side

### Adding custom recipes

Add a new recipe set to `config.lua`:

```lua
Config.RecipeSets['my_workbench'] = {
    label   = '🔧 Custom Workbench',
    recipes = {
        {
            id         = 'custom_item',
            label      = 'My Custom Item',
            inputs     = { ['iron_scrap'] = 5, ['wire'] = 2 },
            output     = { item = 'custom_gadget', count = 1 },
            time       = 8000,
            skillCheck = 'medium',
        },
    },
}
```

Then assign it to a model in `Config.AutoCraftingModels` or select it manually in the admin configure menu.

---

## 🔓 Lock & Crack System

### Lock types

| Type | Who can open |
|---|---|
| `none` | Everyone |
| `owner` | The player whose identifier is stored as owner |
| `job` | Any player with the specified ox_core job |
| `group` | Any player with the specified ox_core group |
| `passcode` | Anyone who enters the correct numeric code |

### Crack difficulties

| Difficulty | Progressbar | Minigame Skillchecks | Cooldown after fail |
|---|---|---|---|
| Easy | 5s | 1 check (large zone) | 15s |
| Medium | 10s | 2 checks | 15s |
| Hard | 20s | 3 checks (tight zones) | 15s |

### Police alert

When `Config.CrackPoliceAlert = true`, all online players with `Config.CrackPoliceJob` receive a notification on crack **attempt** — including the coordinates. Adapt the alert handler in `client/main.lua` to match your dispatch system (ps-dispatch, ox_lib dispatch, etc.).

---

## 🛡️ Admin System

Admins (detected via ox_core groups, ace permissions, or `hasPermission`) can:

- See **⚙️ Configure Interaction** on any placed prop
- Set prop as Stash or Crafting Station
- Remove interact configuration
- Bypass all lock restrictions when opening stashes

Admin detection mirrors `rde_props` exactly: ace permissions → `hasPermission('admin')` → `getGroups()` check.

---

## 🔧 Developer API

### Server Events (trigger from other resources)

```lua
-- Force-delete interact data for a prop (e.g. when your resource deletes a prop)
TriggerEvent('rde_interact:propDeleted', propId)
```

### Client Events (listen in other resources)

```lua
-- Fires when interact data is synced/updated for a prop
AddEventHandler('rde_interact:sync', function(propId, data)
    -- data = { type = 'stash'|'crafting', metadata = {...} }
end)

-- Fires when interact data is removed for a prop
AddEventHandler('rde_interact:remove', function(propId)
end)
```

### Server Callback

```lua
-- Check if a player is admin (from client)
local isAdmin = lib.callback.await('rde_interact:isAdmin', false)
```

### GlobalState Keys

```lua
-- Read interact data for any prop from client or server
local data = GlobalState['rde_interact:' .. propId]
-- data = { propId, type, metadata } or nil
```

---

## 🗄️ Database

Table auto-created on first start — never touches `rde_props` table:

```sql
CREATE TABLE IF NOT EXISTS `rde_props_interact` (
    `prop_id`    VARCHAR(64)              NOT NULL PRIMARY KEY,
    `type`       ENUM('stash','crafting') NOT NULL,
    `metadata`   LONGTEXT                 NOT NULL DEFAULT '{}',
    `created_at` TIMESTAMP                DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP                DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 🐛 Troubleshooting

**Target options not showing on props?**  
Ensure `rde_props_interact` starts after `rde_props` in your `server.cfg`. Check F8 console for version output — must show `v1.0.5`. Enable `Config.Debug = true` for verbose logging. Verify `Config.PropsStatebagPrefix` matches your rde_props `Config.StatebagPrefix` (default: `'rde_prop_'` with underscore).

**Stash opens but is empty after restart?**  
Stash content is stored by ox_inventory. Ensure ox_inventory is running and the stash ID (`rde_prop_{propId}`) matches. Run `/reloadprops` in rde_props to re-register stashes.

**Crack attempt fires but no police alert?**  
Check `Config.CrackPoliceJob` matches your ox_core job name exactly. Verify the officer has the correct job assigned. Adapt the alert handler in `client/main.lua` for your dispatch system.

**Passcode always says wrong?**  
Passcode is hashed on the client before sending. If you set a passcode before v1.0.5, it may have been double-hashed — delete and re-configure the prop to reset.

**Configure option not showing (admin)?**  
Admin detection uses ace permissions, `hasPermission`, and ox_core groups. Check your `server.cfg` for `add_ace` and your ox_core group assignments. Set `Config.AdminAce = 'command'` to use FiveM's default ace.

**Entity not found / interact options missing on dense props?**  
The 3-stage entity retry covers most cases. If a specific prop model causes issues, increase the search radius in the Stage 3 fallback in `client/main.lua` (`dist < 3.0`).

---

## 📝 Changelog

### v1.0.5 — Current
- ✅ **ROOT FIX:** StateBag prefix corrected from `rde_prop:` to `rde_prop_` (underscore) — matches rde_props
- ✅ **ROOT FIX:** Switched from `addBoxZone` to `addLocalEntity` — interact options now appear in the **same ox_target menu** as rde_props options
- ✅ `@ox_core/lib/init.lua` in shared_scripts — identical to rde_props fxmanifest
- ✅ Admin detection matches rde_props exactly: ace → hasPermission → getGroups
- ✅ Auto-configure props based on model (`Config.AutoStashModels` / `Config.AutoCraftingModels`)
- ✅ `lib.callback` for server-authoritative admin check
- ✅ Zone refresh after first configure (immediate feedback)
- ✅ Minigame skillchecks working for both crack and crafting

### v1.0.4
- ✅ Removed `@ox_core/imports.lua` (file doesn't exist)
- ✅ `require '@ox_core.lib.init'` as alternative import method
- ✅ Ace permission fallback for admin detection
- ✅ Auto-configure system (first implementation)

### v1.0.1
- ✅ 3-stage entity-finding retry (1.5m → 3.0m → GamePool filter)
- ✅ Passcode hashed client-side + stored hashed in DB
- ✅ Crack cooldown system — per-prop, per-player
- ✅ Server-side distance check on openStash, passcode, craft
- ✅ Police alert fires on crack ATTEMPT, not just success
- ✅ Rate limiting on configure / craft / crack events

### v1.0.0 — Initial release
- Stash system with Owner/Job/Group/Passcode locks
- Crack system with Easy/Medium/Hard difficulties
- Crafting system with hybrid auto-model + per-prop recipe sets
- Separate DB table — zero core modifications to rde_props
- StateBag-based sync

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit: `git commit -m 'Add your feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

Guidelines: follow existing Lua style, comment non-obvious logic, test on a live server, update docs for new features.

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE_PROPS_INTERACT v1.0.5 (STASH & CRAFTING LAYER FOR FIVEM)      #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   ORIGIN:     https://github.com/RedDragonElite                                 #
#                                                                                 #
#   WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS #
#                                                                                 #
#   [ THE RULES OF THE GAME ]                                                     #
#                                                                                 #
#   1. // THE "FUCK GREED" PROTOCOL (FREE USE)                                    #
#      You are free to use, edit, and abuse this code on your server.             #
#      Learn from it. Break it. Fix it. That is the hacker way.                   #
#      Cost: 0.00€. If you paid for this, you got scammed by a rat.               #
#                                                                                 #
#   2. // THE TEBEX KILL SWITCH (COMMERCIAL SUICIDE)                              #
#      Listen closely, you parasites:                                             #
#      If I find this script on Tebex, Patreon, or in a paid "Premium Pack":      #
#      > I will DMCA your store into oblivion.                                    #
#      > I will publicly shame your community.                                    #
#      > I hope your server lag spikes to 9999ms every time you blink.            #
#      SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.                            #
#                                                                                 #
#   3. // THE CREDIT OATH                                                         #
#      Keep this header. If you remove my name, you admit you have no skill.      #
#      You can add "Edited by [YourName]", but never erase the original creator.  #
#      Don't be a skid. Respect the architecture.                                 #
#                                                                                 #
#   4. // THE CURSE OF THE COPY-PASTE                                             #
#      This addon hooks into rde_props via StateBags and ox_target.               #
#      If you rip it out of context without reading, it WILL break.               #
#      Don't come crying to my DMs. RTFM or learn to code.                        #
#                                                                                 #
#   --------------------------------------------------------------------------    #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
#   --------------------------------------------------------------------------    #
###################################################################################
```

**TL;DR:**
- ✅ Free forever — use it, edit it, learn from it
- ✅ Keep the header — credit where it's due
- ❌ Don't sell it — commercial use = instant DMCA
- ❌ Don't be a skid — context matters, read the code

---

## 🌐 Community & Support

| | |
|---|---|
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr (RDE) | [RedDragonElite](https://primal.net/p/nprofile1qqsv8km2w8yr0sp7mtk3t44qfw7wmvh8caqpnrd7z6ll6mn9ts03teg9ha4rl) |
| 🔵 Nostr (Shin) | [SerpentsByte](https://primal.net/p/nprofile1qqs8p6u423fappfqrrmxful5kt95hs7d04yr25x88apv7k4vszf4gcqynchct) |
| 🏗️ rde_props Core | [rde_props](https://github.com/RedDragonElite/rde_props) |
| 🚪 RDE Doors | [rde_doors](https://github.com/RedDragonElite/rde_doors) |
| 🚗 RDE Car Service | [rde_carservice](https://github.com/RedDragonElite/rde_carservice) |
| 🎯 RDE Skills | [rde_skills](https://github.com/RedDragonElite/rde_skills) |

**When asking for help, always include:**
- Full error from server console or txAdmin
- Your `server.cfg` resource start order
- rde_props + ox_core + ox_lib versions in use

---

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)

[⬆ Back to Top](#-rde-props-interact--stash--crafting-layer)

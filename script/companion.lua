local utils = require("utils") -- I don' t think I actually use anything from this currently but I might one day
local challenge_mode = settings.startup["set-challenge-mode"].value -- is the old challenge mode option enabled?
local mode = settings.startup["set-mode"].value -- Are we in normal (0), challenge (1), forgiving (2), or combined (3) mode?
local abandon_job_distance = 128 -- distance that we ignore jobs and follow the player instead
local follow_range = 12  -- how close we stick to the player
local sticker_life = 11  -- modifies flight speed (sorta, it's complicated)
local dist_bonus = 2     -- offset when setting job destination
local staging_step = 2   -- offset when stepping towards a job
local inner_margin = 2   -- offset when stopping on a job
local def_speed = 2.5    -- non challenge mode companion speed
local cmax = 12          -- max number of companions you can have simultaneously when fully upgraded in challenge mode; recommended min of 6
local lib = {}           -- predeclaration
local debug_mode = false -- enables debugging functionality (no gameplay difference)

--[[ TABLE OF CONTENTS ]]--
--[[
Line   31 Challenge mode stat control
Line  133 Initialization
Line  338 Utilities
Line 1345 Core Logic
Line 1765 Secondary Utilities
Line 2545 Migrations
Line 2754 Commands and Remotes
Last updated 3.1.0]]
--------------------------- Challenge Mode Stat Control ---------------------------

local function set_defaults()
    if not storage then storage = storage or {} end
    storage.companion_update_interval = settings.startup["set-update-interval"].value or 5
    storage.fuel_multiplier = 1
    storage.companion_speed_factor = storage.companion_speed_factor or 1.0
    storage.player_speed_factor = storage.player_speed_factor or {} 
    if mode == 1 or mode == 3 then -- shitty values to start with in challenge mode
        storage.base_speed                   = 0.5
        storage.attack_count                 = 0
        storage.max_distance                 = 24
        storage.max_companions               = 1
    else -- moderately good (but not best) values for non challenge mode players
        storage.base_speed                   = def_speed
        storage.attack_count                 = 8
        storage.max_distance                 = 100
        storage.max_companions               = 2
    end
end

local function ensure_companion_upgrades()
    if not storage then storage = {} end
    if not storage.companion_upgrades then storage.companion_upgrades = {} end
    if mode ~= 1 and mode ~= 3 then return end -- only use this table in challenge or combined mode
    if not storage.companion_upgrades or not next(storage.companion_upgrades) then
        storage.companion_upgrades = { -- if you change any of these, remember to change the defaults up there ^ too
            ["electronics"]             = {{stat="base_speed",     value=1,    phrase="I can move a little easier now."}},
            ["automobilism"]            = {{stat="base_speed",     value=1.75, phrase="Engine boost activated."}},
            ["robotics"]                = {{stat="base_speed",     value=2.5,  phrase="Now I can fly like those robots!"}},
            ["rocket-fuel"]             = {{stat="base_speed",     value=10,   phrase="Rocket fuel: max speed!"}},
            --Recommended do not touch; these values do not behave predictably and were dialed in with pure trial and error. 
            
            ["military"]                = {{stat="attack_count",   value=1,    phrase="Rudimentary weapons systems online."}},
            ["laser"]                   = {{stat="attack_count",   value=3,    phrase="Laser system repaired."}},
            ["stronger-explosives-2"]   = {{stat="attack_count",   value=7,    phrase="Weapons systems powered up."}},
            ["laser-weapons-damage-3"]  = {{stat="attack_count",   value=12,   phrase="Energy weapons at max."}},
            --How many laser particles it spawns with each attack; each particle always does the same damage
            
            ["logistics"]               = {{stat="max_distance",   value=48,   phrase="This will let me plan ahead better."}},
            ["lamp"]                    = {{stat="max_distance",   value=80,   phrase="I can see more clearly now."}},
            ["radar"]                   = {{stat="max_distance",   value=128,  phrase="Radar has extended my range to max."}},
            --How far the companion looks for construction jobs; highest value should not exceed abandon_job_distance
            
            ["processing-unit"]         = {{stat="max_companions", value=math.ceil(cmax/5),  phrase="Your suit can handle a friend now!"}},
            ["power-armor-mk2"]         = {{stat="max_companions", value=cmax, phrase="Your suit's fully upgraded: time to roll out the squad."}},
            --How many companions you can have simultaneously; change "cmax" at start of file, not this.

            -- Companion Shield upgrade tree
            ["energy-shield-equipment"] = {{
                stat="companion-shield-mk0", 
                value="companion-shield-mk1", 
                phrase="Shield partially repaired."
            }},
            ["energy-shield-mk2-equipment"] = {{
                stat="companion-shield-mk1", 
                value="companion-shield-mk2", 
                phrase="Additional shields online."
            }},
            ["fusion-reactor-equipment"] = {{
                stat="companion-shield-mk2", 
                value="companion-shield-mk3", 
                phrase="Shields fully operational."
            }},

            -- Companion Roboport upgrade tree
            ["logistic-science-pack"] = {{
                stat="companion-roboport-mk0", 
                value="companion-roboport-mk1", 
                phrase="Roboport partially repaired."
            }},
            ["construction-robotics"] = {{
                stat="companion-roboport-mk1", 
                value="companion-roboport-mk2", 
                phrase="Roboport upgrade online."
            }},
            ["logistic-robotics"] = {{
                stat="companion-roboport-mk2", 
                value="companion-roboport-mk3", 
                phrase="Roboport fully operational."
            }},
        }
    end
end

local stat_tables = {
    base_speed    = storage.base_speed,
    damage        = storage.attack_count,
    max_distance  = storage.max_distance,
    number_drones = storage.max_companions,
}
-- this table and function are so that each stat can be referenced dynamically (it avoids a gigantic if-then chain)
local function get_stats_for_tech(tech)
    local found = {}
    for stat, table in pairs(stat_tables) do
        if table[tech] then
            found[stat] = table[tech]
        end
    end
    return found
end

--------------------------- Initialization ---------------------------

local script_data =
{
    companions = {},
    active_companions = {},
    player_data = {},
    search_schedule = {},
    specific_job_search_queue = {}
}

local function bind_storage()
    if not storage.companion then
        storage.companion = script_data
    else
        script_data = storage.companion
    end
end

lib.on_init = function()
    set_defaults()
    ensure_companion_upgrades()
    storage.companion = storage.companion or script_data
    storage.companion_update_interval = settings.startup["set-update-interval"].value or 5
    local force = game.forces.player
    if force.max_failed_attempts_per_tick_per_construction_queue == 1 then
        force.max_failed_attempts_per_tick_per_construction_queue = 4
    end
    if force.max_successful_attempts_per_tick_per_construction_queue == 3 then
        force.max_successful_attempts_per_tick_per_construction_queue = 8
    end
    bind_storage()
end

local repair_tools
local get_repair_tools = function()
    if repair_tools then
        return repair_tools
    end
    repair_tools = {}
    for k, item in pairs (prototypes.item) do
        if item.type == "repair-tool" then
            repair_tools[item.name] = true
        end
    end
    return repair_tools
end

local fuel_items
local get_fuel_items = function(player)
    local fuel_items = {}
    for k, item in pairs(prototypes.item) do
        if item.fuel_value > 0 and item.fuel_category == "chemical" then
            table.insert(fuel_items, {name = item.name, count = 1, fuel_top_speed_multiplier = item.fuel_top_speed_multiplier})
        end
    end

    local use_best_fuel_first = settings.get_player_settings(player)["set-fuel-preference"].value
    table.sort(fuel_items, function(a, b)
        if use_best_fuel_first then
            return a.fuel_top_speed_multiplier > b.fuel_top_speed_multiplier
        else
            return a.fuel_top_speed_multiplier < b.fuel_top_speed_multiplier
        end
    end)

    return fuel_items
end

local function set_companion_stats(player)
    ensure_companion_upgrades()
    local force = player.force
    local techs = force.technologies

    local best_values = {}

    for tech, upgrades in pairs(storage.companion_upgrades) do
        if techs[tech] and techs[tech].researched then
            local upgrade = upgrades[1]
            local stat, value = upgrade.stat, upgrade.value
            if not best_values[stat] or value > best_values[stat] then
                best_values[stat] = value
            end
        end
    end
    storage.base_speed    = best_values.base_speed or storage.base_speed
    storage.attack_count  = best_values.attack_count or storage.attack_count
    storage.max_distance  = best_values.max_distance or storage.max_distance
    storage.number_drones = best_values.number_drones or storage.number_drones
end

local get_companion = function(unit_number)

    local companion = unit_number and script_data.companions[unit_number]
    if not companion then return end

    if not companion.entity.valid then
        companion:on_destroyed()
        return
    end

    return companion
end

local name = "secret_companion_surface_please_don't_touch"
local get_secret_surface = function()
    local surface = game.surfaces[name]
    if surface then
        return surface
    end
    surface = game.create_surface(name, {height = 1, width = 1})
    return surface
end

local rotate_vector = function(vector,    orientation)
    local x = vector[1] or vector.x
    local y = vector[2] or vector.y
    local angle = (orientation) * math.pi * 2
    return
    {
        x = (math.cos(angle) * x) - (math.sin(angle) * y),
        y = (math.sin(angle) * x) + (math.cos(angle) * y)
    }
end

local get_player_speed = function(player, boost)
    local boost = boost or 10.0 
    if player.vehicle then
        return math.abs(player.vehicle.speed) * boost
    end

    if player.character then
        return player.character_running_speed * boost
    end

    return 0.3

end

local Companion = {}
Companion.metatable = {__index = Companion}

Companion.new = function(entity, player)
    local player_data = script_data.player_data[player.index]
    if not player_data then
        player_data = {
            companions = {},
            last_job_search_offset = 0,
            last_attack_search_offset = 0
        }
        script_data.player_data[player.index] = player_data
        player.set_shortcut_available("companion-construction-toggle", true)
        player.set_shortcut_available("companion-attack-toggle", true)
        if mode == 1 or mode == 3 then
            player.set_shortcut_toggled("companion-attack-toggle", false)
        end
    end

    local count = 0
    for _ in pairs(player_data.companions) do count = count + 1 end
    if count >= storage.max_companions then
        if count == 1 then
			player.print("Your in-suit controller can't handle another friend just now.")
		elseif count == cmax then
			player.print("Your in-suit controller can only handle " .. cmax .. " of us at once!")
		else
			player.print("Your in-suit controller can't handle more than " .. storage.max_companions .. " companions for now.")
		end
        if entity and entity.valid then
			local inserted = player.insert{name = entity.name, count = 1}
			if inserted == 0 then
				-- NEEDS FIX: If player inventory is full, just drop it on the ground
				entity.surface.spill_item_stack(entity.position, {name = entity.name, count = 1}, true, player.force, false)
			end
			entity.destroy()
		end
        return
    end

    player.request_translation({"idle-line.0"})
    player_data.companions[entity.unit_number] = true

    local companion = {
        entity = entity,
        player = player,
        unit_number = entity.unit_number,
        robots = {},
        flagged_for_equipment_changed = true,
        last_attack_tick = 0,
        job_done_pending = false,
        speed = 0,
        last_idle_line_tick = 0,
        next_forced_idle_tick = 18000,
		last_robot_count = 0
    }

    set_companion_stats(player)
    setmetatable(companion, Companion.metatable)
    script_data.companions[entity.unit_number] = companion
    script.register_on_object_destroyed(entity)

    companion:try_to_refuel()
    companion:set_active()
end

--------------------------- Utilities ---------------------------

local adjust_follow_behavior = function(player)
    local player_data = script_data.player_data[player.index]
    if not player_data then return end
    local count = 0
    local guys = {}

    local surface = player.physical_surface

    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            if not companion.active and (companion.entity.surface == surface) then
                count = count + 1
                guys[count] = companion
            end
        end
    end

    if count == 0 then return end
    local reach = player.reach_distance - 2
    local length = math.min(5 + (count * 0.33), reach)
    if count == 1 then length = 2 end
    local dong = 0.75 + (0.5 / count)
    local shift = {x = 0, y =0}
    local speed = get_player_speed(player, 1.0)
    if player.vehicle then
        local orientation = player.vehicle.orientation
        dong = dong + orientation
        shift = rotate_vector({0, -speed * 15}, orientation)
    elseif player.character then
        local walking_state = player.character.walking_state
        if walking_state.walking then
            shift = rotate_vector({0, -speed * 15}, walking_state.direction / 8)
        end
    end

    local offset = {length, 0}
    local position = player.physical_position
    for k, companion in pairs (guys) do
        local angle = (k / count) + dong
        local follow_offset = rotate_vector(offset, angle)
        follow_offset.x = follow_offset.x + shift.x
        follow_offset.y = follow_offset.y + shift.y
        local target = companion.entity.follow_target
        if not (target and target.valid) then
            if player.character then
                companion.entity.follow_target = player.character
            else
                companion.entity.autopilot_destination = {position.x + follow_offset.x, position.y + follow_offset.y}
            end
        end
        -- stupid solution but if it works ... is it really stupid?
        if follow_offset and follow_offset.x and follow_offset.y and follow_offset.x <= 10000 and follow_offset.y <= 10000 then
            companion.entity.follow_offset = follow_offset
        end
        companion:set_speed(speed + companion:get_distance_boost(companion.entity.autopilot_destination))
        companion:try_to_refuel()
    end
end

function Companion:_job_distance_and_range(target)
    local t = target or self.current_job_target
    if not t then return nil, nil end
    local tx = t.x or t[1]
    local ty = t.y or t[2]
    local p  = self.entity.position
    local dx = tx - p.x
    local dy = ty - p.y
    local d  = math.sqrt(dx*dx + dy*dy)
    local reach = (storage and storage.max_distance) or 24
    return d, reach
end

function Companion:_inside_job_zone(margin)
    local d, reach = self:_job_distance_and_range()
    if not d then return false end
    margin = margin or inner_margin
    return d <= math.max(0, reach - margin)
end

local function eff_base()
    if mode ~=1 and mode ~=3 then return def_speed end
    if not storage.companion_speed_factor then
        storage.companion_speed_factor = 1.0
    end
    return (storage.base_speed) * (storage.companion_speed_factor)
end

local get_speed_boost = function(burner)
    local burning = burner and burner.currently_burning
    if not burning then return 1 end
    storage.fuel_multiplier = storage.fuel_multiplier or 1
    return (burning.fuel_top_speed_multiplier or 1) * storage.fuel_multiplier
end

function Companion:can_spawn_robot()
    return table_size(self.robots or {}) < (storage.scripted_robot_limit or 69)
end

function Companion:set_robot_stack()
    local inventory = self:get_inventory()
    if not inventory.set_filter(21,"companion-construction-robot") then
        inventory[21].clear()
        inventory.set_filter(21,"companion-construction-robot")
    end

    if self.can_construct and self:player_wants_construction() then
        inventory[21].set_stack({name = "companion-construction-robot", count = 100})
    else
        inventory[21].clear()
    end
end

function Companion:clear_robot_stack()
    local inventory = self:get_inventory()
    if not inventory.set_filter(21,"companion-construction-robot") then
        inventory[21].clear()
        inventory.set_filter(21,"companion-construction-robot")
    end
    inventory[21].clear()
end

function Companion:set_active()
    self:set_robot_stack()
    self.flagged_for_equipment_changed = true
    local mod = self.unit_number % storage.companion_update_interval
    local list = script_data.active_companions[mod]
    if not list then
        list = {}
        script_data.active_companions[mod] = list
    end
    list[self.unit_number] = true
    self.active = true
    self:set_speed((eff_base() * 1.2) * get_speed_boost(self.entity.burner))
    adjust_follow_behavior(self.player)
end

function Companion:clear_active()
    if not self.active then return end
    if not self.out_of_energy then
        local pending_job_line = self.job_done_tick and not self.job_done_announced
        if pending_job_line and game.tick - self.job_done_tick < 10 then
            if math.random(1, 20) > 15 then
                self:say_random("search-for-nearby-work-line")
            end
            self.job_done_announced = true
            self.job_done_tick = nil
        end
    end
    local mod = self.unit_number % storage.companion_update_interval
    local list = script_data.active_companions[mod]
    if not list then
        error("companion clear_active()")
        return
    end
    list[self.unit_number] = nil
    if not next(list) then
        script_data.active_companions[mod] = nil
    end
    self.active = false
    self:clear_robots()
    adjust_follow_behavior(self.player)
    self.next_idle_line_tick = nil
    self.test_idle_tick = nil
    self.test_idle_fired = nil
    self.job_done_tick = nil
   
    return
end

function Companion:clear_speed_sticker()
    if not self.speed_sticker then return end
    self.speed_sticker.destroy()
    self.speed_sticker = nil
end

function Companion:get_speed_sticker()
    if self.speed_sticker and self.speed_sticker.valid then
        return self.speed_sticker
    end
    self.speed_sticker = self.entity.surface.create_entity{
        name   = "speed-sticker",
        target = self.entity,
        force  = self.entity.force,
        position = self.entity.position,
    }
    if self.speed_sticker then self.speed_sticker.active = true end
    return self.speed_sticker
end

function Companion:get_distance_boost(position)
    local distance = self:distance(position)
    return (distance / 10)
end


function Companion:clear_speed_fx()
    local fx = self.speed_fx
    if fx and fx.valid then
        fx.destroy()
    end
    self.speed_fx = nil
end

function Companion:get_speed_fx()
    local fx = self.speed_fx
    if fx and fx.valid then
        return fx
    end
    -- cached handle is missing or dead ? recreate
    self.speed_fx = rendering.draw_animation{
        animation    = "companion-speed-flame",
        target       = self.entity,
        surface      = self.entity.surface,
        render_layer = "object",
    }
    return self.speed_fx
end

function Companion:set_speed(speed)
    local factor = storage.companion_speed_factor or 1.0
    self.speed = speed
    self._last_speed_factor = factor
    if not storage.base_speed then storage.base_speed = 10 end

    -- Measure actual movement since last call (tiles/tick)
    local pos = self.entity.position
    local tick = game.tick
    local v = 0
    if self._last_pos and self._last_pos_tick then
        local dt = tick - self._last_pos_tick
        if dt > 0 then
            local dx = pos.x - self._last_pos.x
            local dy = pos.y - self._last_pos.y
            v = math.sqrt(dx*dx + dy*dy) / dt
        end
    end
    self._last_pos = pos
    self._last_pos_tick = tick

    if v > 0.015 then
        local sticker = self:get_speed_sticker()
        if sticker and sticker.valid then
            sticker.time_to_live = 11
            sticker.active = true
        end
        local fx = self:get_speed_fx()
        if fx and fx.valid then
            fx.time_to_live = 11

            local S_MIN  = 0.25   -- size at near-zero speeds
            local S_MAX  = 1.33   -- size cap at high speeds
            local V_FULL = 0.11   -- v where scale ~~ 1.0 (5 tiles/s)
            local SENS   = 10.0   -- speed of size rise over velocity

            local GAIN = (1.0 - S_MIN) / math.log(1 + SENS * V_FULL)
            local s = S_MIN + GAIN * math.log(1 + SENS * v)
            if s > S_MAX then s = S_MAX end

            fx.x_scale = s
            fx.y_scale = s
        end
    else
        self:clear_speed_sticker()
        self:clear_speed_fx()
    end
end

function Companion:get_speed()
    return self.speed
end

function Companion:get_grid()
    return self.entity.grid
end

function Companion:clear_passengers()

    if self.driver and self.driver.valid then
        self.driver.destroy()
        self.driver = nil
    end

    if self.passenger and self.passenger.valid then
        self.passenger.destroy()
        self.passenger = nil
    end

end

function Companion:check_equipment()
    self.flagged_for_equipment_changed = nil

    local grid = self:get_grid()

    -- Check for roboport equipment first
    self.can_construct = false
    for k, equipment in pairs (grid.equipment) do
        if equipment.type == "roboport-equipment" then
			if equipment.name:find("^companion%-roboport") then
				self.can_construct = true
				break
			elseif equipment.name:find("^personal%-roboport") then
				self:say("I can't use this, this roboport is for you!")
				break
			end
		end
    end

    -- Only set robot stack if we have a roboport
    if self.can_construct then
        local network = self.entity.logistic_network
        local max_robots = (network and network.robot_limit) or 100
        if max_robots > 0 then
            self:set_robot_stack()
        else
            self.can_construct = false
        end
    else
        self:clear_robots()
		self:return_to_player()
    end

    self.can_attack = false
    for k, equipment in pairs (grid.equipment) do
        if equipment.type == "companion-defense-equipment" then
            self.can_attack = true
            break
        end
    end
end

function Companion:robot_spawned(robot)
    if not (robot and robot.valid) then return end
    local id = robot.unit_number
    self:set_active()
    self.robots[id] = robot
    if robot.valid then
        robot.destructible = false
        robot.minable = false
    end
    if self.entity and self.entity.valid and robot.valid then
        self.entity.surface.create_entity{
            name = "inserter-beam",
            position = self.entity.position,
            target = robot,
            source = self.entity,
            force = self.entity.force,
            source_offset = {0, 0}
        }
    end
    self:move_to_robot_average()
end

function Companion:clear_robots()
    for k, robot in pairs(self.robots) do
        local r = robot
        if r and r.valid then
            local ok = pcall(function()
                r.mine{
                    inventory      = self:get_inventory(),
                    force          = true,
                    ignore_minable = true
                }
            end)
            if not ok and r.valid then
                r.destroy()
            end
        end
        local beam_ok, beam = pcall(function() return robot.beam end)
        if beam_ok and beam and beam.valid then
            beam.destroy()
        end
        self.robots[k] = nil
    end
    self:clear_robot_stack()
end

function Companion:move_to_robot_average()
    if not next(self.robots) then return false end

    local position = { x = 0, y = 0 }
    local count = 0
    for k, robot in pairs(self.robots) do
        if robot and robot.valid then
            local rp = robot.position
            position.x = position.x + rp.x
            position.y = position.y + rp.y
            count = count + 1
        else
            self.robots[k] = nil
        end
    end
    if count == 0 then return false end

    position.x = position.x / count
    position.y = position.y / count
    self.entity.autopilot_destination = position
    return true
end

function Companion:try_to_refuel()
    if not self:get_fuel_inventory().is_empty() or self.entity.energy > 0 then return end
	self:say("Refueling...")
    if self:distance(self.player.physical_position) <= follow_range then
        for k, item in pairs (get_fuel_items(self.player)) do
            if self:find_and_take_from_player({name = item.name, count = item.count}) then
                return
            end
        end
    end
    return true
end

function Companion:update_state_flags()
    self.out_of_energy = self:try_to_refuel()
    self.is_in_combat = (game.tick - self.last_attack_tick) < 60
    self.is_on_low_health = self.entity.get_health_ratio() < 0.7
    self.is_busy_for_construction = not not (self.is_in_combat or self:move_to_robot_average() or self.moving_to_destination)
    -- "not not" coerces it into a strict true/false result, never just truthy or falsey 
    self.is_getting_full = self:get_inventory()[16].valid_for_read
end

function Companion:search_for_nearby_work()
    if not self:player_wants_construction() or not self.can_construct then return end
    if self.entity.surface ~= self.player.physical_surface then return end
	local radius = storage.max_distance or 100
	local origin = self.entity.position
	local area = {{origin.x - radius, origin.y - radius}, {origin.x + radius, origin.y + radius}}
	self:try_to_find_work(area)
end

function Companion:search_for_nearby_targets()
    if not self:player_wants_attack() then return end
    if not self.can_attack then return end
    if self.entity.surface ~= self.player.physical_surface then return end
    local range = 32
    local origin = self.entity.position
    local area = {{origin.x - range, origin.y - range}, {origin.x + range, origin.y + range}}
    --self:say("NICE")
    self:try_to_find_targets(area)
end

function Companion:is_idle()
    -- are we currently working?
    return not self.is_in_combat or not self.is_busy_for_construction
end

function Companion:is_busy()
    -- are we doing ANYthing at all?
    return self.is_in_combat or self.is_busy_for_construction or self.moving_to_destination
end

function Companion:say(text)
	if not settings.startup["companion-voice-lines"].value then return end
    local tick_value = 0
    local live_value = 0
    if debug_mode then -- when debugging, text is short lived and rapid firing
        tick_value = 1 
        live_value = 30 
    else -- otherwise text lasts 4 seconds and can only fire twice per second
        tick_value = 30 
        live_value = 240 
    end
    if (game.tick - (self.last_spoken_tick or 0)) <= tick_value then return end 
    self.last_spoken_tick = game.tick
    self.player.create_local_flying_text{
        position = {x = self.entity.position.x, y = self.entity.position.y - 2.5},
        text = text or "Error",
        color = {r = 0.4, g = 0.8, b = 1},
		time_to_live = live_value,
		speed = 0.5
    }
end

function Companion:on_destroyed()
    if not script_data.companions[self.unit_number] then
        --On destroyed has already been called.
        return
    end

	for k, robot in pairs(self.robots) do
		local r = robot
		if r and r.valid then 
            r.destroy() 
        end
	end

    script_data.companions[self.unit_number] = nil
    local player_data = script_data.player_data[self.player.index]

    player_data.companions[self.unit_number] = nil

    if not next(player_data.companions) then
        script_data.player_data[self.player.index] = nil
        self.player.set_shortcut_available("companion-attack-toggle", false)
        self.player.set_shortcut_available("companion-construction-toggle", false)
    end

    adjust_follow_behavior(self.player)
end

function Companion:distance(position)
    local source = self.entity.position
    local x2 = position[1] or position.x
    local y2 = position[2] or position.y
    return (((source.x - x2) ^ 2) + ((source.y - y2) ^ 2)) ^ 0.5
end

function Companion:get_inventory()
    local inventory = self.entity.get_inventory(defines.inventory.spider_trunk)
    inventory.sort_and_merge()
    return inventory
end

function Companion:get_fuel_inventory()
    local inventory = self.entity.get_fuel_inventory()
    inventory.sort_and_merge()
    return inventory
end

function Companion:insert_to_player_or_vehicle(stack)

    local inserted = self.player.insert(stack)
    if inserted > 0 then return inserted end

    if self.player.vehicle then
        inserted = self.player.vehicle.insert(stack)
        if inserted > 0 then return inserted end
        if self.player.vehicle.train then
            inserted = self.player.vehicle.train.insert(stack)
            if inserted > 0 then return inserted end
        end
    end

    return 0

end

function Companion:try_to_shove_inventory()
    local inventory = self:get_inventory()
    local total_inserted = 0
    for k = 1, 20 do
        local stack = inventory[k]
        if not (stack and stack.valid_for_read) then break end
        local inserted = self:insert_to_player_or_vehicle(stack)
        if inserted == 0 then
            self.player.print({"inventory-restriction.player-inventory-full", stack.prototype.localised_name, {"inventory-full-message.main"}})
            break
        else
            total_inserted = total_inserted + inserted
            if inserted == stack.count then
                stack.clear()
            else
                stack.count = stack.count - inserted
            end
        end
    end

    if total_inserted > 0 then
        self.entity.surface.create_entity
        {
            name = "inserter-beam",
            source = self.entity,
            target = self.player.character,
            target_position = self.player.physical_position,
            force = self.entity.force,
            position = self.entity.position,
            duration = math.min(math.max(math.ceil(total_inserted / 5), 10), 60),
            max_length = follow_range + 4
        }
    end

end

function Companion:has_items()
    return self:get_inventory()[1].valid_for_read
end

function Companion:can_go_inactive()
    if self.out_of_energy then return end
    if self:is_busy() then return end
    if self:has_items() then return end
    if self:distance(self.player.physical_position) > follow_range then return end
    return true
end

function Companion:return_to_player()

    if not self.player.valid then return end
    if self.is_busy_for_construction and not self.is_getting_full then return end
    if self.player.physical_surface ~= self.entity.surface then
        return
    end

    self.moving_to_destination = nil
    local distance = self:distance(self.player.physical_position)

    if distance <= follow_range then
        self:try_to_shove_inventory()
        if not (self.entity.valid) then return end
    end

    if distance > 500 then
        self:teleport(self.player.physical_position, self.entity.surface)
    end
    
    if self.current_job_target
    and self:player_wants_construction()
    and self.can_construct
    and not self:_inside_job_zone() then
        if not self.moving_to_destination then
            self:set_job_destination(self.current_job_target)
        end
        return
    end

    if self:can_go_inactive() then
        self:clear_active()
        return
    end

    self:set_speed(math.max(eff_base() * 0.8, get_player_speed(self.player, 1.0)))

    if self.player.character then
        self.entity.follow_target = self.player.character
        return
    end
    self.entity.autopilot_destination = self.player.physical_position
end

function Companion:take_item(item, target)
    local target_inventory = get_inventory(target)
    if not target_inventory then return end

    while true do
        local stack = target_inventory.find_item_stack({ name = item.name, quality = item.quality })
        if not stack then break end

        local given = self.entity.insert(stack)
        if given == 0 then break end
        if given == stack.count then
            stack.clear()
        else
            stack.count = stack.count - given
        end
        item.count = item.count - given
        if item.count <= 0 then break end
    end

    if item.count <= 0 then
        local extra_stacks = 2 -- how much extra material the companion grabs in anticipation of more work
        local stack_size = (prototypes.item[item.name] and prototypes.item[item.name].stack_size) or 100
        local extra_to_take = extra_stacks * stack_size
        local taken_extra = 0

        while taken_extra < extra_to_take do
            local stack = target_inventory.find_item_stack({ name = item.name, quality = item.quality })
            if not stack then break end
            local given = self.entity.insert(stack)
            if given == 0 then break end
            if given == stack.count then
                stack.clear()
            else
                stack.count = stack.count - given
            end
            taken_extra = taken_extra + given
        end
    end

    self.entity.surface.create_entity{
        name = "inserter-beam",
        source = self.entity,
        target = (target.is_player() and target.character) or nil,
        target_position = target.position,
        force = self.entity.force,
        position = self.entity.position,
        duration = math.min(math.max(math.ceil(item.count / 5), 10), 60),
        max_length = follow_range + 4
    }

    return item.count <= 0
end

function Companion:take_item_from_train(item, train)
    for k, wagon in pairs(train.cargo_wagons) do
        if self:take_item(item, wagon) then
            return true
        end
    end
    return false
end

local angle = function(position_1, position_2)
    local d_x = (position_2[1] or position_2.x) - (position_1[1] or position_1.x)
    local d_y = (position_2[2] or position_2.y) - (position_1[2] or position_1.y)
    return math.atan2(d_y, d_x)
end

function Companion:get_offset(target_position, length, angle_adjustment)
        local angle = angle(self.entity.position, target_position)
        angle = angle + (math.pi / 2) + (angle_adjustment or 0)
        local x1 = (length * math.sin(angle))
        local y1 = (-length * math.cos(angle))
        return {x1 / 10, y1 / 10}
end

function Companion:set_attack_destination(position)
    local self_position = self.entity.position
    local distance = self:distance(position) + dist_bonus

    if math.abs(distance) > 2 then
        local offset = self:get_offset(position, distance, (distance < 0 and math.pi/4) or 0)
        self_position.x = self_position.x + offset[1]
        self_position.y = self_position.y + offset[2]
        self.moving_to_destination = true
        self.entity.autopilot_destination = self_position
    end

    self.last_attack_tick = game.tick
    self.is_in_combat = true
    self:set_active()
end

function Companion:set_job_destination(position)
    local self_pos = self.entity.position
    local tx = position.x or position[1]
    local ty = position.y or position[2]
    local dx = tx - self_pos.x
    local dy = ty - self_pos.y
    local d  = math.sqrt(dx*dx + dy*dy)

    self.current_job_target = position

    if d <= 2 then
        self.moving_to_destination = nil
        return
    end
    local _, reach = self:_job_distance_and_range(position)
    local inner_needed = math.max(0, d - (reach - inner_margin))
    local step = math.max(staging_step, inner_needed)
    step = math.min(step, d - 1) 

    local nx, ny = dx / d, dy / d
    local dest = { x = self_pos.x + nx * step, y = self_pos.y + ny * step }

    self.moving_to_destination = true
    self.entity.follow_target = nil
    self.entity.autopilot_destination = dest
    self.is_busy_for_construction = true
    self:set_active()
end

function Companion:player_wants_attack()
    return self.player.is_shortcut_toggled("companion-attack-toggle")
end

function Companion:player_wants_construction()
    return self.player.is_shortcut_toggled("companion-construction-toggle")
end

function Companion:attack(entity, projectile_count)
    if not self:player_wants_attack() then return end

    projectile_count = projectile_count or 3  -- default if not provided

    local position = self.entity.position
    for i = 1, projectile_count do
        local offset = (math.random() * 0.5) - 0.25

        local projectile = self.entity.surface.create_entity{
            name = "companion-projectile",
            position = {position.x, position.y - 1.5},
            speed = 0.05,
            force = self.entity.force,
            target = entity,
            max_range = 55
        }

        projectile.orientation = projectile.orientation + offset

        local beam = self.entity.surface.create_entity{
            name = "inserter-beam",
            source = self.entity,
            target = self.entity,
            position = {0, 0}
        }
        beam.set_beam_target(projectile)
    end

    self:set_attack_destination(entity.position)
    self.last_attack_tick = game.tick
end

local ghost_types =
{
    ["entity-ghost"] = true,
    ["tile-ghost"] = true
}

local item_request_types =
{
    ["entity-ghost"] = true,
    ["item-request-proxy"] = true

}

function Companion:try_to_find_targets(search_area)

    local entities = self.entity.surface.find_entities_filtered
    {
        area = search_area,
        is_military_target = true
    }

    local our_force = self.entity.force
    for k, entity in pairs (entities) do
        if not entity.valid then break end
        if entity.destructible then
            local force = entity.force
            if not (force == our_force or force.name == "neutral" or our_force.get_cease_fire(entity.force)) then
                self:set_attack_destination(entity.position)
                return
            end
        end
    end

end

function get_inventory(entity)
    if entity.is_player() then
        if not entity.controller_type or entity.controller_type ~= defines.controllers.character then return end
        return entity.get_main_inventory() or entity.get_output_inventory()
    end

    if entity.type == "spider-vehicle" then
        return entity.get_inventory(defines.inventory.spider_trunk)
    elseif entity.type == "car" then
        return entity.get_inventory(defines.inventory.car_trunk)
    elseif entity.type == "cargo-wagon" then
        return entity.get_inventory(defines.inventory.cargo_wagon)
    else
		return entity.get_main_inventory() or entity.get_output_inventory()
	end
end

function Companion:find_and_take_from_player(item)
    local count = self.player.get_item_count{ name = item.name, quality = (item.quality or "normal") }
    if count >= item.count then
        if self:take_item(item, self.player) then
            return true
        end
    end

    local vehicle = self.player.vehicle
    if vehicle then
        local train = vehicle.train
        if not train then
            local target_inventory = get_inventory(vehicle)
            local count = target_inventory.get_item_count{ name = item.name, quality = (item.quality or "normal") }
            if count >= item.count then
                if self:take_item(item, vehicle) then
                    return true
                end
            end
        else
            local train_contents = train.get_contents()

            local count = 0

            for _, item_in_train in pairs(train_contents) do
                if (item_in_train.name == item.name and item_in_train.quality == item.quality) then
                    count = item_in_train.count
                    break
                end
            end

            if count >= item.count then
                if self:take_item_from_train(item, train) then
                    return true
                end
            end
        end
    end
end

function Companion:on_player_placed_equipment(event)
    self:set_active()
    --self:say("Equipment added")
end

function Companion:on_player_removed_equipment(event)
    self:set_active()
    --self:say("Equipment removed")
end

function Companion:teleport(position, surface)
    self:clear_robots()
    self:clear_speed_sticker()
    self:clear_speed_fx()  
    self.entity.teleport(position, surface)
    self:set_active()
end

function Companion:change_force(force)

    self.entity.force = force
    for k, robot in pairs (self.robots) do
        if robot.valid then
            robot.force = force
        end
    end

    self:check_equipment()

end

local on_built_entity = function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end

    if entity.name ~= "companion" then
        return
    end

    local player = event.player_index and game.get_player(event.player_index)
    if not player then return end

    Companion.new(entity, player)

end

local on_entity_destroyed = function(event)
    local companion = get_companion(event.unit_number)
    if not companion then return end
    companion:on_destroyed()
end

local search_offsets = {}
local search_distance = 100
local search_divisions = 7

local setup_search_offsets = function()
    local r = search_distance / search_divisions
    search_offsets = {}
    for y = 0, (search_divisions - 1) do
        local offset_y = (y - (search_divisions / 2)) * r
        for x = 0, (search_divisions - 1) do
            local offset_x = (x - (search_divisions / 2)) * r
            local area = {{offset_x, offset_y}, {offset_x + r, offset_y + r}}
            table.insert(search_offsets, area)
        end
    end

    --table.sort(search_offsets, function(a, b) return distance(a[1], {0,0}) < distance(b[1], {0,0}) end)

    for k, v in pairs (search_offsets) do
        local i = (((k * 87)) % #search_offsets) + 1
        search_offsets[k], search_offsets[i] = search_offsets[i], search_offsets[k]
    end
end
setup_search_offsets()

local get_free_companion_for_construction = function(player_data)
    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion and (not companion.active) and companion.can_construct and not companion:move_to_robot_average() then
            return companion
        end
    end
end

function Companion:escape_danger(threat_pos)
    if self:distance(self.player.physical_position) > abandon_job_distance then
        self.current_job_target = nil
        self.moving_to_destination = nil
        self.entity.autopilot_destination = nil
        self:clear_robots()
        self:return_to_player()
        return
    end

    if not threat_pos or not threat_pos.x then
        self.current_job_target = nil
        self.moving_to_destination = nil
        self.entity.autopilot_destination = nil
        self:return_to_player()
        return
    end

    local self_pos = self.entity.position
    local dx = self_pos.x - threat_pos.x
    local dy = self_pos.y - threat_pos.y
    local d  = math.sqrt(dx*dx + dy*dy)
    if d < 0.001 then d = 0.001 end

    local retreat = 8
    local dest = { x = self_pos.x + (dx/d) * retreat, y = self_pos.y + (dy/d) * retreat }

    self.current_job_target = nil
    self.moving_to_destination = true
    self.entity.follow_target = nil
    self.entity.autopilot_destination = dest

    self:set_active()
end


--------------------------- Core Logic ---------------------------

function Companion:update() 
    if self.flagged_for_equipment_changed then
        self:check_equipment()
    end
    
    do
        local pos = self.entity.position
        if self.moving_to_destination then
            local lp = self._last_auto_pos or pos
            if (math.abs(pos.x - lp.x) + math.abs(pos.y - lp.y)) < 0.05 then
                self._stalled_ticks = (self._stalled_ticks or 0) + 1
            else
                self._stalled_ticks = 0
            end
            self._last_auto_pos = pos
            if (self._stalled_ticks or 0) > 120 then
                self.moving_to_destination = nil
                self.entity.autopilot_destination = nil
            end
        else
            self._stalled_ticks = 0
            self._last_auto_pos = pos
        end
    end

    local was_busy = self.is_busy_for_construction
    local was_in_combat = self.is_in_combat

    self:update_state_flags()
    
    if self.current_job_target then 
    -- if the player is too far from the job, ignore it and follow player
        local p = self.player.physical_position
        local t = self.current_job_target
        local tx = t[1] or t.x
        local ty = t[2] or t.y
        local dx = p.x - tx
        local dy = p.y - ty
        local d = (dx * dx + dy * dy) ^ 0.5
        if d > abandon_job_distance then
            self.moving_to_destination = nil
            self.current_job_target = nil
            self.entity.autopilot_destination = nil
            self:clear_robots()
            self:return_to_player()
            return
        end
    end
    
    if self:player_wants_construction()
    and self.can_construct
    and next(self.robots)
    and not self.moving_to_destination
    then -- ensures we complete all jobs in range before moving on to the next location
        local radius = storage.max_distance or 100
        local origin = self.entity.position
        local area = {{origin.x - radius, origin.y - radius}, {origin.x + radius, origin.y + radius}}
        local hold = self.moving_to_destination
        self.moving_to_destination = true
        self:try_to_find_work(area)
        self.moving_to_destination = hold
    end
    
    if was_busy and not self.is_busy_for_construction then
        -- So we were building, and now we are finished, lets try to find some work nearby
        self:search_for_nearby_work()
    end

    if was_in_combat and not self.is_in_combat then
        -- Same as above
        self:search_for_nearby_targets()
    end

    if self.is_getting_full or self.is_on_low_health or not self:is_busy() then
        self.moving_to_destination = nil
        self:return_to_player()
    end
end

function Companion:try_to_find_work(search_area)
    local force   = self.entity.force
    local surface = self.entity.surface

    local current_items = self:get_inventory().get_contents()
    local can_take_from_player = self:distance(self.player.physical_position) <= follow_range
        and self.entity.surface == self.player.physical_surface

    local function has_or_can_take(item)
        if self:get_inventory().get_item_count{
            name    = item.name,
            quality = (item.quality or "normal")
        } >= (item.count or 1) then
            return true
        end
        if not can_take_from_player then return false end
        return self:find_and_take_from_player{
            name    = item.name,
            count   = (item.count or 1),
            quality = (item.quality or "normal")
        }
    end

    local attempted_ghost_names   = {}
    local attempted_upgrade_names = {}
    local attempted_proxy_items   = {}
    local repair_attempted        = false
    local deconstruction_attempted = false
    local max_item_type_count     = 10

    local function pick(pos)
        if not self.moving_to_destination then
            self:set_job_destination(pos)
            return true
        end
    end

    local function bots_claimed(entity, kind)
        if kind == "construct" then
            return entity.is_registered_for_construction and entity.is_registered_for_construction() or false
        elseif kind == "upgrade" then
            return entity.is_registered_for_upgrade and entity.is_registered_for_upgrade() or false
        elseif kind == "repair" then
            return entity.is_registered_for_repair and entity.is_registered_for_repair() or false
        elseif kind == "decon" then
            return entity.is_registered_for_deconstruction and entity.is_registered_for_deconstruction(force) or false
        end
        return false
    end

    -- deconstruction (ignore if bots already claimed)
    local decon = surface.find_entities_filtered{
        area                = search_area,
        force               = force,
        to_be_deconstructed = true
    }
    for _, entity in pairs(decon) do
        if not entity.valid then break end
        if (entity.type ~= "vehicle") or (entity.speed and entity.speed < 0.4) then
            if not bots_claimed(entity, "decon") then
                deconstruction_attempted = true
                if pick(entity.position) then return end
            end
        end
    end

    -- ghosts (ignore if bots already claimed)
    local ghosts = surface.find_entities_filtered{
        area  = search_area,
        force = force,
        type  = {"entity-ghost", "tile-ghost"}
    }
    for _, entity in pairs(ghosts) do
        if (max_item_type_count or 0) <= 0 then return end
        if not entity.valid then break end

        if bots_claimed(entity, "construct") then goto continue_ghost end

        local entity_type = entity.type
        local quality     = (entity.quality and entity.quality.name) or "normal"

        if ghost_types[entity_type] then
            local ghost_name = entity.ghost_name
            if not attempted_ghost_names[ghost_name] then
                local proto = entity.ghost_prototype
                local items = proto and proto.items_to_place_this
                local item  = items and items[1]
                if item then
                    item.quality = quality
                    if has_or_can_take(item) then
                        if pick(entity.position) then return end
                        max_item_type_count = max_item_type_count - 1
                        attempted_ghost_names[ghost_name] = 1
                    else
                        attempted_ghost_names[ghost_name] = 0
                    end
                else
                    attempted_ghost_names[ghost_name] = 0
                end
            end
            if item_request_types[entity_type] and attempted_ghost_names[ghost_name] == 1 then
                local items = entity.item_requests
                for _, item in pairs(items) do
                    if not attempted_proxy_items[item.name] then
                        attempted_proxy_items[item.name] = true
                        if has_or_can_take(item) then
                            max_item_type_count = max_item_type_count - 1
                        end
                    end
                end
            end
        end
        ::continue_ghost::
    end

    -- upgrades (ignore if bots already claimed)
    local upgrades = surface.find_entities_filtered{
        area           = search_area,
        force          = force,
        to_be_upgraded = true
    }
    for _, entity in pairs(upgrades) do
        if not entity.valid then break end
        if bots_claimed(entity, "upgrade") then goto continue_upgrade end

        local quality        = (entity.quality and entity.quality.name) or "normal"
        local upgrade_target = entity.get_upgrade_target()
        if upgrade_target and not attempted_upgrade_names[upgrade_target.name] then
            if upgrade_target.name == entity.name then
                if pick(entity.position) then return end
            else
                local items = upgrade_target.items_to_place_this
                local item  = items and items[1]
                if item then
                    item.quality = quality
                    if has_or_can_take(item) then
                        if pick(entity.position) then return end
                        max_item_type_count = max_item_type_count - 1
                    end
                end
            end
            attempted_upgrade_names[upgrade_target.name] = true
        end
        ::continue_upgrade::
    end

    -- repair (ignore if bots already claimed)
    if not repair_attempted and not self.moving_to_destination then
        local candidates = surface.find_entities_filtered{
            area  = search_area,
            force = force,
            limit = 200
        }
        for _, entity in pairs(candidates) do
            local needs_repair = (entity.get_health_ratio and ((entity.get_health_ratio() or 1) < 1)) or false
            if needs_repair and not bots_claimed(entity, "repair") then
                for name in pairs(get_repair_tools()) do
                    if has_or_can_take({name = name, count = 1}) then
                        if pick(entity.position) then return end
                        break
                    end
                end
                break
            end
        end
    end

    -- item request proxies (ignore if bots already claimed)
    local proxies = surface.find_entities_filtered{
        area  = search_area,
        force = force,
        type  = "item-request-proxy"
    }
    for _, entity in pairs(proxies) do
        if not entity.valid then break end
        if bots_claimed(entity, "construct") then goto continue_proxy end
        local items = entity.item_requests
        for _, item in pairs(items) do
            if not attempted_proxy_items[item.name] then
                attempted_proxy_items[item.name] = true
                if has_or_can_take(item) then
                    if pick(entity.position) then return end
                    max_item_type_count = max_item_type_count - 1
                end
            end
        end
        ::continue_proxy::
    end

    -- neutral cliffs (ignore if bots already claimed)
    local attempted_cliff_names = {}
    local neutral_entities = surface.find_entities_filtered{
        area                = search_area,
        force               = "neutral",
        to_be_deconstructed = true
    }
    for _, entity in pairs(neutral_entities) do
        if not entity.valid then break end
        if entity.type == "cliff" then
            local claimed = bots_claimed(entity, "decon")
            if not attempted_cliff_names[entity.name] and not claimed then
                local item_name = entity.prototype.cliff_explosive_prototype
                if has_or_can_take({name = item_name, count = 1}) then
                    if pick(entity.position) then return end
                    max_item_type_count = max_item_type_count - 1
                end
                attempted_cliff_names[entity.name] = true
            end
        elseif not deconstruction_attempted and not claimed then
            deconstruction_attempted = true
            if pick(entity.position) then return end
        end
    end
end

local perform_job_search = function(player, player_data)

    if not player.is_shortcut_toggled("companion-construction-toggle") then return end
    local free_companion = get_free_companion_for_construction(player_data)
    if not free_companion then return end

    if not player.controller_type or player.controller_type    ~= defines.controllers.character then return end

    player_data.last_job_search_offset = player_data.last_job_search_offset + 1
    local area = search_offsets[player_data.last_job_search_offset]
    if not area then
        player_data.last_job_search_offset = 0
        return
    end

    local position = player.physical_position
    local search_area = {{area[1][1] + position.x, area[1][2] + position.y}, {area[2][1] + position.x, area[2][2] + position.y}}

    free_companion:try_to_find_work(search_area)
end

local perform_attack_search = function(player, player_data)

    if not player.is_shortcut_toggled("companion-attack-toggle") then return end

    if not player.controller_type or player.controller_type    ~= defines.controllers.character then return end

    local free_companion
    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion and not companion.active and companion.can_attack then
            free_companion = companion
            break
        end
    end
    if not free_companion then return end

    player_data.last_attack_search_offset = player_data.last_attack_search_offset + 1
    local area = search_offsets[player_data.last_attack_search_offset]
    if not area then
        player_data.last_attack_search_offset = 0
        return
    end

    local position = player.physical_position
    local search_area = {{area[1][1] + position.x, area[1][2] + position.y}, {area[2][1] + position.x, area[2][2] + position.y}}

    free_companion:try_to_find_targets(search_area)
end

local process_specific_job_queue = function(player_index, player_data)

    local player = game.players[player_index]
    if not player.is_shortcut_toggled("companion-construction-toggle") then
        script_data.specific_job_search_queue[player_index] = nil
        return
    end

    local areas = script_data.specific_job_search_queue[player_index]
    local i, area = next(areas)

    if not i then
        script_data.specific_job_search_queue[player_index] = nil
        return
    end

    local free_companion = get_free_companion_for_construction(player_data)
    if not free_companion then
        return
    end

    --free_companion:say(i)
	if not storage.max_distance then storage.max_distance = 250 end
    if free_companion:distance(area[1]) < storage.max_distance then
        free_companion:try_to_find_work(area)
    end

    areas[i] = nil

end

local check_job_search = function(event)
    if not next(script_data.player_data) then return end

    local job_search_queue = script_data.specific_job_search_queue
    local players = game.players

    for player_index, player_data in pairs(script_data.player_data) do
        local player = players[player_index]
        if player.connected then
            local areas = job_search_queue[player_index]

            if areas then
                for i = 1, (storage.queue_stride or 8) do
                    if not job_search_queue[player_index] then break end
                    process_specific_job_queue(player_index, player_data)
                end
            else
                for i = 1, (storage.job_stride or 12) do
                    perform_job_search(player, player_data)
                end
            end
            for i = 1, (storage.attack_stride or 6) do
                perform_attack_search(player, player_data)
            end
        end
    end
end

local update_active_companions = function(event)
    local mod = event.tick % storage.companion_update_interval
    local list = script_data.active_companions[mod]
    if not list then return end
    for unit_number, bool in pairs (list) do
        local companion = get_companion(unit_number)
        if companion then
            companion:update()
        end
    end
end

local check_follow_update = function(event)
    if not next(script_data.player_data) then return end
    local players = game.players
    for player_index, player_data in pairs(script_data.player_data) do
        local player = players[player_index]
        if player.connected then
            adjust_follow_behavior(player)
        end
    end
end

local function check_and_restore_construction_bots()
    for unit_number, companion in pairs(script_data.companions) do
        if companion and companion.entity and companion.entity.valid then
            if companion:player_wants_construction() then
                local inventory = companion:get_inventory()
                if inventory and inventory[21] then
                    local stack = inventory[21]
                    if stack.valid_for_read then
                        if stack.name ~= "companion-construction-robot" or stack.count ~= 100 then
                            stack.set_stack({name="companion-construction-robot", count=100})
                        end
                    else
                        inventory[21].set_stack({name="companion-construction-robot", count=100})
                    end
                end
            end
        end
    end
end

local function check_inactive_idle_chatter(event)
    if not next(script_data.companions) then return end
    for unit_number, comp in pairs(script_data.companions) do
        if comp and comp.entity and comp.entity.valid and not comp.active then
            if not (comp.is_in_combat or comp.is_busy_for_construction) then
                local delay = settings.get_player_settings(comp.player)["companion-idle-chatter-delay"].value
                local minimum = math.max(1, math.floor(delay * 0.1))
                local maximum = math.ceil(delay)

                if not comp.next_idle_line_tick then
                    comp.next_idle_line_tick = event.tick + 60 * math.random(minimum, maximum)
                elseif event.tick >= comp.next_idle_line_tick then
                    comp:say_random("idle-line")
                    comp.next_idle_line_tick = event.tick + 60 * math.random(minimum, maximum)
                end
            else
                comp.next_idle_line_tick = nil
            end
        end
    end
end

local on_tick = function(event)
    update_active_companions(event) -- must run every tick
	if event.tick % storage.companion_update_interval == 0 then 
    -- by default runs every 5 ticks, user configurable
        check_follow_update(event)
        check_and_restore_construction_bots()
		check_job_search(event)
        check_inactive_idle_chatter(event)
    end
end

--------------------------- Secondary Utilities ---------------------------

local on_spider_command_completed = function(event)
    local spider = event.vehicle
    local companion = get_companion(spider.unit_number)
    if not companion then return end
    companion:on_spider_command_completed()
end

function Companion:on_spider_command_completed()
    local t = self.current_job_target
    if t then
        local p = self.player.physical_position
        local tx = t[1] or t.x
        local ty = t[2] or t.y
        local dx = p.x - tx
        local dy = p.y - ty
        local d = (dx * dx + dy * dy) ^ 0.5
        if d > abandon_job_distance then
            self.moving_to_destination = nil
            self.current_job_target = nil
            self.entity.autopilot_destination = nil
            self:clear_robots()
            self:return_to_player()
            return
        end
    end

    self.moving_to_destination = nil

    local distance = self:distance(self.player.physical_position)
    if not self.is_busy_for_construction and distance <= follow_range then
        self:try_to_shove_inventory()
    end

    if self.current_job_target and not next(self.robots)
       and self:player_wants_construction() and self.can_construct then
        self:set_job_destination(self.current_job_target)
        return
    end
end

local companion_attack_trigger = function(event)

    local source_entity = event.source_entity
    if not (source_entity and source_entity.valid) then
        return
    end

    local target_entity = event.target_entity
    if not (target_entity and target_entity.valid) then
        return
    end

    local companion = get_companion(source_entity.unit_number)
    if companion then
        companion:attack(target_entity, storage.attack_count)
    end
end

local companion_robot_spawned_trigger = function(event)
    local robot = event.target_entity or event.source_entity
    if not (robot and robot.valid) then return end
    if robot.type ~= "construction-robot" and robot.type ~= "logistic-robot" then return end

    local network = robot.logistic_network
    if not network or not network.cells or not network.cells[1] then return end
    local owner = network.cells[1].owner
    if not (owner and owner.valid and owner.name == "companion") then return end

    local companion = get_companion(owner.unit_number)
    if companion then
        companion:robot_spawned(robot)
    end
end

--[[effect_id :: string: The effect_id specified in the trigger effect.
surface_index :: uint: The surface the effect happened on.
source_position :: Position (optional)
source_entity :: LuaEntity (optional)
target_position :: Position (optional)
target_entity :: LuaEntity (optional)]]

local on_script_trigger_effect = function(event)
    local id = event.effect_id
    --game.print(id)
    if id == "companion-attack" then
        companion_attack_trigger(event)
        return
    end

    if id == "companion-robot-spawned" then
        companion_robot_spawned_trigger(event)
    end
end

local on_player_placed_equipment = function(event)

    local player = game.get_player(event.player_index)
    --if player.opened_gui_type ~= defines.gui_type.entity then return end


    local opened = player.opened
    if not (opened and opened.valid and opened.prototype.name == "companion") then return end

    local companion = get_companion(opened.unit_number)
    if not companion then return end

    companion:on_player_placed_equipment(event)

end

local on_player_removed_equipment = function(event)
    local player = game.get_player(event.player_index)
    if player.opened_gui_type ~= defines.gui_type.entity then return end

    local opened = player.opened
    if not (opened and opened.valid and opened.prototype.name == "companion") then return end

    local companion = get_companion(opened.unit_number)
    if not companion then return end

    companion:on_player_removed_equipment(event)

end

local on_entity_settings_pasted = function(event)

    local entity = event.destination
    if not (entity and entity.valid) then return end

    local companion = get_companion(entity.unit_number)
    if not companion then return end

    companion:set_active()

end

local on_player_changed_surface = function(event)
    local player_data = script_data.player_data[event.player_index]
    if not player_data then return end

    local player = game.get_player(event.player_index)
    if not player.character then
        --For the space exploration satellite viewer thing...
        --If there is no character, lets just not go with the player.
        return
    end
    local surface = player.physical_surface
    local position = player.physical_position

    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            companion:teleport(position, surface)
        end
    end

end

local on_player_left_game = function(event)
    local player_data = script_data.player_data[event.player_index]
    if not player_data then return end

    local surface = get_secret_surface()
    local position = {x = 0, y = 0}

    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            companion:teleport(position, surface)
        end
    end
end

function reschedule_companions(allow_prototype_access)
    script_data.active_companions = {}
    for k, companion in pairs(script_data.companions) do
        if companion.entity and companion.entity.valid then
            companion.moving_to_destination = nil
            if allow_prototype_access then
                companion:set_active()
            else
                companion.active = false
            end
        else
            script_data.companions[k] = nil
        end
    end
end

local on_player_joined_game = function(event)
    local player_data = script_data.player_data[event.player_index]
    if not player_data then return end

    local player = game.get_player(event.player_index)
    local surface = player.physical_surface
    local position = player.physical_position

    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            companion:teleport({position.x + math.random(-20, 20), position.y + math.random(-20, 20)}, surface)
        end
    end
	set_companion_stats(player)
    reschedule_companions(true)
    adjust_follow_behavior(player)
end

local on_player_changed_force = function(event)
    local player_data = script_data.player_data[event.player_index]
    if not player_data then return end

    local player = game.get_player(event.player_index)
    local force = player.force
    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            companion:change_force(force)
        end
    end
end

local on_player_driving_changed_state = function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    if not player.vehicle then return end

    if player.vehicle.name == "companion" then
        player.driving = false
    end

    adjust_follow_behavior(player)

end

local rebukes =
-- picks one at random if you try to use a spidertron remote on the drone
{
    "You're not the boss of me",
    "Get lost",
    "Not me pal",
    "Maybe later, I mean never.",
    "Go bother someone else",
    "I do my own thing",
    "lol as if...",
    "What are you, nuts?",
    "I ain't goin' in there!",
    "lol. lmao, even",
    "Who do you think you are?",
    "Do I look like a friggin spider to you?",
    "What do I look like, a spidertron?",
    "That's really not necessary.",
    "Oh don't worry, I can take care of myself.",
    "You don't need to do that.",
    "Don't do that.",
    "No.",
    "Nope.",
    "Nuh uh.",
    "Not happening.",
    "In your dreams"
}

local on_player_used_spider_remote = function(event)
    local vehicle = event.vehicle
    if not (vehicle and vehicle.valid) then return end
    local companion = get_companion(vehicle.unit_number)
    if not companion then return end

    companion:say(rebukes[math.random(#rebukes)])
    companion.entity.follow_target = nil
    companion.entity.autopilot_destination = nil

end

local on_player_mined_entity = function(event)
    if event.entity and event.entity.valid and event.entity.name == "companion" then
        local player = game.get_player(event.player_index)
        player.remove_item{name = "companion-construction-robot", count = 1000}
    end
end

local recall_fighting_robots = function(player)
    local player_data = script_data.player_data[player.index]
    if not player_data then return end
    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            if companion.is_in_combat then
                companion:return_to_player()
            end
        end
    end
end

local recall_constructing_robots = function(player)
    local player_data = script_data.player_data[player.index]
    if not player_data then return end
    for unit_number, bool in pairs (player_data.companions) do
        local companion = get_companion(unit_number)
        if companion then
            if next(companion.robots) then
                companion:clear_robots()
                companion:return_to_player()
            end
			if companion.moving_to_destination and not companion.is_in_combat then
                companion.moving_to_destination = nil
                companion:return_to_player()
            end
        end
    end
end

local clear_specific_job_search_queue = function(player)
    script_data.specific_job_search_queue[player.index] = nil
end

local on_lua_shortcut = function(event)
    local player = game.get_player(event.player_index)
    local name = event.prototype_name
    if name == "companion-attack-toggle" then
        player.set_shortcut_toggled(name, not player.is_shortcut_toggled(name))
        recall_fighting_robots(player)
    end
	if name == "companion-construction-toggle" then
		player.set_shortcut_toggled(name, not player.is_shortcut_toggled(name))
		recall_constructing_robots(player)
		clear_specific_job_search_queue(player)
		local player_data = script_data.player_data[player.index]
		if player_data then
			for unit_number in pairs(player_data.companions) do
				local companion = script_data.companions[unit_number]
				if companion then
					companion:set_robot_stack()
				end
			end
		end
	end
end

script.on_event("companion-attack-hotkey", function(event)
    local player = game.get_player(event.player_index)
    if player then
        player.set_shortcut_toggled("companion-attack-toggle", not player.is_shortcut_toggled("companion-attack-toggle"))
        recall_fighting_robots(player)
    end
end)

script.on_event("companion-construction-hotkey", function(event)
    local player = game.get_player(event.player_index)
    if player then
        player.set_shortcut_toggled("companion-construction-toggle", not player.is_shortcut_toggled("companion-construction-toggle"))
        recall_constructing_robots(player)
        clear_specific_job_search_queue(player)
        local player_data = script_data.player_data[player.index]
        if player_data then
            for unit_number in pairs(player_data.companions) do
                local companion = script_data.companions[unit_number]
                if companion then
                    companion:set_robot_stack()
                end
            end
        end
    end
end)

script.on_event("companion-force-search", function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.connected then return end

    local pd = script_data.player_data[player.index]
    if not pd then return end

    for unit_number in pairs(pd.companions) do
        local c = script_data.companions[unit_number]
        if c and c.can_construct and c:player_wants_construction() then
            c:search_for_nearby_work()
            c:search_for_nearby_targets()
            if c.debug_report_state then
                c:debug_report_state("force-search")
            end
        end
    end
end)

local dissect_area_size = 32

local dissect_and_queue_area = function(player_index, player_pos, area)
    local player_queue = script_data.specific_job_search_queue[player_index]
    if not player_queue then
        player_queue = {}
        script_data.specific_job_search_queue[player_index] = player_queue
    end
	if not storage.max_distance then storage.max_distance = 250 end
    local xmax = math.max(player_pos.x - storage.max_distance, area.left_top.x)
    local xmin = math.min(player_pos.x + storage.max_distance, area.right_bottom.x)
    local ymax = math.max(player_pos.y - storage.max_distance, area.left_top.y)
    local ymin = math.min(player_pos.y + storage.max_distance, area.right_bottom.y)

    local count = #player_queue
    for x = xmin, xmax, dissect_area_size do
        for y = ymin, ymax, dissect_area_size do
            table.insert(player_queue, (count > 0 and math.random(count)) or 1, {{x, y}, {x + dissect_area_size, y + dissect_area_size}})
            count = count + 1
        end
    end

end

local on_player_deconstructed_area = function(event)
    local player = game.get_player(event.player_index)
    if not player.is_shortcut_toggled("companion-construction-toggle") then return end
    dissect_and_queue_area(event.player_index, player.physical_position, event.area)
end

local function get_all_blueprint_entities(blueprint_record)
    local entities = {}

    if blueprint_record.type == "blueprint-book" and blueprint_record.object_name == "LuaItem" then
        blueprint_record = blueprint_record.get_inventory(defines.inventory.item_main)[blueprint_record.active_index]

        return get_all_blueprint_entities(blueprint_record)
    end

    -- Check if the item is a blueprint book
    if blueprint_record.type == "blueprint-book" then
        -- Recursively process each item inside the book
        for _, item in pairs(blueprint_record.contents) do
            local nested_entities = get_all_blueprint_entities(item)
            for _, nested_entity in pairs(nested_entities) do
                table.insert(entities, nested_entity)
            end
        end
    elseif blueprint_record.type == "blueprint" then
        -- Add entities if it's a single blueprint
        local blueprint_entities = blueprint_record.get_blueprint_entities()
        if blueprint_entities then
            for _, entity in pairs(blueprint_entities) do
                table.insert(entities, entity)
            end
        end
    end

    return entities
end

local get_blueprint_area = function(player, offset)
    local entities = {}
    local max = 0
    local x1, y1, x2, y2
    local position

    if player.cursor_stack and player.cursor_stack.valid_for_read then
        if player.cursor_stack.object_name == "LuaRecord" and player.cursor_stack.count > 0 then
            entities = get_all_blueprint_entities(player.cursor_stack)
        else
            entities = get_all_blueprint_entities(player.cursor_stack.item)
        end
    elseif player.cursor_record then
        entities = get_all_blueprint_entities(player.cursor_record)
    else
        max = 32
    end

    if entities and #entities > 0 then
        for _, entity in pairs (entities) do
            position = entity.position
            x1 = math.min(x1 or position.x, position.x)
            y1 = math.min(y1 or position.y, position.y)
            x2 = math.max(x2 or position.x, position.x)
            y2 = math.max(y2 or position.y, position.y)

            max = math.max(max, math.abs(x1), math.abs(x2), math.abs(y1), math.abs(y2))
        end
    end

    return {left_top = {x = offset.x - max, y = offset.y - max}, right_bottom = {x = offset.x + max, y = offset.y + max}}
end

local on_pre_build = function(event)
    local player = game.get_player(event.player_index)

    if not (player.is_cursor_blueprint()) then return end

    if not player.is_shortcut_toggled("companion-construction-toggle") then
        return
    end

    -- I am lazy, not going to bother with rotations and flips...
    local area = get_blueprint_area(player, event.position)
    dissect_and_queue_area(event.player_index, player.physical_position, area)


end

local on_player_created = function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local surface = player.physical_surface
    local position = player.physical_position
	set_companion_stats(player)
	local entity = surface.create_entity
	{
	    name = "companion",
	    position = position,
	    force = player.force
	}
	entity.insert("wood")
	entity.color = player.color
	local grid = entity.grid
	grid.put{name = "companion-reactor-equipment"}
	if not challenge_mode then 
		grid.put{name = "companion-defense-equipment"}
		grid.put{name = "companion-defense-equipment"}
		grid.put{name = "companion-roboport-mk2"}
		grid.put{name = "companion-shield-mk2"}
        player.set_shortcut_available("companion-attack-toggle", true)
        player.set_shortcut_toggled("companion-attack-toggle", true)
	else
		grid.put{name = "companion-defense-equipment"}
		grid.put{name = "companion-roboport-mk0"}
		grid.put{name = "companion-shield-mk0"}
        player.set_shortcut_available("companion-attack-toggle", true)
        player.set_shortcut_toggled("companion-attack-toggle", false)
	end
	player.set_shortcut_available("companion-construction-toggle", true)
	player.set_shortcut_toggled("companion-construction-toggle", true)
	local companion = Companion.new(entity, player)
end

local function purge_illegal_companion_bots(player)
    if not (player and player.valid) then return end
    local cs = player.cursor_stack
    if cs and cs.valid_for_read and cs.name == "companion-construction-robot" then
        cs.clear()
    end
    local removed = player.remove_item{name = "companion-construction-robot", count = 1000000}
    if removed > 0 then
        local opened = player.opened
        if opened and opened.valid and opened.name == "companion" then
            local c = get_companion(opened.unit_number)
            if c then c:set_robot_stack() end
        end
    end
end

local on_player_main_inventory_changed = function(event)
    local player = game.get_player(event.player_index)
    purge_illegal_companion_bots(player)
end

local on_player_fast_transferred = function(event)
    local player = game.get_player(event.player_index)
    purge_illegal_companion_bots(player)
end

local on_player_cursor_stack_changed = function(event)
    local player = game.get_player(event.player_index)
    purge_illegal_companion_bots(player)
end

local function swap_equipment(grid, input, output) -- equipment literal names as strings, matches any arbitrary names. 
	if not grid or type(input) ~= "string" or type(output) ~= "string" then return nil end
	local target_positions = {} -- where on the grid each matching equipment is located
	for _, equipment in pairs(grid.equipment) do -- find the position of each equipment
		if equipment.name == input then 
			table.insert(target_positions, equipment.position)
		end 
	end
	for i = 1, #target_positions do -- remove "input" and replace with "output" equipment
		grid.take{position = target_positions[i]}
		grid.put{name = output, position = target_positions[i]}
	end
end

local function apply_researched_equipment_upgrades(player, grid)
    if not (player and grid) then return end
    ensure_companion_upgrades()
    local techs = player.force.technologies
    for _ = 1, 3 do
        for tech, entries in pairs(storage.companion_upgrades) do
            local up = entries and entries[1]
            if up and type(up.value) == "string" then
                local t = techs[tech]
                if t and t.researched then
                    swap_equipment(grid, up.stat, up.value)
                end
            end
        end
    end
end

function Companion:get_random_localised(key)
    -- Looks in __root__/locale/en/locale.cfg and reads the first line in KEY, then uses that value as it's upper bounds for randomly picking between 1 and KEY. 
	-- In the locale file, the first line should always be the exact number of lines in that section
	-- too low (i.e. lines were added) won't do anything except not show the added lines but too high will just return the key itself
    local count = storage.dialogue_counts and storage.dialogue_counts[key]
    if not count then
        local translated = self.player.request_translation({key .. ".0"})
        count = tonumber(translated) or 1
        storage.dialogue_counts = storage.dialogue_counts or {}
        storage.dialogue_counts[key] = count
    end
    local index = math.random(1, count)
    return {key .. "." .. index}
end

function Companion:say_random(key) 
    -- this function used to do more than simply call that ^ function, just haven't bothered removing it from where it's spread
    self:say(self:get_random_localised(key))
end

local function reseed_defaults()
    storage.companion_upgrades = nil
    ensure_companion_upgrades()
    for _, p in pairs(game.players) do
        set_companion_stats(p)
    end
    if reschedule_companions then reschedule_companions(true) end
    game.print("Companion defaults and upgrade table re-seeded.")
end

local function converge_equipment_to_researched(player, grid)
    if not (player and grid) then return end
    ensure_companion_upgrades()
    local techs = player.force.technologies

    for _ = 1, 3 do 
        local changed = false
        for tech, entries in pairs(storage.companion_upgrades or {}) do
            local t = techs[tech]
            local up = entries and entries[1]
            if t and t.researched and up and type(up.value) == "string" then
                if swap_equipment(grid, up.stat, up.value) then
                    changed = true
                end
            end
        end
        if not changed then break end
    end
end

local function reset_companions_for_player(player)
    local player_data = script_data.player_data and script_data.player_data[player.index]
    if not player_data or not next(player_data.companions) then
        player.print("No companion data found for this player.")
        return
    end

    local count = 0
    for unit_number in pairs(player_data.companions) do
        local companion = script_data.companions[unit_number]
        if companion then
            -- reset state
            companion:clear_robots()
            companion.is_busy_for_construction = false
            companion.is_in_combat = false
            companion.job_done_tick = nil
            companion.job_done_announced = false
            companion.out_of_energy = nil
            companion.moving_to_destination = nil
            companion.next_idle_line_tick = nil
            companion.test_idle_tick = nil
            companion.test_idle_fired = nil
            companion:clear_speed_sticker()
            companion:check_equipment()
            companion:try_to_refuel()
            companion:set_active()
            set_companion_stats(player)
            adjust_follow_behavior(player)
            companion:debug_report_state("RESET")

            local grid = companion.entity.grid
            apply_researched_equipment_upgrades(player, grid)
            converge_equipment_to_researched(player, grid)

            count = count + 1
        end
    end

    game.print({"", "Reset ", count, " companions for ", player.name, "."})
end

local function on_entity_damaged(event)
    local ent = event.entity
    if not (ent and ent.valid) then return end
    if ent.name ~= "companion" then return end

    local c = get_companion(ent.unit_number)
    if not c then return end                                     -- uses your helper
    if c:player_wants_attack() then return end                    -- respect attack toggle
    if c.entity.surface ~= c.player.physical_surface then return end

    if c._last_escape_tick and (game.tick - c._last_escape_tick) < 30 then return end
    c._last_escape_tick = game.tick

    local src = (event.cause and event.cause.valid) and event.cause.position or nil
    c:escape_danger(src)                                          -- flee from cause, or to player if nil
end


local function on_research_finished(event)
    if not challenge_mode or not event.research then return end
    local tech = event.research.name
    local entries = storage.companion_upgrades and storage.companion_upgrades[tech]
    if not entries or not entries[1] then return end
    local up = entries[1]
    local stat_alias = {
        damage        = "attack_count",
        number_drones = "max_companions",
    }
    for _, player in pairs(game.connected_players) do
        if player.force == event.research.force then
            local pd = script_data.player_data[player.index]
            if not pd then goto continue_player end
            for unit_number in pairs(pd.companions) do
                local companion = script_data.companions[unit_number]
                if not companion then goto continue_companion end
                if up.phrase then companion:say(up.phrase) end
                if type(up.value) == "number" then
                    -- STAT UPGRADE
                    local key = stat_alias[up.stat] or up.stat
                    storage[key] = up.value
                elseif type(up.value) == "string" then
                    -- EQUIPMENT UPGRADE (stat = from equipment, value = to equipment)
                    local grid = companion:get_grid()
                    if grid then
                        swap_equipment(grid, up.stat, up.value)
                        converge_equipment_to_researched(player, grid)
                    end
                end
                ::continue_companion::
            end
            ::continue_player::
        end
    end
end


lib.events =
{
    [defines.events.on_built_entity]                  = on_built_entity,
    [defines.events.on_object_destroyed]              = on_entity_destroyed,
    [defines.events.on_tick]                          = on_tick,
    [defines.events.on_spider_command_completed]      = on_spider_command_completed,
    [defines.events.on_script_trigger_effect]         = on_script_trigger_effect,
    [defines.events.on_entity_settings_pasted]        = on_entity_settings_pasted,

    [defines.events.on_player_placed_equipment]       = on_player_placed_equipment,
    [defines.events.on_player_removed_equipment]      = on_player_removed_equipment,
    [defines.events.on_player_main_inventory_changed] = on_player_main_inventory_changed,
    [defines.events.on_player_fast_transferred]       = on_player_fast_transferred,
    [defines.events.on_player_cursor_stack_changed]   = on_player_cursor_stack_changed,

    [defines.events.on_player_changed_surface]        = on_player_changed_surface,
    [defines.events.on_player_left_game]              = on_player_left_game,
    [defines.events.on_player_joined_game]            = on_player_joined_game,
    [defines.events.on_player_created]                = on_player_created,
    [defines.events.on_player_changed_force]          = on_player_changed_force,
    [defines.events.on_player_driving_changed_state]  = on_player_driving_changed_state,
    [defines.events.on_player_used_spidertron_remote] = on_player_used_spider_remote,

    [defines.events.on_player_mined_entity]           = on_player_mined_entity,
    [defines.events.on_pre_player_mined_item]         = on_pre_player_mined_item,
    [defines.events.on_lua_shortcut]                  = on_lua_shortcut,
    [defines.events.on_player_deconstructed_area]     = on_player_deconstructed_area,
    [defines.events.on_pre_build]                     = on_pre_build,
	[defines.events.on_research_finished]             = on_research_finished,
    [defines.events.on_entity_damaged]                = on_entity_damaged,
}

lib.on_load = function()
    script_data = storage.companion or script_data
    for unit_number, companion in pairs(script_data.companions) do
        setmetatable(companion, Companion.metatable)
    end
end

---------------------------- Migrations ----------------------------------

local function migrate_companions()
    for unit_number, companion in pairs(script_data.companions) do
        companion.last_idle_line_tick = companion.last_idle_line_tick or game.tick
        companion.next_forced_idle_tick = companion.next_forced_idle_tick or (game.tick + 1800)
        companion.job_done_tick = companion.job_done_tick or nil
        companion.job_done_announced = companion.job_done_announced or false
    end
end

local string = string
local table = table

local version_pattern = "%d+"
local version_format = "%02d"

function format_version(version, format)
-- from FLIB
  if version then
    format = format or version_format
    local tbl = {}
    for v in string.gmatch(version, version_pattern) do
      tbl[#tbl + 1] = string.format(format, v)
    end
    if next(tbl) then
      return table.concat(tbl, ".")
    end
  end
  return nil
end

function is_newer_version(old_version, current_version, format)
-- from FLIB
  local v1 = format_version(old_version, format)
  local v2 = format_version(current_version, format)
  if v1 and v2 then
    if v2 > v1 then
      return true
    end
    return false
  end
  return nil
end

function run(old_version, migrations, format, ...)
-- from FLIB
  local migrate = false
  for version, func in pairs(migrations) do
    if migrate or is_newer_version(old_version, version, format) then
      migrate = true
      func(...)
    end
  end
end

function on_config_changed(e, migrations, mod_name, ...) 
-- from FLIB
-- only runs if THIS mod is what changed, rather than if ANY mod changed like vanilla on_configuration_changed()
  local changes = e.mod_changes[mod_name or script.mod_name]
  local old_version = changes and changes.old_version
  if old_version then
    if migrations then
      run(old_version, migrations, nil, ...)
    end
    return true
  end
  return false
end

local function create_popup(player, message)
  if player.gui.center.companion_popup then
    player.gui.center.companion_popup.destroy()
  end
  local frame = player.gui.center.add{
    type = "frame",
    name = "companion_popup",
    caption = "Companion Drones 3.0",
    direction = "vertical"
  }
  local textbox = frame.add{
    type = "text-box",
    text = message,
    read_only = true,
    word_wrap = true,
  }
  textbox.style.width = 280
  textbox.style.height = 220
  textbox.style.top_padding = 3
  textbox.style.bottom_padding = 3
  textbox.style.left_padding = 1
  textbox.style.right_padding = 5
  textbox.style.font = "default-bold"
  local ok_button = frame.add{
    type = "button",
    name = "companion_popup_ok",
    caption = "OK"
  }
  ok_button.style.width = 280
  ok_button.style.top_margin = 10
end

local function on_gui_click(event)
  local player = game.players[event.player_index]
  if event.element and event.element.name == "companion_popup_ok" then
    if player.gui.center.companion_popup then
      player.gui.center.companion_popup.destroy()
    end
  end
end

local function show_update_popup()
    for _, player in pairs(game.players) do
        set_companion_stats(player)
        create_popup(player, [[
            MAJOR MOD UPDATE DETECTED!

            Please check the changelog and/or
            the mod description to see all the 
            new changes, or at least check 
            the settings to see what's new.

            This popup will never show again
            (once you save at least)
        ]])
    end
end

local migrations = {
    ["3.0.0"] = function()
        for _, player in pairs(game.players) do
            reset_companions_for_player(player)
        end
        show_update_popup()
    end,
}

local function check_challenge_mode()
    if challenge_mode and (mode == 0 or mode == 2) then
        game.print("[WARNING] IMPORTANT MESSAGE FOR COMPANION DRONE CHALLENGE MODE USERS:")
        game.print("[WARNING] The 'challenge mode' setting will be removed soon, replaced by the 'set mode' setting.")
        game.print("[WARNING] You MUST switch 'set mode' to mode 1 or 3 OR uncheck 'challenge mode' or this mod will CRASH in the near future.")
    end
end

script.on_event(defines.events.on_gui_click, on_gui_click)

script.on_configuration_changed(function(e)
    bind_storage()
    storage.companion_update_interval = settings.startup["set-update-interval"].value or 5
    reseed_defaults()
    for player_index, player_data in pairs (script_data.player_data) do

        if player_data.last_search_offset then
            player_data.last_job_search_offset = player_data.last_search_offset
            player_data.last_attack_search_offset = player_data.last_search_offset
            player_data.last_search_offset = nil
        end

        local player = game.get_player(player_index)
        if player then
            local gui = player.gui.relative
            if gui.companion_gui then
                gui.companion_gui.destroy()
            end

            if not player.is_shortcut_available("companion-attack-toggle") then
                player.set_shortcut_available("companion-attack-toggle", true)
                if mode == 1 or mode == 3 then
                    player.set_shortcut_toggled("companion-attack-toggle", false)
                else
                    player.set_shortcut_toggled("companion-attack-toggle", true)
                end
            end

            if not player.is_shortcut_available("companion-construction-toggle") then
                player.set_shortcut_available("companion-construction-toggle", true)
                player.set_shortcut_toggled("companion-construction-toggle", true)
            end
        else
            script_data.player_data[player_index] = nil
        end

    end

    for k, companion in pairs (script_data.companions) do
        if (companion.player and companion.player.valid) then
            companion.speed = companion.speed or 0
            companion:clear_passengers()
            companion.entity.minable = true
        else
            companion.entity.destroy()
            script_data.companions[k] = nil
        end
    end

    if script_data.tick_updates then
        script_data.tick_updates = nil
    end

    script_data.specific_job_search_queue = script_data.specific_job_search_queue or {}

    reschedule_companions()
	migrate_companions()
    check_challenge_mode()
	on_config_changed(e, migrations)
end)


----------------------------------- Commands and Remotes ------------------------------------

local jetpack_remote =
{
    on_character_swapped = function(event)
        local new_character = event.new_character
        if not (new_character and new_character.valid) then return end
        if new_character.player then
            adjust_follow_behavior(new_character.player)
        end
    end
}

script.on_event(defines.events.on_string_translated, function(event)
	local key = event.localised_string[1]
	if key and event.translated and key:match("^.+%.0$") then
		local base_key = key:match("^(.-)%.0$")
		storage.dialogue_counts = storage.dialogue_counts or {}
		storage.dialogue_counts[base_key] = tonumber(event.result) or 1
	end
end)

function Companion:debug_stats_state(prefix)
    local msg = string.format(
        "[%s] tick=%d unit=%s | speed=%s damage=%s range=%s count=%s",
        prefix or "",
        game.tick,
        tostring(storage.unit_number),
        tostring(storage.base_speed),
        tostring(storage.attack_count),
        tostring(storage.max_distance),
        tostring(storage.max_companions)
    )
    log(msg)
    self.player.print(msg)
end

function Companion:debug_report_state(prefix)
    local msg = string.format(
        "[%s] tick=%d unit=%s | wants=%s can_construct=%s surface_ok=%s cell=%s is_busy=%s robots=%d pos=(%.1f,%.1f) actv=%s itick=%s",
        prefix or "",
        game.tick,
        tostring(self.unit_number),
        tostring(self:player_wants_construction()),
        tostring(self.can_construct),
        tostring(self.entity.surface == self.player.physical_surface),
        tostring(self.entity.logistic_cell ~= nil),
        tostring(self:is_busy()),
        table_size(self.robots or {}),
        self.entity.position.x, self.entity.position.y,
        tostring(self.active),
        tostring(self.next_idle_line_tick)
    )
    log(msg)
    self.player.print(msg)
end

remote.add_interface("companion_speed", {
    set_factor = function(v)
        if type(v) == "number" and v > 0 then
            storage.companion_speed_factor = v
            for _, comp in pairs(script_data.companions) do
                if comp and comp.entity and comp.entity.valid then
                    comp._last_speed_factor = nil
                end
            end
        end
    end,
    get_factor = function() return storage.companion_speed_factor or 1.0 end,
})

remote.add_interface("companion_remote_for_jetpack", jetpack_remote)

commands.add_command("reschedule_companions", "If they get stuck or something", reschedule_companions)

commands.add_command("reset_companions",
"Fully reset your companion(s) to brand-new state.",
function(cmd) 
    local player = game.get_player(cmd.player_index)
    if player then reset_companions_for_player(player) end
end)

--Various debug commands:
commands.add_command("debug_companion", 
"Debug companion state", 
function(cmd)
    if not debug_mode then game.print("You cannot use this command while Debug mode is disabled") return end 
    local player = game.get_player(cmd.player_index)
    if not player then return end
    local player_data = script_data.player_data[player.index]
    if not player_data then player.print("No player_data") return end
    for unit_number in pairs(player_data.companions) do
        local companion = script_data.companions[unit_number]
        if companion then
            companion:debug_report_state("console")
            companion:debug_stats_state("stats")
        end
    end
end)

commands.add_command("swap_equipment", 
"Takes any input equipment name and replaces it with output name. Takes two arguments.", 
function(cmd)
    if not debug_mode then game.print("You cannot use this command while Debug mode is disabled") return end
	local errmsg = "Usage: /swap_equipment <old-equipment-literal-name> <new-equipment-literal-name>"
    local player = game.get_player(cmd.player_index)
    local companion = script_data.companions[next(script_data.player_data[player.index].companions)]
    local grid = companion:get_grid()
	if not cmd.parameter then
		game.print(errmsg)
		return
	end
	local input, output = cmd.parameter:match("^(%S+)%s+(%S+)$") 
	-- splits the combined string of "old_equipment_name new_equipment_name" and separates them where the whitespace is
	-- then assigns them to input and output respectively.
	if not input or not output or type(input) ~= "string" or type(output) ~= "string" then
		game.print(errmsg)
		return
	end
	swap_equipment(grid, input, output)
end)

commands.add_command("companion_reseed_defaults",
"Refreshes companion stats in storage table.",
function(cmd)
    if not debug_mode then game.print("You cannot use this command while Debug mode is disabled") return end
    local player = game.get_player(cmd.player_index)
    if player then reseed_defaults(player) end
end)

commands.add_command("companion_speed_factor",
"Set companion speed multiplier (>0). Decimals between 0 and 1 will slow the drone.",
function(cmd)
    if not debug_mode then game.print("You cannot use this command while Debug mode is disabled") return end
    local v = tonumber(cmd.parameter)
    if v and v > 0 then
        remote.call("companion_speed", "set_factor", v)
        game.print({"", "[Companion] speed factor set to ", v})
    else
        local cur = remote.call("companion_speed", "get_factor")
        game.print({"", "[Companion] current speed factor = ", cur, " (usage: /companion_speed_factor <number>)"})
    end
end)

return lib

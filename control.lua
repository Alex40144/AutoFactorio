require "util"
local task = require("tasks")
local research = require("research")

dbg = true
enabled = true
route = nil
local current_task = 0
local current_research = 0
local destination = {x=0, y=0}

-----------------------------------------------------------------------------------------------------

function debug(msg)
    if dbg then
        game.print(msg)
    end
    return true
end

function debugtable(msg)
    game.print(serpent.line(msg))
end

function error(msg)
    game.print(msg)
end

-----------------------------------------------------------------------------------------------------

function calcbearing(p, from, to)
    deltax = to.x - from.x
    deltay = to.y - from.y

    bearing = math.atan2(deltay,deltax)  --radians
    if bearing < 0 then
        bearing = bearing + 2* math.pi
    end
    x = 2 * math.cos(bearing)  --radians
    y = 2 * math.sin(bearing)  --radians

    bearing_deg = math.floor(bearing * 57.2957795)

    if bearing_deg > 270 then
        bearing_deg = bearing_deg - 270
    else
        bearing_deg = bearing_deg + 90
    end

    return bearing_deg
end



function walk(p, location)
    local bearing = calcbearing(p, p.position, location)
    local direction = math.floor(bearing/45 + 0.5)

    if direction == 0 then
        p.walking_state = {walking = true, direction = defines.direction.north}
    elseif direction == 1 then
        p.walking_state = {walking = true, direction = defines.direction.northeast}
    elseif direction == 2 then
        p.walking_state = {walking = true, direction = defines.direction.east}
    elseif direction == 3 then
        p.walking_state = {walking = true, direction = defines.direction.southeast}
    elseif direction == 4 then
        p.walking_state = {walking = true, direction = defines.direction.south}
    elseif direction == 5 then
        p.walking_state = {walking = true, direction = defines.direction.southwest}
    elseif direction == 6 then
        p.walking_state = {walking = true, direction = defines.direction.west}
    elseif direction == 7 then
        p.walking_state = {walking = true, direction = defines.direction.northwest}
    elseif direction == 8 then
        p.walking_state = {walking = true, direction = defines.direction.north}
    end
end

function path(p, location)
    p.surface.request_path({
        bounding_box = p.character.prototype.collision_box,
        collision_mask = p.character.prototype.collision_mask,
        start = p.position,
        radius = 3.5,
        goal = location,
        force = p.force,
        can_open_gates = true,
        entity_to_ignore = p.character,
        pathfinding_flags = {
            allow_destroy_friendly_entities = false,
            cache = false,
            prefer_straight_paths = true,
            low_priority = false
        },
    })
    return
end

--this is needed as the reach distance for mining is shorten than placing/interracting 
function minepath(p, location)
    p.surface.request_path({
        bounding_box = p.character.prototype.collision_box,
        collision_mask = p.character.prototype.collision_mask,
        start = p.position,
        radius = 0.5,
        goal = location,
        force = p.force,
        can_open_gates = true,
        entity_to_ignore = p.character,
        pathfinding_flags = {
            allow_destroy_friendly_entities = false,
            cache = false,
            prefer_straight_paths = true,
            low_priority = false
        },
    })
    return
end



function craft(p, item, count)
    if count == -1 then
        count = p.get_craftable_count(item)
    end
    crafted = p.begin_crafting{recipe = item, count = count}
    debug("crafting " .. count .. " " .. item)
    if crafted < count then
        error("Did not craft full count of " .. item)
    end
    return true
end

function mine(p, location)
    --check if there is an item where we are going to mine.
    --used to detect when mining has been finished so we can move on. This means you can't mine tiles
    if p.can_place_entity{name = "transport-belt", position = location, direction = defines.direction.north} then
        delroute(p)
        return true
    else
        p.update_selected_entity(location)
        --can we reach to mine?
        if not p.can_reach_entity(p.selected) then
            if not route then
                minepath(p, location) 
            end
            return false
        end
        p.mining_state = {mining = true, position = location}
    end
end

function build(p, location, item, direction)
    --can_place_entity already checks player reach
    --if out of reach, placing fails, but keep trying.
    --we can use this to place whilst walking as it will keep trying until it succeeds.
    if p.get_item_count(item) < 1 then
        error("did not have " .. item)
        return false
    elseif p.surface.can_fast_replace{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player", fast_replace = true, player = p}
        if built then
            delroute(p)
            --be honest
            p.remove_item{name=item, count=1}
            return true
        else
            return false
        end
    elseif p.can_place_entity{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player"}
        if built then
            delroute(p)
            --be honest
            p.remove_item{name=item, count=1}
            return true
        else
            return false
        end
    -- we might be stood where we want to place the object
    elseif p.position.x > location.x-2 and p.position.x < location.x+2 and p.position.y > location.y-2 and p.position.y < location.y+2 then
            path(p, {location.x-p.position.x-4, location.y-p.position.y+2})
    else
        if not route then
            path(p, location)
        end
        return false
    end
end

function take(p, location, item, count, skip, inv)
    p.update_selected_entity(location)

    if not p.can_reach_entity(p.selected) then
        if not route then
            path(p, location)
        end
        return false
    end

    inv = p.selected.get_inventory(inv)
    if not inv then
        error("no inventory found")
        return false
    end
    ammountininv = inv.get_item_count(item)
    if ammountininv < 1 then
        error("did not take any " .. item)
        if skip == true then
            delroute(p)
            return true
        else
            return false
        end
    elseif count == -1 then
        --take everything
        p.insert{name=item, count=ammountininv}
        inv.remove{name=item, count=ammountininv}
        delroute(p)
        return true
    else
        take = math.min(count, ammountininv)
        p.insert{name=item, count=take}
        inv.remove{name=item, count=take}
        error("didn't take requested ammount of " .. item .. " only took "  .. take .. " of " .. count)
        delroute(p)
        return true
    end
end

function put(p, item, count, location, destinv)
    p.update_selected_entity(location)
    if not p.can_reach_entity(p.selected) then
        if not route then
            path(p, location)
        end
        return false
    end

    local countininventory = p.get_item_count(item)
    local destination = p.selected.get_inventory(destinv)

    --we can only move what we have
    tomove = math.min(countininventory, count)

    --this is to check if tomove = 0 as .insert doesn't like it
    if tomove < 1 then
        error("did not put any " .. item)
    else
        inserted = destination.insert{name = item, count = tomove}
        --be honest
        p.remove_item{name=item, count=inserted}
    end
    delroute(p)
    return true

end

function time(p)
    local seconds = p.online_time / 60
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    error(hours..":"..mins..":"..secs)
end

function science(p)
    p.force.add_research(research[current_research])
    return true
end

function recipe(p, location, recipe)
    p.update_selected_entity(location)
    if not p.can_reach_entity(p.selected) then
        if not route then
            path(p, location)
        end
        return false
    else
        delroute(p)
    end

    local contents = p.selected.set_recipe(recipe)
    if contents then
        for name, count in pairs(contents) do
            p.insert{name = name, count = count}
        end
    end
    return true
end

function speed(p, speed)
    game.speed = speed
    error("game speed set to " .. speed)
    return true
end

function delroute(p)
    route = nil
    p.walking_state = {walking = false}
end

function within(one, two)
    if one.x>two.x-0.4 and one.x<two.x+0.4 and one.y>two.y-0.4 and one.y<two.y+0.4 then
        return true
    else
        return false
    end
end


-----------------------------------------------------------------------------------------------------

function doTask(p, tasks)
    if tasks[1] == "build" then
        return build(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "craft" then
        return craft(p,tasks[2], tasks[3])
    elseif tasks[1] == "mine" then
        return mine(p, tasks[2])
    elseif tasks[1] == "research" then
        return science(p)
    elseif tasks[1] == "put" then
        return put(p, tasks[2], tasks[3], tasks[4], tasks[5])
    elseif tasks[1] == "take" then
        return take(p, tasks[2], tasks[3], tasks[4], tasks[5], tasks[6])
    elseif tasks[1] == "recipe" then
        return recipe(p, tasks[2], tasks[3])
    elseif tasks[1] == "speed" then
        return speed(p, tasks[2])
    elseif tasks[1] == "time" then
        --output current run time
        time(p)
        return true
    elseif tasks[1] == "end" then
        --end the run
        debug("ending run")
        return "end"
    end
end

-----------------------------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(event)
    --get player
    local p = game.players[1]

    --only run if we are allowed to
    if enabled == true then
        --game.print(current_task) -- +3 for line number
        if p.walking_state.walking == false then
            if route then
                if #route > 2 then
                    walk(p, route[2].position)
                    if within( p.position, route[2].position) then
                        table.remove(route, 1)
                    end
                end
            end
            result = doTask(p, task[current_task])
            if result ~= nil then
                if result == true then
                    current_task = current_task + 1
                elseif result == "end" then
                    enabled = false
                end
            end

        else
            -- if the next task is mining or walking, we can do that whilst moving.
            if task[current_task][1] ~= "mine" or task[current_task][1] ~= "walk" then
                result = doTask(p, task[current_task])
                if result ~= nil then
                    if result == true then
                        current_task = current_task + 1
                    end
                end
            end
        end
    end
end)

--when we have out path

script.on_event(defines.events.on_script_path_request_finished, function(event)
    if event.try_again_later then
        error("pathing failed")
    elseif event.path then
        route = event.path
        if dbg then
            
            local i = 1
            rendering.clear()
            while i < #route do
                rendering.draw_line{surface = game.players[1].surface, from = route[i].position, to = route[i+1].position, color = {g=1}, width = 2}
                i = i+1
            end
        end
    else
        error("Pathing failed")
    end


end)


--add on research ended. use file to store order of research tasks.

script.on_event(defines.events.on_research_finished, function()
    debug("starting next research")
    local p = game.players[1]
    current_research = current_research + 1
    p.force.add_research(research[current_research])
end)
require "util"
local task = require("tasks")
local research = require("research")

local dbg = false
enabled = true  --this one is global
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
    if dbg then
        game.print(serpent.line(msg))
    end
    return true
end

function error(msg)
    game.print(msg)
end

-----------------------------------------------------------------------------------------------------

function walk(p, deltax, deltay)
    if deltax > 0.2 then
        if deltay > 0.2 then
            return{walking = true, direction = defines.direction.southeast}
        elseif deltay < -0.2 then
            return{walking = true, direction = defines.direction.northeast}
        else
            return{walking = true, direction = defines.direction.east}
        end
    elseif deltax < -0.2 then
        if deltay > 0.2 then
            return{walking = true, direction = defines.direction.southwest}
        elseif deltay < -0.2 then
            return{walking = true, direction = defines.direction.northwest}
        else
            return{walking = true, direction = defines.direction.west}
        end
    elseif deltay > 0.2 then
        return{walking = true, direction = defines.direction.south}
    elseif deltay < -0.2 then
        return{walking = true, direction = defines.direction.north}
    else
        return{walking = false}
    end
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
    --mainly used to detect when mining has been finished so we can move on.
    if p.can_place_entity{name = "transport-belt", position = location, direction = defines.direction.north} then
        debug("mined")
        return true
    else
        p.update_selected_entity(location)
        p.mining_state = {mining = true, position = location}
    end
end

function build(p, location, item, direction)
    --create_entity already checks player reach
    --if out of reach, placing fails, but keep trying.
    --we can use this to place whilst walking as it will keep trying until it succeeds.
    --we should probably check that we have the item
    if p.get_item_count(item) < 1 then
        error("did not have " .. item)
        return false
    elseif p.surface.can_fast_replace{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player", fast_replace = true, player = p}
        if built then
            --be honest
            p.remove_item{name=item, count=1}
            return true
        else
            return false
        end
    elseif p.can_place_entity{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player"}
        if built then
            --be honest
            p.remove_item{name=item, count=1}
            return true
        else
            return false
        end
    else
        error("Placing failed: " .. item)
        return false
    end
end

function take(p, location, item, count, skip, inv)
    p.update_selected_entity(location)

    if not p.can_reach_entity(p.selected) then
        return false
    end

    inv = p.selected.get_inventory(inv)
    if not inv then
        return false
    end
    ammountininv = inv.get_item_count(item)
    if ammountininv < 1 then
        error("did not take any " .. item)
        if skip == true then
            return true
        else
            return false
        end
    elseif count == -1 then
        --we can be truthful here. NO CHEATING
        p.insert{name=item, count=ammountininv}
        inv.remove{name=item, count=ammountininv}
        return true
    else
        take = math.min(count, ammountininv)
        p.insert{name=item, count=take}
        inv.remove{name=item, count=take}
        error("didn't take requested ammount of " .. item .. " only took "  .. take .. " of " .. count)

    end
end

function put(p, item, count, location, destinv)
    p.update_selected_entity(location)
    if not p.can_reach_entity(p.selected) then
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
        inserted = destination.insert{name = item, count = math.min(countininventory, count)}
        --be honest
        p.remove_item{name=item, count=inserted}
    end
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
        return false
    end

    local contents = p.selected.set_recipe(recipe)
    if contents then
        for name, count in pairs(contents) do
            p.insert{name = name, count = count}
        end
    end
    return true
end

-----------------------------------------------------------------------------------------------------

function doTask(p, pos, tasks)
    --debugtable(tasks)
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
    --get player's position
    local pos = p.position

    --only run if we are allowed to
    if enabled == true then
        game.print(current_task)
        if p.walking_state.walking == false then
            if task[current_task][1] == "walk" then
                destination = task[current_task][2]
                local destinationdelta = {x=destination.x - pos.x, y=destination.y - pos.y}
                walking = walk(p, destinationdelta.x, destinationdelta.y)
                current_task = current_task + 1
            else
                result = doTask(p, pos, task[current_task])
                if result ~= nil then
                    if result == true then
                        current_task = current_task + 1
                    elseif result == "end" then
                        enabled = false
                    end
                end
            end

        else
            --we are still walking so let's continue to walk
            walking = walk(p, destination.x-pos.x, destination.y-pos.y)
            -- if the next task is mining or walking, we can do that whilst moving.
            if task[current_task][1] ~= "mine" or task[current_task][1] ~= "walk" then
                result = doTask(p, pos, task[current_task])
                if result ~= nil then
                    if result == true then
                        current_task = current_task + 1
                    end
                end
            end
        end
    end
    p.walking_state = walking
end)


--add on research ended. use file to store order of research tasks.

script.on_event(defines.events.on_research_finished, function()
    debug("starting next research")
    local p = game.players[1]
    current_research = current_research + 1
    p.force.add_research(research[current_research])
end)
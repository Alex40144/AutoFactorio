require "util"
local task = require("tasks")

local dbg = true
enabled = true  --this one is global
local current_task = 0
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
        debug("At destination")
        return{walking = false}
    end
end

function craft(p, item, count)
    p.begin_crafting{recipe = item, count = count}
    debug(string.format("crafting " .. count .. " " .. item))
    return true
end

function mine(p, location)
    --check if there is an item where we are going to mine.
    --mainly used to detect when mining has been finished so we can move on.
    if p.can_place_entity{name = "transport-belt", position = location, direction = defines.direction.north} then
        return true
    else
        p.update_selected_entity(location)
        p.mining_state = {mining = true, position = location}
    end
end

function build(p, location, item, direction)
    if p.can_place_entity{name = item, position = location, direction = direction} then
        p.surface.create_entity{name = item, position = location, direction = direction, force="player"}
        return true
    else
        error("could not place " .. item)
    end
end

function take(p, location, item, count, inv)
    p.update_selected_entity()

    if not p.can_reach_entity() then
        return false
    end

    inv = p.selected.get_inventory(slot)
    ammountininv = inv.get_item_count(item)
    --take all the contents
    if count == -1 then
        --we can be truthful here. NO CHEATING
        p.insert{name=item, count=ammountininv}
        inv.remove{name=item, count=ammountininv}
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

    inserted = destination.insert{name = item, count = math.min(countininventory, count)}

    if inserted == 0 then
        debug("Inserted 0 " .. item)
    end
    return true

end

-----------------------------------------------------------------------------------------------------

function doTask(p, pos, tasks)
    --debugtable(tasks)
    if tasks[1] == "build" then
        --Build
        debug("build task started")
        return build(p, tasks[2], tasks[3], tasks[4])

    elseif tasks[1] == "craft" then
        --craft
        debug("crafting task started")
        return craft(p,tasks[2], tasks[3])

    elseif tasks[1] == "mine" then
        debug("mining task started")
        return mine(p, tasks[2])
    elseif tasks[1] == "put" then
        debug("put task started")
        return put(p, tasks[2], tasks[3], tasks[4], tasks[5])
    elseif tasks[1] == "take" then
        debug("take task started")
        return take(p, tasks[2], tasks[3], tasks[4], tasks[5])
    elseif tasks[1] == "debug" then
        --output current run time
        return debug(string.format("Current run time %f seconds", p.online_time / 60))

    elseif tasks[1] == "walk" then
        --walk
        debug("walking task started")
        destination = tasks[2]
        local destinationdelta = {x=destination.x - pos.x, y=destination.y - pos.y}
        return walk(p, destinationdelta.x, destinationdelta.y)

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
        if p.walking_state.walking == false then
            --if we are stopped
            result = doTask(p, pos, task[current_task])
            if result ~= nil then
                if (type(result) == "table") then
                    if result.walking == true then
                        --do we want to continue walking
                        walking = result
                    elseif result.walking == false then
                        --stopping walking
                        current_task = current_task + 1
                    end
                elseif result == true then
                    current_task = current_task + 1
                elseif result == "end" then
                    enabled = false
                end
            end


        else
            --we are still walking so let's continue to walk
            walking = walk(p, destination.x-pos.x, destination.y-pos.y)
            -- if the next task is building, then we can do that whilst moving.
        end
    end
    p.walking_state = walking
end)


script.on_init(function()
    debug("player has joined game")
    walking = {walking=false}
    enabled = true
end)

--add on research ended. use file to store order of research tasks.
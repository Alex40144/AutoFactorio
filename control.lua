require "util"
local task = require("tasks")

local dbg = true
enabled = true  --this one is global
local current_task = 1
local destination = {x=0, y=0}

function debug(msg)
    if dbg then
        game.print(msg)
    end
end

function craft(p, item, count)
    p.begin_crafting{recipe = item, count = count}
    debug(string.format("crafting %f %f", count, item))
end

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

function mine(p, location)
    p.update_selected_entity(location)
    p.mining_state = {mining = true, position = location}
end

function build(p, position, item, direction)
    -- Build things
end

function doTask(p, pos, tasks)
    if tasks[1] == "build" then
        debug("build task started")
        build(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "craft" then
        debug("crafting task started")
        craft(p,tasks[2], tasks[3])
    elseif tasks[1] == "debug" then
        debug(string.format("Current run time %f seconds", p.online_time / 60))
        return false
    elseif tasks[1] == "walk" then
        debug("walking task started")
        destination = {x=task[current_task].x, y=task[current_task].y}
        local destinationdelta = {x=destination.x - pos.x, y=destination.y - pos.y}
        return walk(p, destinationdelta.x, destinationdelta.y)
    elseif tasks[1] == "end" then
        return "end"
    end
end

script.on_event(defines.events.on_tick, function(event)
    local p = game.players[1]
    local pos = p.position

    --enable on first run

    if enabled == true then
        --if we are already walking
        if p.walking_state.walking == false then
            --if we are stopped
            result = doTask(p, pos, task[current_task])
            if result ~= nil then
                if result.walking ~= nil then
                    if result.walking == true then
                        --do we want to continue walking
                        walking = result
                    elseif result.walking == false then
                        --stopping walking
                        current_task = current_task + 1
                    end
                elseif result == false then
                    current_task = current_task + 1
                elseif result == "end" then
                    enabled = false
                end
            end


        else
            --continue to walk
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
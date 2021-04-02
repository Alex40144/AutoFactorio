require "util"
local taskList = require("tasks")
local research = require("research")
local Position = require("__stdlib__/stdlib/area/position")
local Area = require("__stdlib__/stdlib/area/area")

dbg = true
enabled = false
route = nil
path_progress = 1
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



function path(p, location, radius)

    local x1 = p.character.bounding_box.left_top.x - p.position.x
    local y1 = p.character.bounding_box.left_top.y - p.position.y
    local x2 = p.character.bounding_box.right_bottom.x - p.position.x
    local y2 = p.character.bounding_box.right_bottom.y - p.position.y
    local bounding = {{x1, y1},{x2, y2}}

    p.surface.request_path({
        bounding_box = bounding,
        collision_mask = p.character.prototype.collision_mask,
        start = p.position,
        radius = radius,
        goal = location,
        force = p.force,
        entity_to_ignore = p.character,
        path_resolution_modifier = 3,
        pathfinding_flags = {
            allow_paths_through_own_entities = true,
            prefer_straight_paths = false,
            low_priority = false
        },
    })
    return
end

function moveAlongPath(p, path)
    local nextNode = path[path_progress]
    if nextNode == nil then
        return false
    end

    local nodeDistance = Position.distance(p.position, nextNode.position)

    while nodeDistance <= p.character_running_speed * 4 do
        path_progress = path_progress + 1
        nextNode = path[path_progress]
        if nextNode == nil then
            return true
        end
        nodeDistance = Position.distance(p.position, nextNode.position)
    end
    local direction = Position.complex_direction_to(p.position, nextNode.position, true)
    p.character.walking_state = {walking = true, direction = direction}
end



function craft(p, item, count)
    if count == -1 then --craft as many as possible
        count = p.get_craftable_count(item)
    end

    crafted = p.begin_crafting{recipe = item, count = count}
    debug("crafting " .. count .. " " .. item)

    if crafted < count then
        error("Did not craft full count of " .. item)
    end
    return true
end

function calculateCraft(p, ...)
    local arg = ...

    if not arg.item and not arg.count then
        local step = current_task + 1
        local iterate = true
        local toCraft = {}
        while iterate do
            if taskList[step][1] == "build" then
                local item = taskList[step][3]
                if not toCraft[item] then
                    toCraft[item] = 1
                else
                    toCraft[item] = toCraft[item] + 1
                end
            elseif taskList[step][1] == "craft" then
                iterate = false
            end
            step = step + 1
        end

        for key,value in pairs(toCraft) do
            if game.recipe_prototypes[key].products[1].amount ~= 1 then
                value = value / game.recipe_prototypes[key].products[1].amount
                value = math.ceil(value)
            end
            if not craft(p, key, value) then
                error("failed to craft all that was needed")
                return false
            end
        end
        return true
    else
        return craft(p, arg.item, arg.count)
    end
end
            


function mine(p, location)
    --check if there is an item where we are going to mine.
    --used to detect when mining has been finished so we can move on. This means you can't mine surface stuff
    if not route then
        path(p, location, 4)
    end
    if p.can_place_entity{name = "transport-belt", position = location, direction = defines.direction.north} then
        delroute(p)
        return true
    else
        p.update_selected_entity(location)
        if p.selected ~= nil then
            if not p.can_reach_entity(p.selected) then
                if not route then
                    path(p, p.selected.selection_box.right_bottom, 0.5) 
                end
                return false
            end
        else
            error("no entity selected")
            error(location)
            path(p, location, 4) 
        end
        p.mining_state = {mining = true, position = location}
    end
end

function build(p, location, item, direction)
    local entitybounding = game.entity_prototypes[item].collision_box
    local entitycollision = Area.offset(entitybounding, location)

    local playercollision = p.character.bounding_box

    if not route then
        path(p, location, 4)
    end

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
            error("Fast replace failed")
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
            error("building failed")
            return false
        end
    -- we might be stood where we want to place the object
    elseif overlap(entitycollision, playercollision) then
        error("colliding with build location")
        path(p, {p.position.x+5, p.position.y+5}, 6)
    end
    return false
end

function take(p, location, count, skip)
    p.update_selected_entity(location)
    item = nil

    if not p.can_reach_entity(p.selected) then
        if not route then
            path(p, location, 3)
        end
        return false
    end

    --check if there is anything in the inventory
    if next(p.selected.get_output_inventory().get_contents()) == nil then
        error("There wasn't anything in the entity")
        if skip == true then
            delroute(p)
            return true
        else
            return false
        end
    end
    debugtable(p.selected.get_output_inventory().get_contents())
    for key, value in pairs(p.selected.get_output_inventory().get_contents()) do
        item = key
        ammountininv = tonumber(value)
    end


    if count == -1 then  --take everything
        p.insert{name=item, count=ammountininv}
        p.selected.remove_item{name=item, count=ammountininv}
        delroute(p)
        return true
    elseif count < ammountininv then
        p.insert{name=item, count=count}
        p.selected.remove_item{name=item, count=count}
        delroute(p)
        return true
    else
        take = math.min(count, ammountininv)
        p.insert{name=item, count=take}
        p.selected.remove_item{name=item, count=take}
        error("didn't take requested ammount of " .. item .. " only took "  .. take .. " of " .. count)
        delroute(p)
        return true
    end
end

function put(p, item, count, location)
    p.update_selected_entity(location)
    if not p.can_reach_entity(p.selected) then
        if not route then
            path(p, location, 3)
        end
        return false
    end

    local playerCount = p.get_item_count(item)

    --this is to check if tomove = 0 as .insert doesn't like it
    if playerCount < 1 then
        error("did not put any "  .. item)
    elseif count < playerCount then --we have enough items to move
        inserted = p.selected.insert{name = item, count = count}
        p.remove_item{name=item, count=inserted}
    else --we don't have enough items to move, we will do all
        tomove = math.min(playerCount, count)
        inserted = p.selected.insert{name = item, count = tomove}
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
            path(p, location, 5)
        end
        return false
    end

    local contents = p.selected.set_recipe(recipe)
    if contents then
        for name, count in pairs(contents) do
            p.selected.insert{name = name, count = count}
        end
    end
    delroute(p)
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

--10000 offset is to negate negative numbers, they make it more complicated.
function overlap(area1, area2)
    if area1.left_top.x+10000 > area2.right_bottom.x+10000 or area2.left_top.x+10000 > area1.right_bottom.x+10000 then
        return false
    elseif area1.left_top.y+10000 > area2.right_bottom.y+10000 or area2.left_top.y+10000 > area1.right_bottom.y+10000 then
        return false
    end

    -- we can assume that they are overlapping
    return true
end

-----------------------------------------------------------------------------------------------------

function doTask(p, tasks)
    if tasks[1] == "build" then
        return build(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "craft" then
        --return craft(p,tasks[2], tasks[3])
        return calculateCraft(p, {item=tasks[2], count=tasks[3]})
    elseif tasks[1] == "mine" then
        return mine(p, tasks[2])
    elseif tasks[1] == "research" then
        return science(p)
    elseif tasks[1] == "put" then
        return put(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "take" then
        return take(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "recipe" then
        return recipe(p, tasks[2], tasks[3])
    elseif tasks[1] == "speed" then
        return speed(p, tasks[2])
    elseif tasks[1] == "time" then
        time(p)
        return true
    elseif tasks[1] == "end" then
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
                moveAlongPath(p, route)
            end
            debug(current_task+2)
            result = doTask(p, taskList[current_task])
            if result ~= nil then
                if result == true then
                    current_task = current_task + 1
                elseif result == "end" then
                    enabled = false
                end
            end

        else
            -- if the next task is not mining then we can do other ones whilst moving.
            if taskList[current_task][1] ~= "mine" then
                debug(current_task+2)
                result = doTask(p, taskList[current_task])
                if result ~= nil then
                    if result == true then
                        current_task = current_task + 1
                    elseif result == "end" then
                        enabled = false
                    end
                end
            end
        end
    end
end)

script.on_event(defines.events.on_cutscene_cancelled, function(event)
    enabled = true


end)

--when we have out path

script.on_event(defines.events.on_script_path_request_finished, function(event)
    if event.try_again_later then
        error("pathing failed")
    elseif event.path then
        path_progress = 1
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
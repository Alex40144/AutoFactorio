--ToDo list
--fix Crafting
--change miner phase to use get function
--function to restock coal / copper-plates


------------------------------------------------------------------------------------------------------
require "util"
local taskList = require("tasks")
local research = require("research")
local Position = require("__stdlib__/stdlib/area/position")
local Area = require("__stdlib__/stdlib/area/area")

dbg = true
enabled = false
route = nil

colliding = false

counter = 0

local current_task = 0
current_research = 0
local destination = {x=0, y=0}

resources = {}

-----------------------------------------------------------------------------------------------------

function debug(msg)
    if dbg then
        game.print(msg)
    end
end

function debugTable(msg)
    if next(msg) == nil then
        game.print("table is empty")
        return
    end
    game.print(serpent.line(msg))
end

function error(msg)
    game.print(msg)
end

-----------------------------------------------------------------------------------------------------

function pick_random(t)
	local keys = {}
	local i = 1
	for k, _ in pairs(t) do
		keys[i] = k
		i = i + 1
	end
	return t[keys[math.random(1, #keys)]]
end

function path(p, location, radius)
    local x1 = p.character.bounding_box.left_top.x - p.position.x
    local y1 = p.character.bounding_box.left_top.y - p.position.y
    local x2 = p.character.bounding_box.right_bottom.x - p.position.x
    local y2 = p.character.bounding_box.right_bottom.y - p.position.y
    local bounding = {{x1, y1},{x2, y2}}

    route = {}
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
            cache = false,
            allow_destroy_friendly_entities = false,
            prefer_straight_paths = true,
            no_break = true
        },
    })
    return
end

function moveAlongPath(p)
    local nextNode = route[1]
    if nextNode == nil then
        return false
    end
    if Position.distance(p.position, nextNode.position) < 0.1 then
        for i = p.character_running_speed,0,-1 do
            table.remove(route, 1)
            table.remove(route, 1)
        end
    end
    nextNode = route[1]
    if nextNode == nil then
        return false
    end

    local direction = Position.complex_direction_to(p.position, nextNode.position, true)
    p.walking_state = {walking = true, direction = direction}
end



function craft(p, item, count)
    if count == 0 then
        return
    end
    --check if we have enough ingredients
    --if not, get ingredients
    local ingredients = game.recipe_prototypes[item].ingredients
    for key,value in pairs(ingredients) do
        debug(value.name .. " have: " .. p.get_item_count(value.name) .. " need: " .. count * game.recipe_prototypes[item].ingredients[key].amount)
        if p.get_item_count(value.name) < (count * game.recipe_prototypes[item].ingredients[key].amount) then
            --we don't have an ingredient
            get(p, value.name)
            
        end
    end
    if p.get_craftable_count(item) >= count then
        crafted = p.begin_crafting{recipe = item, count = count}
        debug("crafting " .. count .. " " .. item)
        if crafted < count then
            error("Did not craft full count of " .. item .. " looking for ingredients")
        end
    end
end

function get(p, item)
    if resources[item] == nil then -- if we don't know where to find item
        error("Can't find " .. item)
        if game.recipe_prototypes[item] == nul then
            return false
        end
        local ingredients = game.recipe_prototypes[item].ingredients
        for key, ingredient in pairs(ingredients) do
            get(p, ingredient.name)
        end
    else
        for key,location in pairs(resources[item]) do
            table.insert(taskList, current_task, {"take", location, 2, true})
        end
    end
    return true
end

function checkFuel(p)
    if resources ~= nil then
        for item, value in pairs(resources) do
            for key,location in pairs(resources[item]) do
                p.update_selected_entity(location)
                if p.selected.get_fuel_inventory() ~= nil then
                    if p.selected.get_fuel_inventory().is_empty() then --has it run out of fuel?
                        put(p, "coal", 40, location)
                    end
                end
            end
        end
    end
    return
end

function calculateCraft(p, ...)

    local arg = ...
    local toCraft = {}

    if not arg.item and not arg.count then
        local step = current_task + 1
        local iterate = true
        
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
    else
        toCraft[arg.item] = arg.count
    end
    --if we already have it don't bother crafting.
    local inventory = p.get_main_inventory().get_contents() --not accounting for crafting queue
    for item,a in pairs(toCraft) do
        for invent, count in pairs(inventory) do
            if item == invent then
                toCraft[item] = toCraft[item] - count
                if toCraft[item] < 1 then
                    toCraft[item] = 0
                end
            end
        end
    end

    local queue = p.crafting_queue
    if queue then
        debugTable(queue)
        for item,a in pairs(toCraft) do
            for key, val in pairs(queue) do
                if item == val.recipe then
                    toCraft[item] = toCraft[item] - val.count
                    debug(toCraft[item])
                    if toCraft[item] < 1 then
                        toCraft[item] = 0
                    end
                end
            end
        end
    end
    debugTable(toCraft)
    for key,value in pairs(toCraft) do
        if game.recipe_prototypes[key].products[1].amount ~= 1 then
            value = value / game.recipe_prototypes[key].products[1].amount
            value = math.ceil(value)
        end
        if craft(p, key, value) == false then
            error("failed to craft all that was needed")
            return false
        end
    end
    return true
end
            


function mine(p, location)
    --check if there is an item where we are going to mine.
    --used to detect when mining has been finished so we can move on. This means you can't mine surface stuff
    if p.can_place_entity{name = "transport-belt", position = location, direction = defines.direction.north} then
        delroute(p)
        return true
    else
        p.update_selected_entity(location)
        if p.selected ~= nil then
            if p.can_reach_entity(p.selected) == false then
                if route == nil then
                    path(p, p.selected.selection_box.right_bottom, 1) 
                end
                return false
            end
            p.mining_state = {mining = true, position = location}
        else
            error("no entity selected")
            error(location)
            path(p, location, 4) 
        end
    end
end

function build(p, location, item, direction, ...)
    local entitybounding = game.entity_prototypes[item].collision_box
    local entitycollision = Area.offset(entitybounding, location)

    local playercollision = p.character.bounding_box

    local arg = ...

    if route == nil then
        path(p, location, 3)
    end

    --can_place_entity already checks player reach
    --if out of reach, placing fails, but keep trying.
    --we can use this to place whilst walking as it will keep trying until it succeeds.
    if p.get_item_count(item) < 1 then
        error("did not have " .. item)
        if (p.crafting_queue_size > 0) then
            return false --still have to wait for queue to finish, so no point working out if our item is queued
        else
            craft(p, item, 1)
        end
        return false
    elseif p.surface.can_fast_replace{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player", fast_replace = true, player = p}
        if built then
            delroute(p)
            colliding = false
            --be honest
            p.remove_item{name=item, count=1}
            if arg.group then
                table.insert(resources[arg.group], location)
                debugTable(resources)
            end
            return true
        else
            error("Fast replace failed")
            return false
        end
    elseif p.can_place_entity{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player"}
        if built then
            delroute(p)
            colliding = false
            --be honest
            p.remove_item{name=item, count=1}
            if arg.group then
                if resources[arg.group] == nil then
                    resources[arg.group] = {}
                    debugTable(resources)
                end
                table.insert(resources[arg.group], {location.x, location.y})
                debugTable(resources)
            end
            return true
        else
            error("building failed")
            return false
        end
    -- we might be stood where we want to place the object
    elseif overlap(entitycollision, playercollision) then
        if not colliding then
            error("colliding with build location")
            path(p, {p.position.x+4, p.position.y}, 1)
        end
        colliding = true
    end

    return false
end

function take(p, location, numberToTake, skip)
    p.update_selected_entity(location)
    item = nil

    if not p.can_reach_entity(p.selected) then
        if route == nil then
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
            -- if entity has fuel requirements.
            if p.selected.get_fuel_inventory() ~= nil then
                if p.selected.get_fuel_inventory().is_empty() then --has it run out of fuel?
                    debug("fuel is empty, adding extra")
                    put(p, "wood", 2, location) --more likely to have wood
                end
            end
            return false
        end
    end
    for key, value in pairs(p.selected.get_output_inventory().get_contents()) do
        item = key
        numberInEntity = tonumber(value)
    end


    if numberToTake == -1 then  --take everything
        p.insert{name=item, count=numberInEntity}
        p.selected.remove_item{name=item, count=numberInEntity}
        delroute(p)
        return true
    elseif numberToTake < numberInEntity then
        p.insert{name=item, count=numberToTake}
        p.selected.remove_item{name=item, count=numberToTake}
        delroute(p)
        return true
    else
        local count = math.min(numberToTake, numberInEntity)
        p.insert{name=item, count=count}
        p.selected.remove_item{name=item, count=count}
        error("didn't take requested ammount of " .. item .. " only took "  .. count .. " of " .. numberToTake)
        delroute(p)
        return true
    end
end

function put(p, item, count, location)
    p.update_selected_entity(location)
    if not p.can_reach_entity(p.selected) then
        if route == nil then
            path(p, location, 3)
        end
        return false
    end

    local playerCount = p.get_item_count(item)
    if count <= playerCount then --we have enough items to move
        inserted = p.selected.insert{name = item, count = count}

        if inserted <= 0 then 
            error("tried to remove " .. inserted .. " items")
            inserted = 1 --THIS CODE IS BAD, QUICK FIX FOR ISSUE
        end
        p.remove_item{name=item, count=inserted}
    else --we don't have enough items to move, use get to find more
        if not get(p, item) then 
            --can't find more
            tomove = 1
            inserted = p.selected.insert{name = item, count = tomove}

            if inserted <= 0 then 
                error("tried to remove " .. inserted .. " items")
                inserted = 1 --THIS CODE IS BAD, QUICK FIX FOR ISSUE
            end

            p.remove_item{name=item, count=inserted}
        end
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

    p.selected.set_recipe(recipe)
    ingredients = game.recipe_prototypes[recipe].ingredients
    for key, ingredient in ipairs(ingredients) do
        inserted = p.selected.insert(ingredient.name)
        p.remove_item{name=ingredient.name, count=inserted}
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
    rendering.clear()
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
    counter = counter + 1
    if counter == 600 then --run every 10 sec * speed
        checkFuel(p)
        counter = 0
    end
    if tasks[1] == "build" then
        return build(p, tasks[2], tasks[3], tasks[4], {group=tasks[5]})
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
        if route ~= nil then
            moveAlongPath(p)
        end
        debugTable(taskList[current_task])
        result = doTask(p, taskList[current_task])
        if result ~= nil then
            if result == true then
                current_task = current_task + 1
                delroute(p)
            elseif result == "end" then
                enabled = false
            end
        end
    end
end)

script.on_event(defines.events.on_cutscene_cancelled, function(event)
    enabled = true
    game.players[1].game_view_settings.show_entity_info = true
end)

--when we have out path

script.on_event(defines.events.on_script_path_request_finished, function(event)
    if event.try_again_later then
        error("pathing failed trying again")
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
        route = nil
    end
end)


--add on research ended. use file to store order of research tasks.

script.on_event(defines.events.on_research_finished, function()
    debug("starting next research")
    local p = game.players[1]
    current_research = current_research + 1
    p.force.add_research(research[current_research])
end)
--ToDo list
--fix Crafting
--change miner phase to use get function
--function to restock coal / copper-plates


------------------------------------------------------------------------------------------------------
require "util"
local taskList = require("tasks")
local research = require("research")
local Position = require("__stdlib__/stdlib/area/position")
local Direction = require("__stdlib__/stdlib/area/direction")
local Area = require("__stdlib__/stdlib/area/area")

dbg = true
enabled = false
route = nil


local current_task = 0
current_research = 0
local destination = {x=0, y=0}

resources = {}
group = {}

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

    delroute(p)
    p.surface.request_path({
        bounding_box = p.character.prototype.collision_box,
        collision_mask = p.character.prototype.collision_mask,
        start = p.position,
        radius = radius,
        goal = location,
        force = p.force,
        entity_to_ignore = p.character,
        path_resolution_modifier = -1,
        pathfind_flags = {
            cache = false,
            prefer_straight_paths = false
        }
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
        end
    end
    nextNode = route[1]
    if nextNode == nil then
        delroute(p) --reached end
        return false
    end

    local direction = Position.complex_direction_to(p.position, nextNode.position, true)
    p.walking_state = {walking = true, direction = direction}
end



function craftItem(p, item, count)
    if count == 0 then
        return false
    end
    --check if we have enough ingredients
    --if not, get ingredients
    if p.get_craftable_count(item) >= count then
        p.begin_crafting{recipe = item, count = count}
        debug("crafting " .. count .. " " .. item)
        return true
    else
        local ingredients = game.recipe_prototypes[item].ingredients
        for key,ingredient in ipairs(ingredients) do
            local have = p.get_item_count(ingredient.name) + getCraftingCount(p, ingredient.name) --need to account for queue
            local need = count * ingredient.amount
            debug(ingredient.name .. " have: " .. have .. " need: " .. need)
            if have < need then
                if get(p, ingredient.name, need - have) then
                elseif ingredient.name == "stone" then
                    error("having a stone issue")
                elseif game.recipe_prototypes[ingredient.name].category == "crafting" then --is an ingredient craftable?
                    debug("can craft " .. ingredient.name)
                    local numToCraft = need - have
                    numToCraft = numToCraft / game.recipe_prototypes[item].products[1].amount
                    numToCraft = math.ceil(numToCraft)
                    craftItem(p, ingredient.name, numToCraft)
                else
                    error("can't find or craft " .. ingredient.name)
                end
            end
        end
        return false
    end
end

function get(p, item, count)
    if resources[item] == nil then -- if we don't know where to find item
        error("Can't find " .. item)
        return false
    else
        for key,location in pairs(resources[item]) do
            p.update_selected_entity(location)
            local outputInventory = p.selected.get_output_inventory()
            if outputInventory == nil then
                debug("selected entity has no output inventory")
            elseif next(p.selected.get_output_inventory().get_contents()) then

                for itemininv, numberInEntity in pairs(p.selected.get_output_inventory().get_contents()) do
                    if item == itemininv and numberInEntity > 0 then
                        debug("getting " .. item .. " from " .. location[1] .. " " .. location[2])
                        if numberInEntity > count then
                            table.insert(taskList, current_task, {"take", location, count, true})
                            count = count - count
                        else 
                            table.insert(taskList, current_task, {"take", location, numberInEntity, true})
                            count = count - numberInEntity
                        end
                        if count <= 0 then
                            goto exitfromget
                        end
                    end
                end
            end
        end
        --if we still need plates, then check fuel in burners
        if count > 0 and (item == "iron-plate" or item == "copper-plate" or item == "stone") then
            checkBurnerFuel(p)
        end
        delroute(p)
    end
    ::exitfromget::
    return count <= 0
end


function calculateCraft(p, toCraft)
    --if we already have it don't bother crafting.
    local inventory = p.get_main_inventory().get_contents()
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
    
    --don't craft if in crafting queue
    local queue = p.crafting_queue
    if queue then
        for item,_ in pairs(toCraft) do
            count = getCraftingCount(p, item)
            toCraft[item] = toCraft[item] - count
            if toCraft[item] < 1 then
                toCraft[item] = 0
            end
        end
    end
    
    --if we can get it, don't craft
    local getting = false
    for item,count in pairs(toCraft) do
        if count > 0 then
            if get(p, item, count) then
                getting = true
                toCraft[item] = 0
            end
        end
    end
    
    debugTable(toCraft)
    for item, numToCraft in pairs(toCraft) do
        --account for multiple products in crafting recipes 
        numToCraft = numToCraft / game.recipe_prototypes[item].products[1].amount
        numToCraft = math.ceil(numToCraft)
        if craftItem(p, item, numToCraft) then
            toCraft[item] = 0
        end
    end
    if getting then
        return false
    else
        return not anyPositive(toCraft)
    end
end

function craft(p, ...)
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
    
    return calculateCraft(p, toCraft)
end

function checkBurnerFuel(p)
    debug("checking burner fuel")
    --remove this task from the task list. Stops repeating this task
    if taskList[current_task][1] == "checkBurnerFuel" then
        table.remove(taskList, current_task)
    end
    local locations = {"iron-burner-miner", "iron-burner-furnace", "copper-burner-miner", "copper-burner-furnace", "stone-burner-miner"}
    local count = 0
    for k, v in pairs(locations) do
        if group[v] then
            for key,location in pairs(group[v]) do
                p.update_selected_entity(location)
                if p.selected.get_fuel_inventory() ~= nil then
                    if p.selected.get_fuel_inventory().is_empty() then --has it run out of fuel?
                        table.insert(taskList, current_task, {"put", "coal", 10,  location})
                        count = count + 10
                    end
                end
            end
        end
    end
    get(p, "coal", count)
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
                    path(p, p.selected.selection_box.right_bottom, 2) 
                end
                return false
            end
            p.mining_state = {mining = true, position = location}
        else
            error("no entity selected")
            error(location)
            path(p, location, 4) 
            return true --it there is no entity there, it is likely that the object has been mined.
        end
    end
end

function build(p, location, item, direction, ...)
    local arg = ...

    --can_place_entity already checks player reach
    --if out of reach, placing fails, but keep trying.
    --we can use this to place whilst walking as it will keep trying until it succeeds.
    if p.get_item_count(item) < 1 then
        debug("did not have " .. item)
        if (getCraftingCount(p, item) > 0) then
            debug("waiting for crafting to finish")
            return false --still have to wait for queue to finish, so no point working out if our item is queued (efficiency??)
        else
            craft(p, {item = item, count = 1})
        end
        return false
    elseif p.surface.can_fast_replace{name = item, position = location, direction = direction, force = "player"} then
        built = p.surface.create_entity{name = item, position = location, direction = direction, force="player", fast_replace = true, player = p}
        if built ~= nil then
            debug("fast replaced")
            --be honest
            p.remove_item{name=item, count=1}
            if arg.group then
                if group[arg.group] == nil then
                    group[arg.group] = {}
                end
                table.insert(group[arg.group], {location.x, location.y})
            end
            if arg.resource then
                if resources[arg.resource] == nil then
                    resources[arg.resource] = {}
                end
                table.insert(resources[arg.resource], {location.x, location.y})
            end
            return true
        else
            error("Fast replace failed")
            return false
        end
    elseif p.can_place_entity{name = item, position = location, direction = direction, force = "player"} then
        if item == "underground-belt" then
            built = p.surface.create_entity{name = item, position = location, direction = direction, force="player", type = arg.group}
        else 
            built = p.surface.create_entity{name = item, position = location, direction = direction, force="player"}
        end
        if built ~= nil  then
            debug("built")
            --be honest
            p.remove_item{name=item, count=1}
            if arg.group then
                if group[arg.group] == nil then
                    group[arg.group] = {}
                end
                table.insert(group[arg.group], {location.x, location.y})
            end
            if arg.resource then
                if resources[arg.resource] == nil then
                    resources[arg.resource] = {}
                end
                table.insert(resources[arg.resource], {location.x, location.y})
            end
            return true
        else
            error("did not build entity")
            return false
        end
    end

    local entitycollision = game.entity_prototypes[item].collision_box
    local entitybounding = {left_top = { x = entitycollision.left_top.x + location.x, y = entitycollision.left_top.y + location.y}, right_bottom = { x = entitycollision.right_bottom.x + location.x, y = entitycollision.right_bottom.y + location.y}}
    
    entitybounding = {left_top = { x = entitybounding.left_top.x - 1, y = entitybounding.left_top.y - 1}, right_bottom = { x = entitybounding.right_bottom.x + 1, y = entitybounding.right_bottom.y + 1}}

    local playerbounding = p.character.bounding_box


    if collides(entitybounding, playerbounding) then
        --I believe there to be an issue with this, logging so when the issue occurs I can fix it.
        debug("colliding with build location")
        debugTable(entitybounding)
        rendering.draw_rectangle{surface = game.players[1].surface, left_top = entitybounding.left_top, right_bottom = entitybounding.right_bottom, color = {g=1}, width = 2, filled = false}
        debugTable(playerbounding)
        rendering.draw_rectangle{surface = game.players[1].surface, left_top = playerbounding.left_top, right_bottom = playerbounding.right_bottom, color = {b=1}, width = 2, filled = false}
        p.walking_state = {walking = true, direction = defines.direction.southwest}
        return false
    else 
        if route == nil then
            path(p, location, 5)
            return false
        end
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
            return false
        end
    end
    for key, value in pairs(p.selected.get_output_inventory().get_contents()) do
        item = key
        numberInEntity = tonumber(value)
    end


    if numberToTake == -1 then  --take everything
        if p.selected.name == "burner-miner" then
            p.insert{name=item, count=numberInEntity - 1}
            p.selected.remove_item{name=item, count=numberInEntity - 1}
        else
            p.insert{name=item, count=numberInEntity}
            p.selected.remove_item{name=item, count=numberInEntity}
        end
        delroute(p)
        return true
    elseif numberToTake == 0 then --I have no idea why this happens, but you can't insert 0 items
        return true
    elseif numberToTake <= numberInEntity then
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
        delroute(p)
            return true
    else --we don't have enough items to move, use get to find more
        if not get(p, item, count) then 
            --can't find more
            tomove = 1
            inserted = p.selected.insert{name = item, count = tomove}

            if inserted <= 0 then 
                error("tried to remove " .. inserted .. " items")
                inserted = 1 --THIS CODE IS BAD, QUICK FIX FOR ISSUE
            end

            p.remove_item{name=item, count=inserted}
            delroute(p)
            return true
        end
        return false
    end

end

function collides(area1, area2)
    -- If there is horizontal separatation 
    if area1.left_top.x > area2.right_bottom.x or area2.left_top.x > area1.right_bottom.x then
        return false
    end 
    -- If there is vertical separation
    if area1.right_bottom.y < area2.left_top.y or area2.right_bottom.y < area1.left_top.y then
        return false
    end
    return true
end

function time(p)
    local seconds = p.online_time / 60
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    error(hours..":"..mins..":"..secs)
    return true
end

function science(p)
    p.force.add_research(research[current_research])
    return true
end

function anyPositive(t)
    for _,v in pairs(t) do
      if v > 0 then
        return true
      end
    end
    return false
end

function getCraftingCount(p, item)
    local queue = p.crafting_queue
    local count = 0
    if queue then
        for key, val in pairs(queue) do
            if item == val.recipe and val.prerequisite == false then
                count = count + val.count
            end
        end
    end
    return count
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
    debug("del route")
end

-----------------------------------------------------------------------------------------------------

function doTask(p, tasks)
    if tasks[1] == "build" then
        return build(p, tasks[2], tasks[3], tasks[4], {group=tasks[5], resource=tasks[6]})
    elseif tasks[1] == "craft" then
        return craft(p, {item=tasks[2], count=tasks[3]})
    elseif tasks[1] == "mine" then
        return mine(p, tasks[2])
    elseif tasks[1] == "research" then
        return science(p)
    elseif tasks[1] == "put" then
        return put(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "take" then
        return take(p, tasks[2], tasks[3], tasks[4])
    elseif tasks[1] == "checkBurnerFuel" then
        return checkBurnerFuel(p)
    elseif tasks[1] == "recipe" then
        return recipe(p, tasks[2], tasks[3])
    elseif tasks[1] == "speed" then
        return speed(p, tasks[2])
    elseif tasks[1] == "time" then
        return time(p)
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
                delroute(p)
                current_task = current_task + 1
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
        game.players[1].walking_state = {walking = true, direction = defines.direction.southwest}
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
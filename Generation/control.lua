require "util"

script.on_init(function()
    game.remove_path("tasks.txt")
end)


script.on_event("log-walk", function(event)
    position = game.players[1].position
    game.print("walk to" .. serpent.line(position))
    game.write_file("tasks.txt", "{\"walk\", {x=" .. position.x .. ", y=" .. position.y .. "}}\n", true)
end)

script.on_event(defines.events.on_built_entity, function(event)
    position = event.created_entity.bounding_box
    position = {x = (position.right_bottom.x + position.left_top.x) / 2 , y = (position.right_bottom.y + position.left_top.y) / 2}
    item = event.created_entity.name
    facing = event.created_entity.direction
    game.print("placed " .. serpent.line(item) .. " at " .. serpent.line(position) .. " facing " .. facing)
    game.write_file("tasks.txt", "{\"build\", {x=" .. position.x .. ", y=" .. position.y .. "}, \"" .. item .. "\", " .. facing .. "}\n", true)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    position = event.entity.bounding_box
    position = {x = (position.right_bottom.x + position.left_top.x) / 2 , y = (position.right_bottom.y + position.left_top.y) / 2}
    game.print("mined at " .. serpent.line(position))
    game.write_file("tasks.txt", "{\"mine\", {x=" .. position.x .. ", y=" .. position.y .. "}\n", true)
end)

script.on_event(defines.events.on_pre_player_crafted_item, function(event)
    item = event.recipe.name
    game.print("crafted " .. serpent.line(item))
    game.write_file("tasks.txt", "{\"craft\", \"" .. item .. "\", 1\n", true)
end)

script.on_event("log-put", function(event)
    p = game.players[1]
    if not p.selected then
        game.print("Please hover over entity")
        return false
    end
    position = p.selected.bounding_box
    position = {x = (position.right_bottom.x + position.left_top.x) / 2 , y = (position.right_bottom.y + position.left_top.y) / 2}
    game.print("put item into " .. serpent.line(position))
    game.write_file("tasks.txt", "{\"put\", \"" .. item .. "\", count, {x=" .. position.x .. ", y=" .. position.y .. "}, defines.inventory.**inventory**}\n", true)
end)

script.on_event("log-take", function(event)
    p = game.players[1]
    if not p.selected then
        game.print("Please hover over entity")
        return false
    end
    position = p.selected.bounding_box
    position = {x = (position.right_bottom.x + position.left_top.x) / 2 , y = (position.right_bottom.y + position.left_top.y) / 2}
    game.print("take from " .. serpent.line(position))
    game.write_file("tasks.txt", "{\"take\", {x=" .. position.x .. ", y=" .. position.y .. "}, \"item\", count, defines.inventory.**inventory**}\n", true)
end)


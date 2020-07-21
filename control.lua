local function debug(p,msg)
    if debug then
        p.print(msg)
    end
end

script.on_event(defines.event.on_tick, function(event))
    local p = game.players[1]
    local pos = p.postion

    debug(p, "This is the first test")
end
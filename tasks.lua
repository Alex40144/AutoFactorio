local task = {}
task[0] = {"walk", {x=-5,y=-21}}
task[1] = {"mine", {x=-6,y=-24}}
task[2] = {"craft", "stone-furnace", 8}
task[3] = {"walk", {x=-20,y=27}}
task[4] = {"build", {x=-22, y=29}, "burner-mining-drill", defines.direction.east}
task[5] = {"build", {x=-20,y=29}, "stone-furnace", defines.direction.south}
task[6] = {"put", "coal", 5, {x=-22, y=29}, defines.inventory.fuel}
task[7] = {"put", "coal", 3, {x=-20, y=29}, defines.inventory.fuel}
task[8] = {"debug"}
task[9] = {"end"}
return task

local task = {}

task[1] = {"walk", {x=-5,y=-21}}
task[2] = {"mine", {x=-6,y=-24}}
task[3] = {"craft", "stone-furnace", 8}
task[4] = {"walk", {x=-20,y=27}}
task[5] = {"build", {x=-22, y=29}, "burner-mining-drill", defines.direction.east}
task[6] = {"build", {x=-20,y=29}, "stone-furnace", defines.direction.south}
task[7] = {"put", "coal", 5, {x=-22, y=29}, defines.inventory.fuel}
task[8] = {"put", "coal", 3, {x=-20, y=29}, defines.inventory.fuel}
task[9] = {"debug"}
task[10] = {"end"}


return task
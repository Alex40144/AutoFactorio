local task = {}

task[1] = {"walk", {x=-5,y=-21}}
task[2] = {"mine", {x=-6,y=-24}}
task[3] = {"craft", "stone-furnace", 8}
task[4] = {"walk", {x=-20,y=27}}
task[5] = {"build", {x=-22, y=29}, "burner-mining-drill", defines.direction.east}
task[6] = {"build", {x=-20,y=29}, "stone-furnace", defines.direction.south}
task[7] = {"debug"}
task[8] = {"end"}


return task
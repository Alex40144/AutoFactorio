# AutoFactorio

This mod is a Tool Assisted Speedrun (TAS) for Factorio.  
It uses the latest Factorio version unless it doesn't work.
It is a bit stupid and can only follow pre defined instructions.

https://github.com/Alex40144/AutoFactorioGenerator

You can also use this to generate your own tasks set

To use this mod:

1. Download the source code from the releases tab (v0.0.1 latest)
2. extract and find 2 folders. one called 'Scenarios' and the other 'mods'
3. Navigate to /user/appdata/roaming/Factorio and put them there.
4. Start up Factorio, enable the mod.
5. create a new game and choose the AutoFactorio scenario.

# To Do list

1. ~~Improve detection for trying to build where player is stood~~
   1. ~~use bounding boxes instead of within function~~
2. ~~better crafting~~
   1. ~~work out what needs crafting~~
   2. ~~craft all items that are needed before the next craft instruction~~
3. ~~better inventory selection~~
   1. ~~take could assume result~~
   2. ~~put could assume input or fuel~~
   3. ~~check what is in inventory and take that. don't define it in tasks.lua~~
      1. ~~this is likely only one type of item~~
4. better resource gathering
   1. ~~save the position of chests that we can refer to when we need stuff~~
   2. ~~change get to use count value.~~
      1. ~~issue with getting stone~~
      1. prefer closest entities

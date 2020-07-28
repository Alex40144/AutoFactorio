#this copys game files into correct folder
import os, glob, shutil
import json
import taskgenerator


##FIRST MOD##
basepath = os.path.dirname(__file__)
infofile = os.path.abspath(os.path.join(basepath, "..", "info.json"))

#begin by updating the lua tasks
taskgenerator.generate_lua_tasks()

#get mod version
with open(infofile, 'r') as infofile:
    data=infofile.read()

obj = json.loads(data)
mod_version = str(obj['version'])
print("version: " + mod_version)

mod_name = str(obj['name'])
print("name: " + mod_name)

#remove any mods
try:
    for filename in glob.glob(r"C:\Users\giddy\AppData\Roaming\Factorio\mods\AutoFactorio*"):
        shutil.rmtree(filename)
except:
    print("no files to remove")

#make folder for mod
os.mkdir(r'C:\Users\giddy\AppData\Roaming\Factorio\mods//' + mod_name + "_" + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "..", "control.lua")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + "_" + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "..", "info.json")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + "_" + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "..", "tasks.lua")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + "_" + mod_version)

##Generator mod.

with open(os.path.abspath(os.path.join(basepath, "info.json")), 'r') as infofile:
    data=infofile.read()

obj = json.loads(data)
mod_version = str(obj['version'])
print("version: " + mod_version)

mod_name = str(obj['name'])
print("name: " + mod_name)

os.mkdir(r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "control.lua")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "info.json")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy(os.path.abspath(os.path.join(basepath, "data.lua")), r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
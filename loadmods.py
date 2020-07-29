#this copys game files into correct folder
import os, glob, shutil
import json


with open("info.json", 'r') as infofile:
    data=infofile.read()

obj = json.loads(data)
mod_version = str(obj['version'])
print("version: " + mod_version)

mod_name = str(obj['name'])
print("name: " + mod_name)

try:
    for filename in glob.glob(r"C:\Users\giddy\AppData\Roaming\Factorio\mods\AutoFactorio_" + mod_version):
        shutil.rmtree(filename)
except:
    print("no files to remove")

os.mkdir(r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy("control.lua", r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy("info.json", r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
shutil.copy("tasks.lua", r'C:\Users\giddy\AppData\Roaming\Factorio\mods\\' + mod_name + '_' + mod_version)
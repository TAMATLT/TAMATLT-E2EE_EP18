# TAMAT LT E2EE Ep18 Repository
This repository contains examples I have used in Ep17 of my E2E:E Series

**If you are an expert in OpenComputers and see that some of these scripts mirror default functions or could be done better**
**PLEASE let me know what could be changed in the Issues section**

If you do not know much about lua programming here is what you do:

- In any computer in opencomputers go into OpenOS and navigate to the #home directory
- In the command line type `edit <filenale.lua>`, where **<filename.lua>** is your script. This opens script editor.
- Minimize minecraft and switch to web brouser.
- Open the *.lua script you want in this repository and copy its contents.
- Go back to minecraft window, back to the editor and press middle mouse button, which will insert contents of .lua script into the editor
- Press 'Ctrl + S' to save file inside OpenOS.
- Press 'Ctrl + W' to close the editor and back to command line.
- Run the script by typing `<filename>` without .lua part if your script name was <filenale.lua>. The you might need to type any arguments for the script like this `<filename> arg1 arg2`
- Alternative route is to find out where your game files are stored in your system and manipulate these files outside of minecraft (see **checkFilesystemLocation.lua** section below)

# Scripts in this repository

All of the scripts from this repository should be copied to home directory of your OpenOS in Minecraft

## checkFilesystemLocation.lua

Lets say you have made your 20th computer with OpenComputers mod, installed OpenOS, created a file there and now want to open this file with your editor outside of Minecraft.

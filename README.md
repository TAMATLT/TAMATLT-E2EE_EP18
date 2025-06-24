# TAMAT LT E2EE Ep18 Repository
This repository contains examples I have used in Ep18 of my E2E:E Series

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

## ShellToFile.lua

Sometimes its handy to output the result of the script into the file, so that you can copy the output for later use. For example if you use LLMs for script creation and want to transfer the error you observed to the LLM to fix the bug.

To use **runScript.lua** you run it like this:

`ShellToFile "command_you_want_to_run" <output_file>`

where **<output_file>** is the file that will contain the output

Of course! Creating good documentation is just as important as writing good code. Using your provided text as a template, I've created a formatted README file for your `nm.lua` script. It maintains the same helpful, instructional style.

## nm.lua - Nanomachines Manager

The `nm` script was coooked up as a replacement for `nn group` command. The main purpose is to reduce the typing you need to do each time you anable or disable input group. It allows you to create simple, memorable shortcuts (called "aliases") for complex combinations of nanomachine inputs. Instead of typing `nn on XX` and `nn on XY`, or defining a group, say for nightvision like this: `nn group set nv 11 12` and then running it like `nn group on nv` you can simply define an alias like `nv` and run it via `nm on nv`.

All aliases are stored in a simple configuration file (`/home/nm.conf`) that you can manage directly from the command line or in external editor.

### Command Reference

Here are all the commands available in `nm`:

*   `nm init`
    *   Establishes the connection with your nanomachine controller. **Required for other commands** 

*   `nm on <alias>`
    *   Activates all nanomachine inputs associated with the specified alias.

*   `nm off <alias>`
    *   Deactivates all nanomachine inputs associated with the specified alias.

*   `nm add <alias> <input1> <input2> ... [--desc "description"]`
    *   Creates a new alias or updates an existing one.
    *   `<alias>`: The short name you want to use (e.g., `speed`, `haste`).
    *   `<inputs...>`: A space-separated list of one or more input numbers.
    *   `--desc "description"`: An optional flag to add a comment about what the alias does. The description text **must be in quotes** if it contains spaces.

*   `nm remove <alias>`
    *   Deletes an alias from your configuration file.

*   `nm list`
    *   Displays a formatted list of all your currently defined aliases, their input numbers, and their descriptions.

*   `nm help`
    *   Shows a summary of all available commands.

### The Configuration File

This script automatically creates and manages a file at `/home/nm.conf`. This file stores all your aliases. While you can edit it manually or use the `nm add` and `nm remove` commands.

An example `nm.conf` file might look like this:

```lua
-- Nanomachine Aliases for nm.lua
-- Format: return { alias = { inputs={...}, desc="..." } }
return {
  nv = {
    inputs = { 11, 12 },
    desc = "Night Vision"
  },
  haste = {
    inputs = { 7 },
    desc = "Repair"
  },
  heart = {
    inputs = { 5, 6 }
  }
}
```

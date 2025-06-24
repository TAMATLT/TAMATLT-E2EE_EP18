--[[
  Nano-Manager (nm)
  A user-friendly command-line tool for managing OpenComputers nanomachines.

  This script provides a streamlined interface for activating and deactivating
  nanomachine effects using simple, memorable aliases. It replaces the default
  `nn group` functionality with a more robust system that stores aliases and
  their descriptions in a human-readable configuration file.
]]

-- Load required OpenComputers libraries
local component = require("component") -- For accessing components like the modem
local event = require("event")       -- For listening to events, like modem messages
local fs = require("filesystem")     -- For checking if files exist
local serialization = require("serialization") -- For saving/loading Lua tables to/from files

-- Define paths for configuration and state files
local ALIAS_CONFIG_PATH = "/home/nm.conf" -- Stores user-defined aliases and descriptions
local STATE_PATH = "/tmp/nm.state"        -- Stores temporary session data like the controller address

--------------------------------------------------------------------------------
-- CORE NANOMACHINE COMMUNICATION
--------------------------------------------------------------------------------

-- The modem component is used for all network communication.
local m = component.modem
-- The 'state' table will hold session data after initialization.
local state = {}

-- sendCommand: Low-level function to send a command to the nanomachine controller.
-- If we know the controller's specific address (state.nnaddress), we send a direct
-- message for efficiency. Otherwise (during init), we broadcast to all devices.
local function sendCommand(...)
  if state.nnaddress then
    m.send(state.nnaddress, state.port, "nanomachines", ...)
  else
    m.broadcast(state.port or 27091, "nanomachines", ...)
  end
end

-- getReply: Sends a command and waits for a response.
-- It calls sendCommand and then uses event.pull to wait for a "modem_message".
-- A timeout is used to prevent the program from freezing if no response is received.
local function getReply(...)
  sendCommand(...)
  if state.nnaddress then
    return {event.pull(2, "modem_message", state.nnaddress)}
  else
    return {event.pull(2, "modem_message")}
  end
end

-- setInput: The fundamental action to enable or disable a single nanomachine input.
-- It verifies initialization, then calls getReply to send the actual command.
local function setInput(inputIndex, shouldBeOn)
  if not state.initialized then
    io.stderr:write("Error: Not initialized. Run 'nm init'\n")
    return false
  end
  print((shouldBeOn and "Enabling" or "Disabling") .. " input " .. inputIndex)
  getReply("setInput", tonumber(inputIndex), shouldBeOn)
  return true
end

--------------------------------------------------------------------------------
-- STATE AND ALIAS FILE MANAGEMENT
--------------------------------------------------------------------------------

-- loadState: Reads the session state from the state file.
-- It uses pcall (protected call) to safely unserialize the data. This prevents
-- the script from crashing if the state file is corrupted or doesn't exist.
local function loadState()
  if fs.exists(STATE_PATH) then
    local file = io.open(STATE_PATH, "r")
    if file then
      local data = file:read("*a")
      file:close()
      local success
      -- Attempt to unserialize; 'success' will be false if it fails.
      success, state = pcall(serialization.unserialize, data)
      if success and state.initialized then
        return true
      end
    end
  end
  -- If loading fails for any reason, reset to a default, uninitialized state.
  state = { initialized = false, port = 27091 }
  return false
end

-- saveState: Serializes the current 'state' table and writes it to the state file.
local function saveState()
  local file, reason = io.open(STATE_PATH, "w")
  if not file then
    io.stderr:write("Could not save state file: " .. reason .. "\n")
    return false
  end
  file:write(serialization.serialize(state))
  file:close()
  return true
end

-- loadAliases: Loads the user's aliases from the configuration file.
-- It uses `loadfile`, which compiles the config file as a Lua script.
-- This works because the config file is expected to return a table.
local function loadAliases()
  if not fs.exists(ALIAS_CONFIG_PATH) then
    return {} -- Return an empty table if the config file doesn't exist yet.
  end
  local aliases, reason = loadfile(ALIAS_CONFIG_PATH)
  if not aliases then
      io.stderr:write("Error loading aliases from " .. ALIAS_CONFIG_PATH .. ": " .. tostring(reason) .. "\n")
      return {}
  end
  -- Execute the compiled script to get the table it returns.
  return aliases()
end

-- saveAliases: Writes the given alias table back to the configuration file.
-- The 'pretty = true' option makes the saved file indented and human-readable.
local function saveAliases(aliases)
  local file, reason = io.open(ALIAS_CONFIG_PATH, "w")
  if not file then
    io.stderr:write("Could not save alias file: " .. reason .. "\n")
    return
  end
  file:write("-- Nanomachine Aliases for nm.lua\n")
  file:write("-- Format: return { alias = { inputs={...}, desc=\"...\" } }\n")
  -- The "return " is prepended to make the file a valid Lua script for `loadfile`.
  file:write("return " .. serialization.serialize(aliases, {pretty = true}))
  file:close()
  print("Aliases saved to " .. ALIAS_CONFIG_PATH)
end

--------------------------------------------------------------------------------
-- COMMAND IMPLEMENTATIONS
-- The 'commands' table acts as a dispatch map, associating command strings
-- with the functions that implement them.
--------------------------------------------------------------------------------

local commands = {}

-- init: Establishes the initial connection with the nanomachine controller.
-- This is a required first step to learn the controller's unique network
-- address and the maximum number of inputs it supports.
function commands.init()
  print("Initializing nanomachine connection...")
  m.close(state.port or 27091) -- Close any old port connections
  m.open(27091) -- Open the default port
  state.port = 27091
  
  -- Ask the controller to use our main port for its responses.
  m.broadcast(27090, "nanomachines", "setResponsePort", state.port)
  event.pull(1, "modem_message") -- Clear any stray messages from the queue.
  
  print("Requesting input count...")
  local resp = getReply("getTotalInputCount")
  if not resp[8] then -- The 8th value in the response is the input count.
    io.stderr:write("Initialization failed. No response from nanomachine controller.\n")
    state.initialized = false
    return
  end

  -- Save the crucial information to our state table.
  state.nnaddress = resp[2] -- The controller's unique address.
  state.max_inputs = resp[8] -- The total number of available inputs.
  state.initialized = true
  saveState() -- Persist this state for future script runs.
  
  print("Initialization successful!")
  print(" -> Controller Address: " .. state.nnaddress)
  print(" -> Max Inputs: " .. state.max_inputs)
end

-- on: Activates all inputs associated with a given alias.
function commands.on(aliasName)
  if not aliasName then return print("Usage: nm on <alias>") end
  local aliases = loadAliases()
  local aliasData = aliases[aliasName]
  if not aliasData then
    return print("Error: Alias '" .. aliasName .. "' not found.")
  end
  
  -- For backward compatibility: if aliasData.inputs doesn't exist (old format),
  -- use aliasData itself. The 'or' operator provides a clean fallback.
  local inputs = aliasData.inputs or aliasData

  print("Activating group '" .. aliasName .. "'...")
  for _, inputIndex in ipairs(inputs) do
    setInput(inputIndex, true)
  end
  print("Group '"..aliasName.."' activated.")
end

-- off: Deactivates all inputs associated with a given alias.
function commands.off(aliasName)
  if not aliasName then return print("Usage: nm off <alias>") end
  local aliases = loadAliases()
  local aliasData = aliases[aliasName]
  if not aliasData then
    return print("Error: Alias '" .. aliasName .. "' not found.")
  end

  -- Same backward compatibility logic as the 'on' command.
  local inputs = aliasData.inputs or aliasData
  
  print("Deactivating group '" .. aliasName .. "'...")
  for _, inputIndex in ipairs(inputs) do
    setInput(inputIndex, false)
  end
  print("Group '"..aliasName.."' deactivated.")
end

-- add: Creates a new alias or updates an existing one.
-- Can optionally include a description using the '--desc' flag.
function commands.add(aliasName, ...)
  local args = {...} -- The '...' captures all variable arguments into a table.
  if not aliasName or #args == 0 then
    return print("Usage: nm add <alias> <input1> ... [--desc \"description\"]")
  end

  local aliases = loadAliases()
  local inputs = {}
  local desc = nil

  -- This loop parses the arguments, separating input numbers from the description flag.
  local i = 1
  while i <= #args do
    if args[i] == "--desc" then
      desc = args[i+1] -- The description is the argument *after* the flag.
      i = i + 1 -- Skip the description text in the next iteration.
    else
      table.insert(inputs, args[i])
    end
    i = i + 1
  end

  if #inputs == 0 then return print("Error: No input numbers provided.") end
  
  -- Convert all input arguments to numbers, erroring if any are invalid.
  local numericInputs = {}
  for i, v in ipairs(inputs) do
    local n = tonumber(v)
    if n then table.insert(numericInputs, n) else return print("Error: Input '"..tostring(v).."' is not a valid number.") end
  end

  -- If a new description wasn't provided, keep the old one (if it exists).
  local existingAlias = aliases[aliasName]
  local finalDesc = desc or (existingAlias and existingAlias.desc or nil)

  -- Create the new alias data table and save it.
  aliases[aliasName] = { inputs = numericInputs, desc = finalDesc }
  saveAliases(aliases)
  
  print("Alias '" .. aliasName .. "' set to inputs: " .. table.concat(numericInputs, ", "))
  if finalDesc then print("Description: " .. finalDesc) end
end

-- remove: Deletes an alias from the configuration.
function commands.remove(aliasName)
  if not aliasName then return print("Usage: nm remove <alias>") end
  local aliases = loadAliases()
  if not aliases[aliasName] then
    return print("Error: Alias '" .. aliasName .. "' does not exist.")
  end
  
  aliases[aliasName] = nil -- Setting a table key to nil effectively removes it.
  saveAliases(aliases)
  print("Alias '" .. aliasName .. "' removed.")
end

-- list: Displays all defined aliases, their inputs, and their descriptions.
function commands.list()
  print("Defined Aliases in " .. ALIAS_CONFIG_PATH .. ":")
  local aliases = loadAliases()
  local found = false
  for name, aliasData in pairs(aliases) do
    found = true
    local inputs = aliasData.inputs or aliasData -- Backward compatibility.
    local desc = aliasData.desc or nil

    -- string.format is used to align the output into neat columns.
    -- "%-12s" means "format as a string, left-aligned, padded to 12 characters".
    local line = "  " .. string.format("%-12s", name) .. "= " .. table.concat(inputs, ", ")
    if desc then
      line = line .. "  -- " .. desc
    end
    print(line)
  end
  if not found then
    print("  (No aliases defined. Use 'nm add <alias> ...' to create one.)")
  end
end

-- help: Displays a helpful message explaining how to use the script.
function commands.help()
    print("Nano-Manager (nm) - A better way to control nanomachines.")
    print("Usage: nm <command> [arguments]")
    print("\nMain Commands:")
    print("  on <alias>        - Activates all inputs in an alias group.")
    print("  off <alias>       - Deactivates all inputs in an alias group.")
    print("\nAlias Management:")
    print("  add <alias> ...   - Creates/updates an alias. Ex: nm add nv 11 12")
    print("     [--desc \"text\"] - Optionally add a description. Must be the last flag.")
    print("  remove <alias>    - Deletes an alias.")
    print("  list              - Shows all defined aliases and their descriptions.")
    print("\nSystem Commands:")
    print("  init              - (Re)Initializes connection to the nanomachine controller.")
    print("  help              - Shows this help message.")
end

--------------------------------------------------------------------------------
-- SCRIPT ENTRY POINT
--------------------------------------------------------------------------------

-- This is where the script begins execution when run from the shell.

loadState() -- Always load the last known state first.
m.open(state.port) -- Ensure the modem is open on the correct port.

local args = {...}
if #args == 0 then
  commands.help() -- If run with no arguments, show help.
  return
end

-- The first argument is the command; the rest are its arguments.
local command = table.remove(args, 1)

if commands[command] then
  -- This block provides a key user-friendly feature: auto-initialization.
  -- If a command that requires initialization is run before 'nm init',
  -- the script will automatically run 'init' first, then retry the command.
  if not state.initialized and command ~= "init" and command ~= "help" then
    io.stderr:write("Not initialized. Running 'nm init' first...\n\n")
    commands.init()
    if state.initialized then
        print("\nRetrying your command: nm " .. command .. " " .. table.concat(args, " "))
        -- 'table.unpack' passes the elements of the 'args' table as
        -- separate arguments to the command function.
        commands[command](table.unpack(args))
    end
  else
    -- If already initialized (or command doesn't need it), run it directly.
    commands[command](table.unpack(args))
  end
else
  print("Unknown command: '" .. command .. "'. Run 'nm help' for a list of commands.")
end
-- ShellToFile.lua
-- A Script designed to output result of a program in OpenComputers to a file.
-- A good reason to do this would be a small computer screen
-- and a better way to read a file would be outside of Minecraft

-- Access arguments using ... (variable arguments)
local arguments = {...}

-- Check if enough arguments are provided
if #arguments < 2 then
  io.stderr:write("Usage: ShellToFile <command> <output_file>\n")
  os.exit(1)
end

-- Get the command and output filename
local commandString = arguments[1]
local outputFilename = arguments[2]

-- Split the command string into parts
local commandParts = {}
for part in commandString:gmatch("%S+") do
  table.insert(commandParts, part)
end

-- Run the command using os.execute and capture output (with error handling)
local command = table.concat(commandParts, " ") 

local handle = io.popen(command .. " 2>&1") -- Redirect stderr to stdout
if not handle then
  io.stderr:write("Error running command: " .. command .. "\n")
  os.exit(1)
end

local output = handle:read("*all")
handle:close()

-- Open the output file for writing (with error handling)
local file, err = io.open(outputFilename, "w")
if not file then
  io.stderr:write("Error opening output file: " .. err .. "\n")
  os.exit(1)
end

-- Write the captured output to the file
file:write(output)
file:close()

print("Command output written to " .. outputFilename)

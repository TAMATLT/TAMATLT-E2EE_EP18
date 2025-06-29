-- Smart Battery Discharge Automation System for OpenComputers
-- Automatically moves battery upgrades from charger to Mekanism Energy Cube for discharge
local component = require("component")
local sides = require("sides")
local io = require("io")
local os = require("os")

-- Get the transposer component for moving items between inventories
local trans = component.transposer
local CONFIG_FILE = "charger.conf"

-- Convert numeric side IDs to readable names for user interface
local sideNames = {
    [sides.bottom] = "bottom", [sides.top] = "top", 
    [sides.north] = "north", [sides.south] = "south",
    [sides.west] = "west", [sides.east] = "east",
    [sides.up] = "up", [sides.down] = "down"
}

-- Configuration storage - will be loaded from file or set during setup
local config = {
    charger_side = nil,      -- Which side the charger is connected to
    cube_side = nil,         -- Which side the energy cube is connected to
    setup_complete = false   -- Whether initial setup has been completed
}

-- Load configuration from file
-- Returns true if config was successfully loaded, false if setup is needed
local function loadConfig()
    -- Try to open the config file for reading
    local file = io.open(CONFIG_FILE, "r")
    if file then
        -- Read the three expected lines from config file
        local line1 = file:read()  -- charger_side=X
        local line2 = file:read()  -- cube_side=X  
        local line3 = file:read()  -- setup_complete=true
        file:close()
        
        -- Parse the config values if all lines were read successfully
        if line1 and line2 and line3 then
            -- Extract the number after the = sign and convert to number
            config.charger_side = tonumber(line1:match("=(.+)"))
            config.cube_side = tonumber(line2:match("=(.+)"))
            -- Check if setup_complete equals "true"
            config.setup_complete = (line3:match("=(.+)") == "true")
            
            print("Config loaded")
            return true
        end
    end
    -- File doesn't exist or couldn't be read properly
    return false
end

-- Save current configuration to file
local function saveConfig()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        -- Write configuration in simple key=value format
        file:write("charger_side=" .. config.charger_side .. "\n")
        file:write("cube_side=" .. config.cube_side .. "\n")
        file:write("setup_complete=true\n")
        file:close()
        print("Config saved")
        return true
    end
    return false
end

-- Scan all sides for connected inventories and display them
local function detectInventories()
    print("Detecting inventories...")
    local inventories = {}
    
    -- Check each of the 6 possible sides (0-5)
    for side = 0, 5 do
        local size = trans.getInventorySize(side)
        if size and size > 0 then
            -- Get the name of the connected inventory
            local name = trans.getInventoryName(side) or "Unknown"
            inventories[side] = {size = size, name = name}
            print(sideNames[side] .. ": " .. name)
        end
    end
    
    return inventories
end

-- Show setup instructions for configuring the Energy Cube
local function showSetupInstructions(cube_side)
    -- Map each side to its opposite side for cube configuration
    local oppositeSides = {
        [sides.up] = sides.down, [sides.down] = sides.up,
        [sides.north] = sides.south, [sides.south] = sides.north,
        [sides.east] = sides.west, [sides.west] = sides.east
    }
    
    -- The cube needs to be configured on the opposite side from where it's connected
    local cubeConfigSide = oppositeSides[cube_side]
    
    print("SETUP REQUIRED:")
    print("1. Open Energy Cube GUI")
    print("2. Go to 'Side Config' tab")
    print("3. Click 'Items' tab")
    print("4. Set " .. sideNames[cubeConfigSide]:upper() .. " side to")
    print("   'Discharge' (Dark Red)")
    print("")
end

-- First-time setup process to detect and configure components
local function runSetup()
    print("=== FIRST TIME SETUP ===")
    
    local inventories = detectInventories()
    
    -- Try to automatically detect charger and energy cube
    local charger_side, cube_side
    
    for side, info in pairs(inventories) do
        -- Look for charger in the inventory name
        if info.name:lower():find("charger") then
            charger_side = side
        end
        -- Look for energy cube in the inventory name
        if info.name:lower():find("cube") or info.name:lower():find("energy") then
            cube_side = side
        end
    end
    
    -- Make sure both components were found
    if not charger_side or not cube_side then
        print("Could not detect components!")
        print("Available:")
        for side, info in pairs(inventories) do
            print("  " .. sideNames[side] .. ": " .. info.name)
        end
        return false
    end
    
    -- Save the detected sides
    config.charger_side = charger_side
    config.cube_side = cube_side
    
    print("Detected:")
    print("Charger: " .. sideNames[charger_side])
    print("Cube: " .. sideNames[cube_side])
    print("")
    
    -- Show instructions for configuring the energy cube
    showSetupInstructions(cube_side)
    
    print("Press ENTER when done...")
    io.read()  -- Wait for user to press enter
    
    -- Mark setup as complete and save configuration
    config.setup_complete = true
    saveConfig()
    
    print("Setup complete!")
    return true
end

-- Check if an item is a battery upgrade
local function isBattery(item)
    if not item then return false end
    
    -- Check the item's display name first
    if item.label then
        local label = item.label:lower()
        if label:find("battery") and label:find("upgrade") then
            return true
        end
    end
    
    -- Check the internal item name as backup
    local name = item.name:lower()
    return name:find("battery") and name:find("upgrade")
end

-- Main automation loop - runs continuously
local function runAutomation()
    print("=== BATTERY AUTOMATION ===")
    print("Charger: " .. sideNames[config.charger_side])
    print("Cube: " .. sideNames[config.cube_side])
    print("Press Ctrl+C to stop")
    print("")
    
    -- Track if we've had successful transfers (helps with error handling)
    local hasWorkedBefore = false
    local failCount = 0
    local maxFails = 5
    
    while true do
        -- Check what's in the first slot of the charger
        local item = trans.getStackInSlot(config.charger_side, 1)
        
        if item and isBattery(item) then
            local itemDesc = item.label or item.name
            print("Found: " .. itemDesc)
            
            -- Try to move battery to energy cube for discharge
            print("Moving to cube...")
            local moved = trans.transferItem(config.charger_side, config.cube_side, 1)
            
            if moved > 0 then
                print("Discharging...")
                -- Move the battery back to the charger (cube will discharge it automatically)
                local returned = trans.transferItem(config.cube_side, config.charger_side, 1)
                
                if returned > 0 then
                    print("Discharge complete!")
                    hasWorkedBefore = true
                    failCount = 0
                else
                    print("Failed to retrieve battery!")
                    failCount = failCount + 1
                end
            else
                -- Transfer failed - could be empty battery or setup issue
                if hasWorkedBefore then
                    -- If it worked before, probably just an empty battery
                    print("Battery empty, skipping...")
                    failCount = 0
                else
                    -- If it never worked, likely a setup problem
                    print("Transfer failed!")
                    print("Likely setup issue.")
                    failCount = failCount + 1
                    
                    -- Show setup instructions after several failures
                    if failCount >= 3 then
                        print("")
                        print("Setup might be wrong:")
                        showSetupInstructions(config.cube_side)
                        failCount = 0
                    end
                end
            end
        else
            -- No battery or wrong item in charger
            if item then
                print("Non-battery: " .. (item.label or item.name))
            else
                print("No battery in charger")
            end
        end
        
        -- Handle too many consecutive failures
        if failCount >= maxFails then
            print("")
            print("Too many failures!")
            print("Check setup and hardware.")
            print("Waiting 30 seconds...")
            print("")
            os.sleep(30)
            failCount = 0
        else
            -- Normal wait between checks
            print("Waiting 5 seconds...")
            print("")
            os.sleep(5)
        end
    end
end

-- Main program execution
print("BATTERY DISCHARGE SYSTEM")

-- Try to load existing configuration
local configLoaded = loadConfig()
if configLoaded then
    print("Using saved config")
    runAutomation()
else
    -- No config found, run first-time setup
    if runSetup() then
        runAutomation()
    end
end
-- Smart Energy Cube Discharge Automation System for OpenComputers
-- Automatically moves Energy Cubes from charger to Mekanism Energy Cube for discharge
local component = require("component")
local sides = require("sides")
local io = require("io")
local os = require("os")

-- Get the transposer component for moving items between inventories
local trans = component.transposer
local CONFIG_FILE = "carpetCharger.conf"

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
    cube_side = nil,         -- Which side the stationary energy cube is connected to
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
            print("  " .. sideNames[side] .. ": " .. name)
        end
    end
    
    return inventories
end

-- Show setup instructions for configuring the stationary Energy Cube
local function showSetupInstructions()
    print("SETUP REQUIRED:")
    print("1. Place the stationary Energy Cube next to the Transposer")
    print("2. Open the Energy Cube GUI")
    print("3. Go to 'Side Config' tab")
    print("4. Click 'Items' tab")
    print("5. Set the side touching the Transposer to")
    print("   'Discharge' (Dark Red)")
    print("6. Place Charger next to the Transposer")
    print("")
end

-- Try to detect both charger and energy cube
local function detectComponents()
    local inventories = detectInventories()
    
    -- Try to automatically detect charger and stationary energy cube
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
    
    return charger_side, cube_side, inventories
end

-- First-time setup process to detect and configure components
local function runSetup()
    print("=== FIRST TIME SETUP ===")
    print("")
    
    -- Show initial setup instructions
    showSetupInstructions()
    
    while true do
        print("Press ENTER when setup is complete...")
        io.read()  -- Wait for user to press enter
        print("")
        
        -- Try to detect components after user input
        local charger_side, cube_side, inventories = detectComponents()
        
        -- Check if both components were found
        if charger_side and cube_side then
            -- Both found! Save configuration
            config.charger_side = charger_side
            config.cube_side = cube_side
            config.setup_complete = true
            
            print("SUCCESS! Detected:")
            print("  Charger: " .. sideNames[charger_side])
            print("  Stationary Cube: " .. sideNames[cube_side])
            print("")
            
            saveConfig()
            print("Setup complete!")
            return true
            
        else
            -- Something is still missing
            print("SETUP INCOMPLETE!")
            print("")
            print("Currently detected:")
            if next(inventories) then
                for side, info in pairs(inventories) do
                    print("  " .. sideNames[side] .. ": " .. info.name)
                end
            else
                print("  No inventories detected")
            end
            print("")
            
            -- Show what's missing
            if not charger_side then
                print("MISSING: Charger (no inventory with 'charger' in name)")
            end
            if not cube_side then
                print("MISSING: Energy Cube (no inventory with 'cube' or 'energy' in name)")
                print("  Make sure the cube side touching the Transposer is set to 'Discharge'!")
            end
            print("")
            
            -- Show setup instructions again
            showSetupInstructions()
        end
    end
end

-- Check if an item is a Mekanism Energy Cube
local function isEnergyCube(item)
    if not item then return false end
    
    -- Check the internal item name first (most reliable)
    if item.name == "mekanism:energycube" then
        return true
    end
    
    -- Check the display name as backup
    if item.label then
        local label = item.label:lower()
        if label:find("energy") and label:find("cube") then
            return true
        end
    end
    
    return false
end

-- Main automation loop - runs continuously
local function runAutomation()
    print("=== ENERGY CUBE AUTOMATION ===")
    print("Charger: " .. sideNames[config.charger_side])
    print("Stationary Cube: " .. sideNames[config.cube_side])
    print("Press Alt+Ctrl+C to stop")
    print("")
    
    -- Track if we've had successful transfers (helps with error handling)
    local hasWorkedBefore = false
    local failCount = 0
    local maxFails = 5
    
    while true do
        -- Check what's in the first slot of the charger
        local item = trans.getStackInSlot(config.charger_side, 1)
        
        if item and isEnergyCube(item) then
            local itemDesc = item.label or item.name
            print("Found: " .. itemDesc)
            
            -- Try to move Energy Cube to stationary cube for discharge
            print("Moving to stationary cube...")
            local moved = trans.transferItem(config.charger_side, config.cube_side, 1)
            
            if moved > 0 then
                print("Discharging...")
                -- Wait a moment for discharge to process
                os.sleep(1)
                -- Move the Energy Cube back to the charger (stationary cube will discharge it automatically)
                local returned = trans.transferItem(config.cube_side, config.charger_side, 1)
                
                if returned > 0 then
                    print("Discharge complete!")
                    hasWorkedBefore = true
                    failCount = 0
                else
                    print("Failed to retrieve Energy Cube!")
                    failCount = failCount + 1
                end
            else
                -- Transfer failed - could be empty cube or setup issue
                if hasWorkedBefore then
                    -- If it worked before, probably just an empty cube
                    print("Energy Cube empty, skipping...")
                    failCount = 0
                else
                    -- If it never worked, likely a setup problem
                    print("Transfer failed!")
                    print("Likely setup issue - cube side may not be set to 'Discharge'")
                    failCount = failCount + 1
                    
                    -- Show setup reminder after several failures
                    if failCount >= 3 then
                        print("")
                        print("REMINDER: Energy Cube side touching Transposer")
                        print("must be set to 'Discharge' (Dark Red) in Side Config!")
                        print("")
                        failCount = 0
                    end
                end
            end
        else
            -- No Energy Cube or wrong item in charger
            if item then
                print("Non-cube item: " .. (item.label or item.name))
            else
                print("No Energy Cube in Charger")
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
print("ENERGY CUBE DISCHARGE SYSTEM")

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

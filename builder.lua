local component = require("component")
local sides = require("sides")
local thread = require("thread")
local term = require("term")

local robotLib = require("robotLib")
local Pos = require('Pos')
local File = require("File")
local Screen = require("Screen")
local Recipe = require("Recipe")

local robot = component.robot
local invc = component.inventory_controller

local DefaultPos = Pos(0,0,0)
local WIDTH , HEIGHT = Screen.getWH()
local idleTimeMax = 5
local inventoryItemList = {}

local inventorySide = 2             -- inventory side, 2 means right, 3 back, 4 left  箱子方向,2为右,3后,4左
local areaSize = 5                  -- craft area size 3 or 5 normal  合成区域大小,一般是3或5
local areaStartPos = Pos(4 , 2)     -- craft area start pos, 4 , 2 means the area start at forward 4 block , right 2 block and bottom 1 block
                                    --合成区域起始位置,前方为x轴正向,右方为y轴正向,合成区域必须是右前方向
local recipeFile = '/home/recipe.txt'
local recipeArea = Pos()
local recipeUsed = {}
local recipeChanged = true

robotLib:init(DefaultPos)

local function processRecipe()
    if recipeChanged then
        recipeUsed = File.ReadFile(recipeFile)
        if (recipeUsed == nil) then
            recipeUsed = Recipe.setRecipe()
        end
    end
    recipeArea = Pos()
    local itemList = {}
    for i,j in pairs(recipeUsed.recipe) do
        for k,v in pairs(j) do
            for l,m in pairs(v) do
                if(m ~= nil) then
                    if(itemList[m] == nil) then
                        itemList[m] = 1
                    else
                        itemList[m] = itemList[m] + 1
                    end
                    recipeArea:large(Pos(l,k,i))
                    if (recipeArea > Pos(areaSize , areaSize , areaSize)) then
                        error('recipe required area larger than the area now')
                    end
                end
            end
        end
    end
    if(recipeUsed.catalyzer ~= nil) then
        if(itemList[recipeUsed.catalyzer] == nil) then
            itemList[recipeUsed.catalyzer] = 1
        else
            itemList[recipeUsed.catalyzer] = itemList[recipeUsed.catalyzer] + 1
        end
    end
    return itemList
end

local function placeBlock()
    local pos = robotLib.getPos() - areaStartPos + Pos(1,1,1)
    if(pos <= recipeArea) then
        local block = recipeUsed.recipe[pos.z][pos.x][pos.y]
        if(block ~= nil) then
            local i = 1
            while (inventoryItemList[block].slot[i] ~= nil) do
                local slot = inventoryItemList[block].slot[i]
                local item = invc.getStackInInternalSlot(slot)
                if (item ~= nil and item.size > 0) then
                    robot.select(slot)
                    robot.place(sides.bottom)
                    return
                end
                i = i + 1
            end
        end
    end
end

local function beforeBuild()
    robotLib.turnTo(inventorySide)
    local itemList = processRecipe()
    local flag = robotLib.suckItem(sides.forward , itemList)
    if(flag) then
        inventoryItemList = robotLib.getItemList()
        idleTimeMax = recipeUsed.craftTime
    end
    robotLib.turnTo(1)
    return flag
end

local function moveToAreaStart()
    for i = 1 , areaStartPos.x do
        robotLib.forward(true)
    end
    robotLib.turn(true)
    for i = 1, areaStartPos.y do
        robotLib.forward(true)
    end
    robotLib.turn(false)
    while (robotLib.getPos().z ~= areaStartPos.z) do
        if (areaStartPos.z > 0) then
            robotLib.moveUp(true)
        else
            robotLib.moveUp(false)
        end
    end
end

local function build()
    local areaEndPos = areaStartPos + recipeArea - Pos(1,1,1)
    local right = true
    local total = recipeArea.x * recipeArea.y
    for i = 1, areaSize do
        local j = 1
        while (j < total and i <= recipeArea.z) do
            while(robotLib.getForwardPos():inArea(areaStartPos, areaEndPos)) do
                placeBlock()
                robotLib.forward(true)
                j = j + 1
            end
            if (j < total) then
                placeBlock()
                robotLib.turn(right)
                robotLib.forward()
                j = j + 1
                robotLib.turn(right)
                right = not right
            end
        end
        placeBlock()
        robotLib.moveUp(true)
        if (total ~= 1 and i < recipeArea.z) then
            robotLib.turn()
            robotLib.turn()
        end
    end
    local catalyzer = recipeUsed.catalyzer
    local i = 1
    while (inventoryItemList[catalyzer].slot[i] ~= nil) do
        local slot = inventoryItemList[catalyzer].slot[i]
        local item = invc.getStackInInternalSlot(slot)
        if (item ~= nil and item.size > 0) then
            robot.select(slot)
            robot.drop(sides.bottom)
            break
        end
        i = i + 1
    end
    robotLib.turnTo(4)
    while(robotLib.getPos().y ~= DefaultPos.y) do
        robotLib.forward(true)
    end
    robotLib.turn(false)
    while(robotLib.getPos().x ~= DefaultPos.x) do
        robotLib.forward(true)
    end
    while(robotLib.getPos().z ~= DefaultPos.z) do
        robotLib.moveUp(false)
    end
    robotLib.turn(true)
    robotLib.turn(true)
end

local function afterBuild()
    while (robotLib.getIdleTime() < idleTimeMax and robotLib.getIdleTime() ~= -1) do
        robotLib.setIdleTime(robotLib.getIdleTime() + 1)
        term.clear()
        local signNumber = math.floor(robotLib.getIdleTime()*50/idleTimeMax)
        print(robotLib.getStatus())
        print(string.rep("*",signNumber)..string.rep("-" ,50 - signNumber))
        print(robotLib.getIdleTime()..' / '..idleTimeMax)
        if(robotLib.getIdleTime() == idleTimeMax - 1 and robotLib.energyLevel() <= 0.6) then
            robotLib.setStatus('low energylevel idling')
            robotLib.setIdleTime(0)
        end
        if (robotLib.key:iskey('q')) then
            robotLib.ShouldRun = false
            return
        end
        os.sleep(1)
    end
    while (robotLib.ShouldSleep) do
        robotLib.Sleeping = true
        os.sleep(1)
    end
    robotLib.Sleeping = false
    if (robotLib.ShouldRun) then
        term.clear()
        print('running')
        robotLib.setIdleTime(0)
    end
end

local function run()
    while true do
        if(robotLib.getPos() == DefaultPos) then
            robotLib.turnTo(1)
            if (robotLib.ShouldRun) then
                robotLib.setStatus('beforeBuild')
                local flag = beforeBuild()
                if(not flag) then
                    Screen.clear()
                    Screen.write('c', HEIGHT / 2 , 'not enough items')
                    robotLib.setStatus('not enough item idling')
                    idleTimeMax = 600
                    afterBuild()
                    idleTimeMax = 5
                else
                    robotLib.setStatus('moveToStart')
                    moveToAreaStart()
                    robotLib.setStatus('build')
                    build()
                end
                robotLib.setStatus('idling')
                afterBuild()
            else
                return
            end
        else
            local string = 'wrong start pos'
            Screen.addInfo('posE', WIDTH - #string, HEIGHT, string)
        end
        os.sleep(0.5)
    end
end

local function menu()
    local key = robotLib.key
    key.blocked = true
    while (not key:iskey('q')) do
        local space = string.rep(' ', math.floor(WIDTH / 6))
        Screen.clear()
        Screen.write('c', 1, 'build robot')
        Screen.write('l', HEIGHT, 'press char to choice')
        Screen.write('l', HEIGHT / 2 - 1, space..'S: set recipe')
        Screen.write('l', HEIGHT / 2 , space..'R: run build robot')
        Screen.write('l', HEIGHT / 2 + 1 , space..'Q: quit program')
        if (key:iskey('s')) then
            robotLib.turnTo(inventorySide)
            Recipe.setRecipe()
            key.key = nil
            robotLib.turnTo(1)
        elseif (key:iskey('r')) then
            key.blocked = false
            Screen.clear()
            Screen.write('l', 1, 'start running')
            robotLib.ShouldRun = true
            run()
        end
        os.sleep(0.5)
    end
    Screen.clear()
    os.exit()
end

if(not robotLib.debug()) then
    Main_thread = thread.create(function()
        while true do
            menu()
            os.sleep(1)
        end
    end)
else
    print('debug mode')
    os.sleep(1)
    menu()
end

thread.waitForAny({robotLib.event_thread, Main_thread})
robotLib = nil
os.exit(0) -- closes all remaining threads
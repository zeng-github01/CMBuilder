local component = require("component")
local sides = require("sides")
local computer = require("computer")
local os = require("os")
local thread = require("thread")
local keyboard = require("keyboard")
local event = require("event")

local Pos = require('Pos')

local robot = component.robot
local invc = component.inventory_controller

local robotLib = {}

local STARTTIME = os.time()
local FILEPATH = '/home/robotStatus.txt'

local pos = Pos()
local face = Pos(1, 0)
local status
local idleTime
local idleTimeMax
local debug = false
local debugInfo = ''
robotLib.keyEvent = {}
robotLib.ShouldSleep = false
robotLib.Sleeping = false
robotLib.ShouldRun = true
robotLib.key = {blocked = false}

local maxEnergy = computer.maxEnergy()
local invSize = robot.inventorySize()

local function updateFile()
    --File.WriteFile(FILEPATH, {pos = pos, face = face, debug = debug})
end

local function getCurrentTime()
    return os.time() / 100
end

robotLib.debug = function()
    return debug
end

robotLib.debugInfo = function(debugInfo_set)
    debugInfo = debugInfo..'\n\t'..debugInfo_set
end

robotLib.getPos = function()
    return pos
end

function robotLib.getForwardPos()
    return pos + face
end

local faceToNumber = function (face_to)
    if (face_to == Pos(1,0)) then
        return 1
    elseif (face_to == Pos(0,1)) then
        return 2
    elseif (face_to == Pos(-1,0)) then
        return 3
    elseif (face_to == Pos(0,-1)) then
        return 4
    end
end

local function numberToFace(face_to)
    if (face_to == 1) then
        return Pos(1,0)
    elseif (face_to == 2) then
        return Pos(0,1)
    elseif (face_to == 3) then
        return Pos(-1,0)
    elseif (face_to == 4) then
        return Pos(0,-1)
    end
end

robotLib.isFace = function(face_to)
    return faceToNumber(face) == face_to
end

robotLib.getFace = function()
    return face
end

robotLib.getStatus = function()
    return status
end

robotLib.setStatus = function(status_set)
    status = status_set
    if debug then
        print(status)
    end
end

robotLib.getIdleTime = function()
    return idleTime
end

robotLib.setIdleTime = function(idleTime_set)
    idleTime = idleTime_set
end

robotLib.STARTTIME = function()
    return STARTTIME
end

robotLib.energyLevel = function()
    return computer.energy() / maxEnergy
end

robotLib.forward =  function(forward)
    if (forward == nil) then
        forward = true
    end
    local flag = false
    while(not flag) do
        if (forward) then
            flag = robot.move(sides.forward)
        else
            flag = robot.move(sides.back)
        end
    end
    if (forward) then
        pos = pos + face
    else
        pos = pos - face
    end
    updateFile()
end

robotLib.moveUp = function(up)
    if (up == nil) then
        up = true
    end
    local flag = false
    while(not flag) do
        if (up) then
            flag = robot.move(sides.top)
        else
            flag = robot.move(sides.bottom)
        end
    end
    if(up) then
        pos = pos + Pos(0, 0, 1)
    else
        pos = pos - Pos(0, 0, 1)
    end
    updateFile()
end

robotLib.turn = function(right)
    if (right == nil) then
        right = true
    end
    robot.turn(right)
    face = face:rotate(right)
    updateFile()
end

robotLib.turnTo = function(face_to)
    face_to = numberToFace(face_to)
    while (face ~= face_to) do
        if (face:rotate(false) == face_to) then
            robotLib.turn(false)
        else
            robotLib.turn(true)
        end
    end
end

-- TODO
robotLib.moveTo = function(pos_to)
    local dpos = pos_to - pos
    if (face == 1) then
        if (dpos > 0) then
            robotLib.forward()
        end
    elseif (face == 2) then
    elseif (face == 3) then
    elseif (face == 4) then
    end
end

robotLib.getItem = function(slot)
    local item = invc.getStackInInternalSlot(slot) or {}
    if (item.name == nil) then
        item.name = ''
        item.damage = 0
        item.size = 0
    end
    if (item.damage ~= 0) then
        item.damage = math.modf(item.damage)
        item.id = item.name..'@'..item.damage
    else
        item.id = item.name
    end
    return item
end

robotLib.getItemOut = function(side, slot)
    local item = invc.getStackInSlot(side, slot) or {}
    if (item.name == nil) then
        item.name = ''
        item.damage = 0
        item.size = 0
    end
    if (item.damage ~= 0) then
        item.damage = math.modf(item.damage)
        item.id = item.name..'@'..item.damage
    else
        item.id = item.name
    end
    return item
end

robotLib.getItemList = function()
    local itemList = {}
    for i=1,16 do
        local item = invc.getStackInInternalSlot(i)
        if (item ~= nil) then
            if (item.damage ~= 0) then
                item.damage = math.modf(item.damage)
                item.id = item.name..'@'..item.damage
            else
                item.id = item.name
            end
            if (itemList[item.id] == nil) then
                itemList[item.id] = item
                itemList[item.id].slot = {i}
            else
                itemList[item.id].size = itemList[item.id].size + item.size
                table.insert(itemList[item.id].slot , i)
            end
        end
    end
    return itemList
end

robotLib.getItemListOut = function(side)
    local slotNumber = invc.getInventorySize(side)
    local itemList = {}
    if(slotNumber ~= nil) then
        local slot = 1
        for item in invc.getAllStacks(side) do
            if (item.name ~= nil) then
                if (item.damage ~= 0) then
                    item.damage = math.modf(item.damage)
                    item.id = item.name..'@'..item.damage
                else
                    item.id = item.name
                end
                if (itemList[item.id] == nil) then
                    itemList[item.id] = item
                    itemList[item.id].slot = {slot}
                else
                    itemList[item.id].size = itemList[item.id].size + item.size
                    table.insert(itemList[item.id].slot , slot)
                end
            end
            slot = slot + 1
        end
        return itemList
    else
        error('Not a Item Inventory')
    end
end

robotLib.suckItem = function(side , itemList)
    local itemsOut = robotLib.getItemListOut(side)
    local flag = true
    if(invc.getInventorySize(side) >= 1) then
        for itemId , count in pairs(itemList) do
            local item = itemsOut[itemId] or {size = 0}
            flag = flag and (item.size >= count)
        end
    end
    if(flag) then
        robot.select(1)
        for item , count in pairs(itemList) do
            local i = 1
            local itemsIn = robotLib.getItemList()
            if (itemsIn[item] == nil) then
                itemsIn[item] = {size = 0}
            end
            while (itemsIn[item].size < count) do
                local countNeed = count - itemsIn[item].size
                invc.suckFromSlot(side , itemsOut[item].slot[i] , countNeed)
                itemsIn = robotLib.getItemList()
                if (invc.getStackInSlot(side, itemsOut[item].slot[i]) == nil) then
                    i = i + 1
                end
            end
        end
    end
    return flag
end

--TODO
robotLib.sort = function()
    local k = 1
    for i = 1 , invSize - 1 do
        local itemA = invc.getStackInInternalSlot(i)
        local itemB = invc.getStackInInternalSlot(i + 1)
    end
    robot.select(1)
end

robotLib.printStatus = function()
end

function robotLib:addKeyEvent(key_set , func)
    key_set = string.lower(key_set)
    self.keyEvent[key_set] = func
end

local function iskey(slef , ...)
    for i , j in pairs({...}) do
        if (slef.key == keyboard.keys[j]) then
            slef.key = nil
            return true
        end
    end
    return false
end
robotLib.key.iskey = iskey

function robotLib:init(pos_set)
    pos = pos_set
    status = 'init'
    idleTime = 0
    local fileRead = File.ReadFile(FILEPATH)
    if (fileRead ~= nil) then
        pos = Pos(fileRead.pos)
        face = Pos(fileRead.face)
        debug = fileRead.debug
        print('read from file:')
        print('pos:\n'..tostring(pos))
        print('face:\n'..tostring(face))
        print('debug:\n'..tostring(debug))
    end
    self.event_thread = thread.create(function()
        while true do
            local name,address,char,key,player = event.pull('key_down')
            robotLib.key.name = name
            robotLib.key.address = address
            robotLib.key.char = char
            robotLib.key.key = key
            robotLib.key.player = player
            if (not robotLib.key.blocked) then
                if(key == keyboard.keys.e) then
                    print('\nE pressed, waiting for finsh task then exit')
                    robotLib.shouldRun = false
                elseif(key == keyboard.keys.r) then
                    robotLib.shouldRun = true
                    robotLib.setIdleTime(-1)
                elseif(key == keyboard.keys.d) then
                    debug = not debug
                end
                for key_set , func in pairs(robotLib.keyEvent) do
                    if(key == keyboard.keys[key_set]) then
                        func()
                    end
                end
            end
        end
    end)
end

return robotLib
local Recipe = {}

local component = require("component")
local keyboard = require("keyboard")
local sides = require("sides")
local thread = require("thread")
local event = require("event")

local robotLib = require("robotLib")
local Screen = require("Screen")
local File = require("File")

local invc = component.inventory_controller

local recipeFile = '/home/recipe.txt'
local slotFilePath = '/home/slot.txt'
local WIDTH , HEIGHT = Screen.getWH()
local STICK = 'minecraft:stick'
local slotToRecipe
local key = {}


local function iskey(slef , ...)
    for i , j in pairs({...}) do
        if (slef.key == keyboard.keys[j]) then
            slef.key = nil
            return true
        end
    end
    return false
end

local function locateRecipeSlot(key)
    local size
    local showinfo = false
    while (not key:iskey('q')) do
        while (not size and not key:iskey('q')) do
            local string1 = 'please choice recipe size'
            local string2 = 'press "A" means 3, press "B" means 5.'
            Screen.clear()
            Screen.write('c', HEIGHT / 2 , string1)
            Screen.write('c', HEIGHT / 2 + 1 , string2)
            if (key:iskey('a')) then
                size = 3
            elseif (key:iskey('b')) then
                size = 5
            end
            if (size) then
                Screen.clear()
                Screen.write('c', HEIGHT / 2 , 'size = '..tostring(size))
            end
            os.sleep(0.5)
        end
        if (not showinfo) then
            local string1 = 'please place two stick at '
            local string2 = string.format([[%d * %d area's]], size, size)
            local string3 = 'top left and bottom right slot'
            Screen.clear()
            Screen.write('c', HEIGHT / 2 , string1..string2)
            Screen.write('c', HEIGHT / 2 + 1 , string3)
            showinfo = true
            os.sleep(3)
        end
        Screen.clear(HEIGHT / 2 - 1)
        Screen.write('c', HEIGHT / 2 - 1 , 'scaning all slot')
        local stick = robotLib.getItemListOut(sides.forward)[STICK]
        Screen.clear(HEIGHT / 2 - 1)
        if (not stick) then
            local string1 = 'please place two stick at '
            local string2 = string.format([[%d * %d area's]], size, size)
            local string3 = 'top left and bottom right slot'
            Screen.clear()
            Screen.write('c', HEIGHT / 2 , string1..string2)
            Screen.write('c', HEIGHT / 2 + 1 , string3)
        elseif (#(stick.slot) ~= 2) then
            Screen.clear()
            Screen.write('c', HEIGHT / 2 , 'the number slot has stick is not two')
        else
            if (key:iskey('c')) then
                Screen.clear()
                Screen.write('c', HEIGHT / 2 , 'calculating slot area')
                local slotA = stick.slot[1]
                local slotB = stick.slot[2]
                local inventoryWidth = (slotB - slotA - size + 1) / (size - 1)
                local _ , flag = math.modf(inventoryWidth)
                if (flag < 1e-9) then
                    slotToRecipe = {}
                    local slotNumber = slotA
                    for i = 1, size do
                        slotToRecipe[i] = {}
                        for j = 1, size do
                            slotToRecipe[i][j] = slotNumber
                            slotNumber = slotNumber + 1
                        end
                        slotNumber = slotNumber + inventoryWidth - size
                    end
                    Screen.clear()
                    Screen.write('c', HEIGHT / 2 , 'slot location saved')
                    File.WriteFile(slotFilePath, slotToRecipe)
                    os.sleep(0.5)
                    return
                else
                    Screen.clear()
                    Screen.write('c', HEIGHT / 2 , 'invalid stick location')
                end
            else
                Screen.clear()
                Screen.write('c', HEIGHT / 2 , 'press "C" to save location')
            end
        end
        os.sleep(1)
    end
    Screen.clear()
end

local function scanRecipeSlot(key)
    local recipe = {}
    local size = #slotToRecipe
    local itemList = {}
    local showList = {}
    local itemNames = {}
    local symList = {'#', '@', '$', '%', '^', '&'}
    local zlevel = 1
    local status = 1
    local showinfo = {false, false}
    while (not key:iskey('q')) do
        if (status == 1) then
            if (not showinfo[status]) then
                local string1 = 'please place blocks that recipe need'
                local string2 =  'at slots seted'
                Screen.clear()
                Screen.write('c', HEIGHT / 2 - 1 , string1)
                Screen.write('c', HEIGHT / 2 , string2)
                showinfo[status] = true
                os.sleep(3)
            end
            Screen.clear(2)
            Screen.write('c', 2 , 'scaning')
            if (not itemList[zlevel]) then
                itemList[zlevel] = {}
            end
            for i = 1, size do
                if (not itemList[zlevel][i]) then
                    itemList[zlevel][i] = {}
                end
                showList[i] = ''
                for j = 1, size do
                    local item = robotLib.getItemOut(sides.forward, slotToRecipe[i][j])
                    if (item.id == '') then
                        itemList[zlevel][i][j] = nil
                        showList[i] = showList[i]..'/'
                    else
                        itemList[zlevel][i][j] = item.id
                        for k, sym in pairs(symList) do
                            if (item.id == itemNames[k]) then
                                showList[i] = showList[i]..sym
                                break
                            elseif (itemNames[k] == nil and item.id ~= '') then
                                showList[i] = showList[i]..sym
                                itemNames[k] = item.id
                                break
                            end
                        end
                        if (showList[i] == '' or showList[i]:sub(-1, -1) == ' ') then
                            showList[i] = showList[i]..'*'
                        end
                    end
                    if (j < size) then
                        showList[i] = showList[i]..' '
                    end
                end
            end
            local string1 = string.format('y level: %d / %d', zlevel, size)
            Screen.clear()
            Screen.write('c', 1 , string1)
            for i = 1, size do
                Screen.write('c', HEIGHT / 2 - size + i , showList[i])
            end
            Screen.write('l', HEIGHT - 2, 'press "Q" to back to up menu')
            Screen.write('l', HEIGHT - 1, 'press "N" to next y level')
            Screen.write('l', HEIGHT , 'press "C" to complete')
            if (key:iskey('n')) then
                if (zlevel < size) then
                    zlevel = zlevel + 1
                else
                    status = 2
                end
            elseif (key:iskey('c')) then
                status = 2
            end
        elseif (status == 2) then
            if (not showinfo[status]) then
                local string = 'please place the catalyzer in slot area'
                Screen.clear()
                Screen.write('c', HEIGHT / 2 , string)
                showinfo[status] = true
                os.sleep(3)
            end
            if (not recipe.recipe) then
                recipe.recipe = itemList
            end
            itemList = {}
            for i = 1, size do
                for j = 1, size do
                    local item = robotLib.getItemOut(sides.forward, slotToRecipe[i][j])
                    if (item.id ~= '') then
                        table.insert(itemList, item.id)
                    end
                end
            end
            if (#itemList == 0) then
                Screen.clear()
                Screen.write('c', HEIGHT / 2 - 1, 'please place the catalyzer in slot area')
            elseif (#itemList ~= 1) then
                Screen.clear()
                Screen.write('c', HEIGHT / 2 - 1, 'there are more than one items in slot area')
                Screen.write('c', HEIGHT / 2, 'catalyzer could only be one item')
            elseif (#itemList == 1) then
                if (key:iskey('c')) then
                    recipe.catalyzer = itemList[1]
                    status = 3
                    Screen.clear()
                    Screen.write('c', HEIGHT / 2, 'catalyzer set: '..itemList[1])
                    os.sleep(1)
                else
                    Screen.clear()
                    Screen.write('c', HEIGHT / 2 - 1, 'please place the catalyzer in slot area')
                    Screen.write('c', HEIGHT / 2, 'press "C" to complete')
                end
            end
        elseif (status == 3) then
            local string = ''
            while (not key:iskey('c', 'enter', 'numpadenter', 'q')) do
                if (key.char >= string.byte('0') and key.char <= string.byte('9')) then
                    string = string..string.char(key.char)
                    key.char = 0
                elseif (key:iskey('back', 'delete')) then
                    string = string:sub(1 , #string - 1)
                end
                Screen.clear()
                Screen.write('c', HEIGHT / 2 - 2, 'please enter craftTime number')
                Screen.write('c', HEIGHT / 2, string)
                Screen.write('l', HEIGHT - 1, 'press "C" or "Enter" to complete')
                os.sleep(0.05)
            end
            recipe.craftTime = tonumber(string) or 0
            status = 4
            Screen.clear()
            Screen.write('c', HEIGHT / 2 - 1, 'recipe added')
        else
            return recipe
        end
        os.sleep(0.1)
    end
end

function Recipe.setRecipe()
    local recipeUsed
    key.iskey = iskey
    local key_thread = thread.create(function()
        while true do
            _,_,key.char,key.key,_ = event.pull('key_down')
        end
    end)
    slotToRecipe = File.ReadFile(slotFilePath)
    if (not slotToRecipe) then
        locateRecipeSlot(key)
    end
    local space = string.rep(' ', math.floor(WIDTH / 6))
    while (not key:iskey('q')) do
        Screen.clear()
        Screen.write('c', math.floor(HEIGHT / 3) , 'press keyboard to choice')
        Screen.write('l', HEIGHT / 2 - 1, space..'R: reset slot location')
        Screen.write('l', HEIGHT / 2 , space..'A: add recipe use saved slot location')
        Screen.write('l', HEIGHT / 2 + 1, space..'Q: quit')
        if (key:iskey('r')) then
            locateRecipeSlot(key)
        elseif (key:iskey('a')) then
            Screen.clear()
            Screen.write('c', HEIGHT / 2 , 'scaning slot')
            recipeUsed = scanRecipeSlot(key)
            if recipeUsed then
                Screen.clear()
                Screen.write('c', HEIGHT / 2, 'writing recipe into file')
                File.WriteFile(recipeFile, recipeUsed)
            end
        end
        os.sleep(0.5)
    end
    Screen.clear()
    key_thread:kill()
    return recipeUsed
end

return Recipe
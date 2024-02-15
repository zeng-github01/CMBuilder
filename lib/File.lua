local filesystem = require('filesystem')

File = {}

local tab = 0

local function writeTab(file)
    file:write(string.rep('  ', tab))
end

local function writeValue(file , value)
    if (type(value) == 'string') then
        file:write('"'..value..'"')
    elseif (type(value) == 'nil') then
        file:write('nil')
    elseif (type(value) == 'number' or type(value) == 'boolean') then
        local dot, _ = tostring(value):find('%.0+$')
        if (dot) then
            value = tostring(value):sub(1, dot - 1)
        end
        file:write(tostring(value))
    elseif (type(value) == 'table') then
        file:writeObj(value)
    else
        error('Invalid value to write')
    end
end

local function detectArray(obj)
    local isArray = true
    local valueType = 'nil'
    local valueTypeOld = 'nil'
    for key , value in pairs(obj) do
        valueTypeOld = valueType
        valueType = type(value)
        local flag = valueType ~= 'nil' and valueTypeOld ~= 'nil'
        flag = flag and valueType ~= valueTypeOld
        if (type(key) ~= 'number' or flag) then
            isArray = false
            break
        end
    end
    return isArray , valueType == 'table'
end

local function writeArray(file , array , isTable)
    file:write('{')
    if isTable then
        file:write('\n')
        tab = tab + 1
    end
    local length = 0
    for key , value in pairs(array) do
        length = math.max(length, key)
    end
    for i = 1, length do
        if isTable then
            file:writeTab()
        end
        file:writeValue(array[i])
        if i < length then
            file:write(',')
            if isTable then
                file:write('\n')
            else
                file:write(' ')
            end
        end
    end
    if isTable then
        tab = tab - 1
        file:write('\n')
        file:writeTab()
    end
    file:write('}')
end

local function writeObj(file , obj)
    local length = 0
    for key , value in pairs(obj) do
        length = length + 1
    end
    local isArray , valueType = detectArray(obj)
    if isArray then
        file:writeArray(obj, valueType)
    else
        file:write('{\n')
        tab = tab + 1
        local j = 1
        for key, value in pairs(obj) do
            file:writeTab()
            file:writeValue(key)
            file:write(' = ')
            file:writeValue(value)
            if j < length then
                file:write(',\n')
                j = j + 1
            end
        end
        tab = tab - 1
        file:write('\n')
        file:writeTab()
        file:write('}')
    end
end

function File.WriteFile(filepath , obj)
    if (obj == nil) then
        return
    end
    if (filesystem.exists(filepath)) then
        local point = filepath:reverse():find('/')
        local path = filepath:reverse():sub(point, -1):reverse()
        local name = filepath:reverse():sub(1, point - 1):reverse()
        local old = path..name:gsub('(%.%w+)$', '_old%1')
        if filesystem.exists(old) then
            filesystem.remove(old)
        end
        filesystem.rename(filepath, old)
    end
    local file = filesystem.open(filepath, 'w')
    file.writeValue = writeValue
    file.writeObj = writeObj
    file.writeTab = writeTab
    file.writeArray = writeArray
    file:writeObj(obj)
    file:close()
end

local function parse(tokenList)
    local obj = {}
    local i , k = 1 , 1
    local nil_value = false
    local key , value
    while(i <= #tokenList) do
        local token = tokenList[i]
        if (token == '{') then
            local atable = {}
            local count = 0
            for j = i + 1, #tokenList do
                if (tokenList[j] == '{') then
                    count = count + 1
                    table.insert(atable, tokenList[j])
                elseif (tokenList[j] ~= '}') then
                    table.insert(atable, tokenList[j])
                elseif (tokenList[j] == '}' and count > 0) then
                    table.insert(atable, tokenList[j])
                    count = count - 1
                elseif (tokenList[j] == '}' and count == 0) then
                    i = j
                    break
                else
                    error('"{" missing "}" at '..tokenList[i - 2]..tokenList[i - 1]..' at '..i)
                end
            end
            value = parse(atable)
        elseif (token:match('[0-9-]') ~= nil) then
            local number = ''
            for j = i , #tokenList do
                if (tokenList[j]:match('[0-9e.-]') ~= nil) then
                    number = number..tokenList[j]
                elseif (tokenList[j]:match('[,=}]') ~= nil) then
                    i = j
                    break
                else
                    error('Invalid number token: '..tokenList[j - 1]..tokenList[j]..' at '..j)
                end
                i = j
            end
            if (tokenList[i] == '=' and key == nil) then
                key = tonumber(number)
            else
                value = tonumber(number)
            end
        elseif (token:match('[tfn]')) then
            local three = token..tokenList[i+1]..tokenList[i+2]
            local four = three .. (tokenList[i+3] or '')
            local five = four .. (tokenList[i+4] or '')
            if (three == 'nil') then
                nil_value = true
                i = i + 3
            elseif (four == 'true') then
                value = true
                i = i + 4
            elseif (five == 'false') then
                value = false
                i = i + 5
            else
                error('Invalid number token: '..tokenList[i - 1]..tokenList[i]..' at '..i)
            end
        elseif (token == '"') then
            local string = ''
            local count = 0
            for j = i + 1, #tokenList do
                if (tokenList[j] ~= '"') then
                    string = string..tokenList[j]
                elseif (tokenList[j] == '"' and count > 0) then
                    string = string..tokenList[j]
                    count = count - 1
                elseif (tokenList[j] == '"' and count == 0) then
                    i = j + 1
                    break
                else
                    error([['"' missing '"' at ]]..tokenList[i - 2]..tokenList[i - 1]..' at '..i)
                end
            end
            if (tokenList[i] == '=' and key == nil) then
                key = string
            else
                value = string
            end
        elseif (token:match('[,}]') ~= nil) then
        elseif (token == '=' and key ~= nil) then
        else
            error(string.format('parse token " %s " error at %s%s %d',token,tokenList[i - 2], tokenList[i - 1], i))
        end
        if (value ~= nil or nil_value) then
            if (nil_value) then
                nil_value = false
            end
            if (key ~= nil) then
                obj[key] = value
                key , value = nil , nil
            else
                obj[k] = value
                k = k + 1
                value = nil
            end
        end
        i = i + 1
    end
    return obj
end

function File.ReadFile(filepath)
    if (not filesystem.exists(filepath)) then
        return nil
    else
        local tokenList = {}
        for line in io.lines(filepath) do
            for token in line:gmatch('%S') do
                table.insert(tokenList, token)
            end
        end
        return parse(tokenList)[1]
    end
end


return File
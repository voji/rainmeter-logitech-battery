local lastRead = os.time()
local hasRead = false
local nextPoll = nil
local validReading = false

local function pollInterval()
    local variable = validReading and 'RefreshSeconds' or 'RetrySeconds'
    local fallback = validReading and 900 or 30
    return math.max(1, tonumber(SKIN:GetVariable(variable)) or fallback)
end

local function show(percent, charging)
    local frame, color, status = 20, '144,144,144', 'Mouse unavailable'
    local text = '--%'
    if percent then
        text = tostring(percent) .. '%'
        color, status = '107,198,250', ''
        if percent < 10 then
            frame, color, status = 18, '255,80,80', 'Critical battery'
        elseif percent < 20 then
            frame, color, status = 16, '255,158,0', 'Low battery'
        elseif percent > 90 then frame = 0
        elseif percent > 80 then frame = 1
        elseif percent > 75 then frame = 2
        else frame = math.min(14, 3 + math.floor((75 - percent) / 5)) end
        if charging then
            color, status = '107,198,250', ''
            if percent < 10 then frame = 19
            elseif percent < 20 then frame = 17 end
        end
    end
    SKIN:Bang('!SetVariable', 'BatteryFrame', tostring(frame))
    SKIN:Bang('!SetVariable', 'BatteryText', text)
    SKIN:Bang('!SetVariable', 'BatteryColor', color)
    SKIN:Bang('!SetVariable', 'BatteryStatus', status)
    SKIN:Bang('!SetVariable', 'ChargingHidden', percent and charging and '0' or '1')
    SKIN:Bang('!UpdateMeter', '*')
    SKIN:Bang('!Redraw')
end

function ReadBattery()
    lastRead, hasRead = os.time(), true
    local output = SKIN:GetMeasure('MeasureMouseCommand'):GetStringValue()
    local device = SKIN:GetVariable('DeviceName')
    local escaped = device:gsub('([^%w])', '%%%1')
    local percent, charging
    for line in output:gmatch('[^\r\n]+') do
        local value, suffix = line:match('^%s*' .. escaped .. ':%s*(%d+)%%%s*(.-)%s*$')
        if value and (suffix == '' or suffix == '(charging)') then
            value = tonumber(value)
            if value >= 0 and value <= 100 then
                percent, charging = value, suffix == '(charging)'
                break
            end
        end
    end
    validReading = percent ~= nil
    nextPoll = os.time() + pollInterval()
    show(percent, charging)
    -- Keep a small diagnostic record of the value actually parsed by Rainmeter.
    local file = io.open(SKIN:GetVariable('CURRENTPATH') .. 'LastReading.txt', 'w')
    if file then
        file:write(os.date('%Y-%m-%d %H:%M:%S'), '\n', device, ': ', percent and (tostring(percent) .. '%' .. (charging and ' (charging)' or '')) or 'unavailable', '\n')
        file:close()
    end
    return percent or -1
end

function Update()
    local now = os.time()
    local interval = pollInterval()
    -- The first script update polls immediately; subsequent polls use the interval.
    if not nextPoll or now >= nextPoll then
        nextPoll = now + interval
        SKIN:Bang('!CommandMeasure', 'MeasureMouseCommand', 'Run')
    end
    local limit = interval + 15
    if now - lastRead > limit then
        show(nil)
        validReading = false
        nextPoll = math.min(nextPoll, now + pollInterval())
        lastRead = now
    end
    return hasRead and 1 or 0
end

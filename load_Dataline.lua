function print(v) reaper.ShowConsoleMsg(v .. '\n') end
function trim(s) return s:match '^%s*(.-)%s*$' end
function isComment(s) return s:sub(1, 1) == '#' end
function hasData(s) return not (s == '' or isComment(s)) end
function hasWhitespace(s) return s:find('%s', 1, false) end

function dump(o, i)
    local indentationWidth = 4
    i = i or 0 -- Indentation.
    if type(o) == 'table' then
        local s = '{ '
        i = i + indentationWidth
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '\n' .. string.rep(' ', i) ..
              '['.. k ..'] = ' .. dump(v, i) .. ','
        end
        i = i - indentationWidth
        return s .. '\n' .. string.rep(' ', i) .. '}'
    else
        return tostring(o)
    end
end

function getData(file)
    local data = {}
    for line in io.lines(file) do
        line = trim(line)
        if hasData(line) then
            local time, voice, event = line:match '^(.-)%s+(.-)%s+(.-)$'
            local datum = {}
            datum['time'] = tonumber(time)
            datum['voice'] = tonumber(voice)
            if hasWhitespace(event) then
                local eventType, eventData = event:match"^(.-)%s+(.-)$"
                datum['eventType'] = eventType
                datum['eventData'] = eventData
            else
                datum['eventType'] = event
            end
            data[#data + 1] = datum
        end
    end
    return data
end

function main()
    local wasFileRead, file = reaper.GetUserFileNameForRead(
      '', 'Choose a *.dataline file.', 'dataline'
    )
    if wasFileRead then
            -- Note: Assumes the Dataline file is valid.
        data = getData(file)
        print(dump(data))
    end
end

main()

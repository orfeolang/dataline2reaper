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

function inArray(t, search)
    for i, v in ipairs(t) do
        if v == search then
            return true
        end
    end
    return false
end

function getVoices(data)
    local voices = {}
    for i = 1, #data do
        if not inArray(voices, data[i]['voice']) then
            voices[#voices + 1] = data[i]['voice']
        end
    end
    table.sort(voices)
    return voices
end

function nameTrack(trackIndex, voiceNumber)
    local track = reaper.GetTrack(0, trackIndex)
    local name = 'voice ' .. voiceNumber
    reaper.GetSetMediaTrackInfo_String(
        track, 'P_NAME', name, true
    )
end

function addTracks(voices)
    for i = 1, #voices do
        local index = i - 1
        reaper.InsertTrackAtIndex(index, true)
        nameTrack(index, voices[i])
    end
end

function main()
    local wasFileRead, file = reaper.GetUserFileNameForRead(
      '', 'Choose a *.dataline file.', 'dataline'
    )
    if wasFileRead then
            -- Note: Assumes the Dataline file is valid.
        data = getData(file)
        print(dump(data))

        local voices = getVoices(data)
        print(dump(voices))

        addTracks(voices)
        reaper.UpdateArrange()
    end
end

main()

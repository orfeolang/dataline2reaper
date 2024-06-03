---------------------------------------------------------------------
-- Config

DEFAULT_SOUND_EXTENSION = 'aiff'
REMOVE_ALL_TRACKS_BEFORE_START = true
DATALINE_FILE_PATH = '/my/dataline/file.dataline'
SOUND_FOLDER_PATH = '/my/sound/path/'

----------------------------------------------------------------------
-- General Utilities

    -- Debug helper - Ex: print(dump(myTable))
function dump (o, i)
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

function trim (s) return s:match '^%s*(.-)%s*$' end
function hasWhitespace (s) return s:find('%s', 1, false) end
function hasExtension (s) return s:match '^.+(%..+)$' ~= nil end

function splitOnWhitespace (data)
    local result = {}
    for datum in (data .. ' '):gmatch('(.-)%s+') do
        table.insert(result, datum)
    end
    return result
end

function inIpairs (t, target)
    for _, v in ipairs(t) do
        if v == target then
            return true
        end
    end
    return false
end

function getSortedTableKeys (t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

----------------------------------------------------------------------
-- Program

    -- Main_OnCommand
local MOC = {
    REMOVE_ALL_SELECTED_TRACKS = 40005,
    REWIND_TO_START = 40042,
    SELECT_ALL_TRACKS = 40296,
    UNSELECT_ALL_TRACKS = 40297,
}

function isComment (s) return s:sub(1, 1) == '#' end
function hasData (s) return not (s == '' or isComment(s)) end
function print (v) reaper.ShowConsoleMsg(v .. '\n') end
function isFile (path) return reaper.file_exists(path) end
function isNote(v) return v['type'] == 'note' and v['data'] ~= nil end

function reaper_RemoveAllTracks ()
    reaper.Main_OnCommand(MOC['SELECT_ALL_TRACKS'], 0)
    reaper.Main_OnCommand(MOC['REMOVE_ALL_SELECTED_TRACKS'], 0)
end

function reaper_InterfaceReset ()
    reaper.Main_OnCommand(MOC['UNSELECT_ALL_TRACKS'], 0)
    reaper.Main_OnCommand(MOC['REWIND_TO_START'], 0)
end

function getData (datalinePath)
    local data = {}
    for line in io.lines(datalinePath) do
        line = trim(line)
        if hasData(line) then
            local time, voice, type_data = line:match '^(.-)%s+(.-)%s+(.-)$'
            local event = {}
            event['time'] = tonumber(time)
            event['voice'] = tonumber(voice)
            if hasWhitespace(type_data) then
                local type, data = type_data:match"^(.-)%s+(.-)$"
                event['type'] = type
                event['data'] = data
            else
                event['type'] = type_data
            end
            table.insert(data, event)
        end
    end
    return data
end

function getVoices (data)
    local voices = {}
    for _, v in ipairs(data) do
        if not inIpairs(voices, v['voice']) then
            table.insert(voices, v['voice'])
        end
    end
    table.sort(voices)
    return voices
end

function nameTrack (trackIndex, voiceNumber)
    local track = reaper.GetTrack(0, trackIndex)
    local name = 'voice ' .. voiceNumber
    reaper.GetSetMediaTrackInfo_String(
        track, 'P_NAME', name, true
    )
end

function addTracks (voices)
    for i, v in ipairs(voices) do
        local trackIndex = i - 1
        reaper.InsertTrackAtIndex(trackIndex, true)
        nameTrack(trackIndex, v)
    end
end

function getTrackIndexFromVoice (voices, voice)
    for i, v in ipairs(voices) do
        if v == voice then
            return i - 1
        end
    end
    return nil
end

--[[
integer reaper.InsertMedia(string file, integer mode)

mode:
    0=add to current track,
    1=add new track,
    3=add to selected items as takes,
    &4=stretch/loop to fit time sel,
    &8=try to match tempo 1x,
    &16=try to match tempo 0.5x,
    &32=try to match tempo 2x,
    &64=don't preserve pitch when matching tempo,
    &128=no loop/section if startpct/endpct set,
    &256=force loop regardless of global preference for looping imported items,
    &512=use high word as absolute track index if mode&3==0 or mode&2048,
    &1024=insert into reasamplomatic on a new track (add 1 to insert on last selected track),
    &2048=insert into open reasamplomatic instance (add 512 to use high word as absolute track index),
    &4096=move to source preferred position (BWF start offset),
    &8192=reversep
]]--

function reaper_GetMediaItemLength (item)
    local take = reaper.GetTake(item, 0)
    local source = reaper.GetMediaItemTake_Source(take)
    return reaper.GetMediaSourceLength(source)
end

local insertMediaMode = {
    ADD_TO_CURRENT_TRACK = 0,
    REVERSED = 8192,
}

function addMedia (trackIndex, path, position, isReversed)
    local track = reaper.GetTrack(0, trackIndex)
    reaper.SetMediaTrackInfo_Value(track, 'I_SELECTED', 1)
    local mode = insertMediaMode['ADD_TO_CURRENT_TRACK']
    if isReversed then mode = mode + insertMediaMode['REVERSED'] end
    reaper.InsertMedia(path, mode)
    local item = reaper.GetSelectedMediaItem(0, 0)
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position) -- Reposition.
    reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 0) -- Optional. For form.
    reaper.SelectAllMediaItems(0, false)
end

function getDatalineFilePath (DATALINE_FILE_PATH)
    local datalineFilePath
    if DATALINE_FILE_PATH then
        if not isFile(DATALINE_FILE_PATH) then
            print('ERROR: DATALINE_FILE_PATH is not a valid path.')
            print('  ' .. DATALINE_FILE_PATH)
        else
            datalineFilePath = DATALINE_FILE_PATH
        end
    else
        gotPath, path = reaper.GetUserFileNameForRead(
            '', 'Choose a Dataline file.', '*.dataline'
        )
        if gotPath then
            datalineFilePath = path
        end
    end
    return datalineFilePath
end

function getSoundFolderPath (SOUND_FOLDER_PATH)
    local soundFolderPath
    if SOUND_FOLDER_PATH then
        soundFolderPath = SOUND_FOLDER_PATH
    else
            -- Note: JS_Dialog_BrowseForFolder needs js_ReaScriptAPI installed.
        gotPath, path = reaper.JS_Dialog_BrowseForFolder(
            'Choose a sound folder.', nil
        )
        if gotPath then
            soundFolderPath = path
        end
    end
    return soundFolderPath
end

function checkIfSoundIsReversed (sound)
    if sound:sub(1, 1) == '-' then
        return true, sound:sub(2)
    end
    return false, sound
end

function main()
    reaper.ClearConsole()
    local datalineFilePath = getDatalineFilePath(DATALINE_FILE_PATH)
    local soundFolderPath = getSoundFolderPath(SOUND_FOLDER_PATH)
    if datalineFilePath and soundFolderPath then
        if REMOVE_ALL_TRACKS_BEFORE_START then reaper_RemoveAllTracks() end
        reaper_InterfaceReset()
            -- Note: Assumes the Dataline file is valid.
        local data = getData(datalineFilePath)
        local voices = getVoices(data)
        addTracks(voices)
        local missingSoundFiles = {}
        for _, v in ipairs(data) do
            if isNote(v) then
                local trackIndex = getTrackIndexFromVoice(voices, v['voice'])
                local sounds = splitOnWhitespace(v['data'])
                for __, sound in ipairs(sounds) do
                    local isReversed, sound = checkIfSoundIsReversed(sound)
                    if not hasExtension(sound) then
                        sound = sound .. '.' .. DEFAULT_SOUND_EXTENSION
                    end
                    local soundPath = soundFolderPath .. sound
                    if isFile(soundPath) then
                        addMedia(trackIndex, soundPath, v['time'], isReversed)
                    else
                        missingSoundFiles[soundPath] = 1
                    end
                end
            end
        end
        local next = next -- Optimization.
        if next(missingSoundFiles) ~= nil then -- If missingSoundFiles has elements.
            print('WARNING: The following sound files could not be found:')
            for _, soundFile in pairs(getSortedTableKeys(missingSoundFiles)) do
                print('  ' .. soundFile)
            end
        end
        reaper_InterfaceReset()
        reaper.UpdateArrange()
    end
end

main()

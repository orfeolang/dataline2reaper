----------------------------------------------------------------------
-- Config

DEFAULT_SOUND_EXTENSION = 'aiff'
REMOVE_ALL_TRACKS_BEFORE_START = true
DATALINE_FILE_PATH = '/my/dataline/file.dataline'
SOUND_FOLDER_PATH = '/my/sound/path/'

----------------------------------------------------------------------
-- General Utilities

    -- Debug helper - Ex: print(dump(myTable))
function dump (obj, currentIndentationWidth)
    local indentationWidth = 4
    i = currentIndentationWidth or 0
    if type(obj) == 'table' then
        local s = '{ '
        i = i + indentationWidth
        for k, v in pairs(obj) do
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

function clip (num, min, max)
    if num < min then num = min end
    if num > max then num = max end
    return num
end

function scale (num, oldMin, oldMax, newMin, newMax)
    return newMin + (((newMax - newMin) * (num - oldMin)) / (oldMax - oldMin))
end

function getRandomFloat (min, max)
    return scale(math.random(), 0, 1, min, max)
end

    -- Percentage is between 0 and 1.
function getRandomSectionFromPct (pct)
    local maxStartPct = 1 - pct
    local startPct = getRandomFloat(0, maxStartPct)
    return startPct, startPct + pct
end

----------------------------------------------------------------------
-- Program

    -- Main_OnCommand
local MOC = {
    REMOVE_ALL_SELECTED_TRACKS = 40005,
    REMOVE_TIME_AND_LOOP_SELECTION = 40020,
    REWIND_TO_START = 40042,
    SELECT_ALL_TRACKS = 40296,
    UNSELECT_ALL_TRACKS = 40297,
}

local insertMediaMode = {
    ADD_TO_CURRENT_TRACK = 0,
    REVERSED = 8192,
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
    reaper.Main_OnCommand(MOC['REMOVE_TIME_AND_LOOP_SELECTION'], 0)
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

function initRandomGenerator ()
    math.randomseed(os.time())
    math.random()
    math.random()
    math.random()
end

function hasSectOption(o)
    for k, v in pairs(o) do
        if k:sub(1, 4) == 'sect' then
            return true
        end
    end
    return false
end

function getStartAndEndPct (path, o)
    if o['sectRandPct'] then
        return getRandomSectionFromPct(o['sectRandPct'])

    elseif o['sectStartPct'] and o['sectEndPct'] then
        return o['sectStartPct'], o['sectEndPct']

    elseif o['sectStartPct'] and not o['sectEndSec'] then
        return o['sectStartPct'], 1

    elseif not o['sectStartSec'] and o['sectEndPct'] then
        return 0, o['sectendPct']

    else
        local source = reaper.PCM_Source_CreateFromFile(path)
        local length = reaper.GetMediaSourceLength(source)

        if o['sectStartPct'] and o['sectEndSec'] then
            return o['sectStartPct'], o['sectEndSec'] / length

        elseif o['sectStartSec'] and o['sectEndPct'] then
            return o['sectStartSec'] / length, o['sectEndPct']

        elseif o['sectRandSec'] then
            return getRandomSectionFromPct(o['sectRandSec'] / length)

        elseif o['sectStartSec'] and o['sectEndSec'] then
            return o['sectStartSec'] / length, o['sectEndSec'] / length

        elseif o['sectStartSec'] then
            return o['sectStartSec'] / length, 1

        elseif o['sectEndSec'] then
            return 0, o['sectEndSec'] / length

        end
    end
    return 0, 1 -- Default. (We should never reach here.)
end

-----------------------------------------------------------'
-- o = options
--
-- o['isReversed']   (bool)       Reverse audio.
-- o['vol']          (num:  0->)  Volume. Ex: 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
-- o['pan']          (num: -1->1) Pan position.
-- o['playrate']     (num:  0->)  Playrate. Ex: 0.5=half speed, 1=normal, 2=double speed, etc
-- o['pitch']        (num)        Pitch shift in semitones. Ex: -1.5 minus 1.5 semitones.
-- o['doPPitch']     (bool)       Preserve pitch when changing playrate.
-- o['sectStartPct'] (num:  0->1) Section start in percentage.
-- o['sectEndPct']   (num:  0->1) Section end end in percentage.
-- o['sectStartSec'] (num:  0->1) Section start in seconds.
-- o['sectEndSec']   (num:  0->1) Section end in seconds.
-- o['sectRandPct']  (num:  0->)  Random section in pecentage.
-- o['sectRandSec']  (num:  0->)  Random section in seconds.
--
-- All options starting with sect are for determining the section
-- of the audio file to play. If none are set, the entire file is played.
-- These options can be conflicting, so there is an order of priority
-- in which they are set. Percentages win out over seconds, and
-- random sections win out over start/end combinations.
--
-- Ex 1) If 'sectRandPct' is set, it will win out over every other sect option
-- and a random percentage of the section will be chosen for play.
--
-- Ex 2) If 'sectStartSec', 'sectEndSec', and 'sectEndPct' are set, the
-- section will be determined by 'sectStartSec' and 'sectEndPct'.
--
-- Note: It's possible to set only the start or end of a section. If start
-- is missing, playing begins at the start of the section, and if end
-- is missing, playing lasts until the end of the section.
-----------------------------------------------------------
function reaper_AddMedia (trackIndex, path, position, o)
    local track = reaper.GetTrack(0, trackIndex)
    reaper.SetMediaTrackInfo_Value(track, 'I_SELECTED', 1)
    local mode = insertMediaMode['ADD_TO_CURRENT_TRACK']
    if o['isReversed'] then mode = mode + insertMediaMode['REVERSED'] end
    if hasSectOption(o) then
        local startPct, endPct = getStartAndEndPct(path, o)
        reaper.InsertMediaSection(path, mode, startPct, endPct, 0) -- 0 = no pitch shift.
    else
        reaper.InsertMedia(path, mode)
    end
    local item = reaper.GetSelectedMediaItem(0, 0)
    reaper.SetMediaItemInfo_Value(item, 'D_POSITION', position)
    local take = reaper.GetTake(item, 0)
    if o['vol']      then reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL',      o['vol'])      end
    if o['pan']      then reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN',      o['pan'])      end
    if o['playrate'] then reaper.SetMediaItemTakeInfo_Value(take, 'D_PLAYRATE', o['playrate']) end
    if o['pitch']    then reaper.SetMediaItemTakeInfo_Value(take, 'D_PITCH',    o['pitch'])    end
    if o['doPPitch'] then reaper.SetMediaItemTakeInfo_Value(take, 'D_PPITCH',   o['doPPitch']) end
    reaper.SetMediaTrackInfo_Value(track, 'I_SELECTED', 0)
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
    initRandomGenerator()
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
                    local options = {}
                    if isFile(soundPath) then
                        reaper_AddMedia(trackIndex, soundPath, v['time'], options)
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

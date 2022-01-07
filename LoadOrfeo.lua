

function msg (input)
  reaper.ShowConsoleMsg("\n"..input)
end

function get_track_no (line) --gets track number in a given line
  local result = {}
  for datum in (line.." "):gmatch("(.-)".."(%s+)") do
     table.insert(result, datum)
     if result[2] then return result[2] end
  end
end

function split (data)
  local result = {}
  for datum in (data.." "):gmatch("(.-)".."(%s+)") do
    table.insert(result, datum)
  end
  return result
end

function read_file (file)
  local result = {}
  for line in io.lines(file) do 
    result[#result + 1] = line
  end
  return result
end

function add_tracks (data) -- initially add all distinct tracks in the datafile
  local seen = {}
  local added_tr_no = 0
  for i = 1, #data do
    local tr = get_track_no (data[i])
    if not seen [tr] == true then
      added_tr_no = added_tr_no + 1
      reaper.InsertTrackAtIndex(added_tr_no, true)
      seen [tr] = true
    end
  end
end

function add_media(track_no, vol_db, pan, path, position, item_no)
  msg ("processing line number: "..item_no.."\n")
  local track = reaper.GetTrack(0, track_no)
  --select active track. Hopefully this means "current track"
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0 )
  local vol_log = math.exp(vol_db*0.115129254)
  if not vol_db == "X" then reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol_log ) end
  if not pan == "X" then reaper.SetMediaTrackInfo_Value(track, "D_PAN", pan ) end
  reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 1 )
  reaper.SetTrackSelected( track, true )
  reaper.InsertMedia(path, 0)
  local item = reaper.GetSelectedMediaItem(0, item_no )
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position )
end

function process_file (data, folder)
  add_tracks (data)
  if not reaper.CountMediaItems( 0 ) == nil then 
       local item_count =  reaper.CountMediaItems( 0 ) 
       mwg ("number of existing media item: "..item_count)
  else item_count = 0
  end
  
  for i = 1, #data do
    local parameters = split(data[i])

    local position = tonumber (parameters[1])
    local track_no = tonumber (parameters[2])
    
    if parameters[3] == "X" then 
      local vol_db = "X" 
    else vol_db = tonumber (parameters [3])
    end
    
    if parameters[4] == "X" then 
      local pan = "X" 
    else pan = tonumber (parameters [4])
    end
    
    local media = parameters[5]
    
    if not vol_db == "X" and not pan == "X" then
      if vol_db > 12
        then 
        msg ("Volume out of range on track "..track_no.."; Default volume set.")
        vol_db = 12
      end
      if pan > 1 or pan < -1
        then pan = 0
        msg ("Pan out of range on track "..track_no.."; set to center.")
      end
    end
    
    --media_dir = "C:/Users/Johnny G/AppData/Roaming/REAPER/Scripts/Orfeo_test_dir"
    --path = media_dir.."/"..media
    path = folder.."/"..media

    msg ("Line "..i.." processed:")
    msg ("track# = "..track_no)
    msg ('Media = '..media)
    msg ("Volume = "..vol_db)
    msg ("Pan = "..pan)
    msg ("Pos = "..position.."s")
    add_media(track_no-1, vol_db ,pan, path, position, item_count + i - 1)
    
  end 
 
end

  

function Main ()
  reaper.ShowConsoleMsg("")
  --retval, file = reaper.GetUserFileNameForRead("data", "Choose data file", "txt" )
  --file = "C:/Users/Johnny G/Desktop/datafile.txt" 
  file = "D:/Tempakshawn/Lua Orfeo project/Datafile.txt" --temp working file
  --retval, folder = reaper.JS_Dialog_BrowseForFolder(caption, initialFolder)
  folder = "D:/Tempakshawn/Lua Orfeo project/media" --temp working folder
  data = read_file (file)
  msg ("number of lines in data file: "..#data)
  msg ("Parent media folder: "..folder.."\n") 
  process_file (data, folder)
  reaper.UpdateArrange()
end 
 
  
Main()






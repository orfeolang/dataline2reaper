

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

function add_tracks (data) -- initially add tracks up to the highest number specified in the file 
  if  not reaper.CountTracks( 0 ) == nil then
    local max_tracks =  reaper.CountTracks( 0 )
  else max_tracks = 0 
  end
  for i = 1, #data do
    local tr = tonumber (get_track_no (data[i]))
    if tr > max_tracks then max_tracks = tr end
  end 
  for i = 0, max_tracks-1 do
    reaper.InsertTrackAtIndex(i, true)
  end
end

function add_media(track_no, vol_db, pan, path, position, item_no)
  --msg ("processing line number: "..item_no.."\n")
  local track = reaper.GetTrack(0, track_no)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0 )
  local vol_log = math.exp(vol_db*0.115129254)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol_log ) 
  reaper.SetMediaTrackInfo_Value(track, "D_PAN", pan ) 
  reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 1 )
  --reaper.SetTrackSelected( track, true )
  --item_count =  reaper.CountMediaItems( proj ) -- number of items before inserting current media
  reaper.InsertMedia(path, 0)
  
  --get the item number-- 
  media_count = 0 
  msg (track_no.."  "..reaper.CountMediaItems( 0 ))
  if track_no > 0 and reaper.CountMediaItems( 0 ) ~= 1 then
    msg ("true")
    for i = 0,(track_no-1) do
      msg ("i = "..i)
      current_track = reaper.GetTrack(0, i)
      media_on_track = reaper.CountTrackMediaItems(current_track) 
      msg ("media on track "..track_no.." = "..media_on_track)
      media_count = media_count + media_on_track
    end
  end
  item_no = media_count
  msg ("\nmedia item no:"..item_no.."\n")
  local item = reaper.GetSelectedMediaItem(0, item_no)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position )
  reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 0 )
end

function process_file (data, folder)
  add_tracks (data)
  for i = 1, #data do
    local parameters = split(data[i])

    local position = tonumber (parameters[1])
    local track_no = tonumber (parameters[2])
    local  vol_db = tonumber (parameters [3])
    local pan = tonumber (parameters [4])
    local media = parameters[5]
    
    if vol_db > 12
      then 
      msg ("Volume out of range on track "..track_no.."; Default volume set.")
      vol_db = 12
    end
    
    if pan > 1 or pan < -1
      then pan = 0
      msg ("Pan out of range on track "..track_no.."; set to center.")
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
    add_media(track_no-1, vol_db ,pan, path, position, i-1)
    
  end 
 
end

function Main ()
  reaper.ShowConsoleMsg("")
  
  msg (reaper.CountMediaItems( 0 ))
  
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






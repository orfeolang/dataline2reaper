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

function add_tracks (data) -- if necessary, add tracks up to highest # in datafile.
  highest_track = 0
  for i = 1, #data do
    local tr = tonumber (get_track_no (data[i]))
    if tr > highest_track then highest_track = tr end
  end
  
  local prev_tracks = reaper.CountTracks( 0 ) 
  local tracks_to_add = highest_track - prev_tracks
  
  if tracks_to_add > 0 then
    for i = 1,tracks_to_add do
      reaper.InsertTrackAtIndex(i, true)
    end
  end

end

function add_media(track_no, vol_db, pan, path, position)
--note: track and item numbers begin at 0.
  local track = reaper.GetTrack(0, track_no)
  reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0 )
  local vol_log = math.exp(vol_db*0.115129254)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol_log ) 
  reaper.SetMediaTrackInfo_Value(track, "D_PAN", pan ) 
  
  --[[get the number of the item we are going to add. 
  Note that media items are numbered sequentially by order of appearance in the track
  window.
  item_no =(#items on prev tracks) + (#items already on track BEFORE item)
  --]]
  
  media_count = 0 
  --Count all items on previous tracks__
  if track_no > 0 and reaper.CountMediaItems( 0 ) ~= 1 then
    for i = 0,(track_no-1) do
      local current_track = reaper.GetTrack(0, i)
      local media_on_track = reaper.CountTrackMediaItems(current_track) 
      media_count = media_count + media_on_track
    end
  end
  --Count all items on current tracks positioned before current item.--
  local other_itemss = reaper.CountTrackMediaItems (track) - 1
  if not other_items == nil then
    local first_item_no = media_count --address of first item on track
    for i = first_item_no, (first_item_no + other_items - 1) do
      -- (subtract 1 because don't count first item) --
      local item = reaper.GetSelectedMediaItem(0, i)
      if reaper.GetMediaItemInfo_Value(item, "D_POSITION") <= position then
        media_count = media_count + 1
      end
    end
  end
      
  item_no = media_count --(because items start at 0, = media_count)
  msg (item_no.." "..track_no)
  track = reaper.GetTrack(0, track_no)
  reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 1 ) --select track in datafile
  reaper.InsertMedia(path, 0) --insert specified media on the track
  local item = reaper.GetSelectedMediaItem(0, 0) --get address of this item
  msg (item)
  --reaper.SetMediaItemPosition(item, position, refreshUI )
  --reaper.SetMediaItemInfo_Value(item, "D_POSITION", position ) --reposition the media
  --reaper.SetMediaTrackInfo_Value(track, "I_SELECTED", 0 ) --unselect the track
end

function process_file (data, folder)
  add_tracks (data)
  reaper.SelectAllMediaItems(0, false)
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
 
    path = folder.."/"..media
    add_media(track_no-1, vol_db ,pan, path, position)
    msg ("Line "..i.." processed:")
    msg ("track# = "..track_no)
    msg ('Media = '..media)
    msg ("Volume = "..vol_db)
    msg ("Pan = "..pan)
    msg ("Position = "..position.."s\n")
    
    
  end 
 
end

function Main ()
  reaper.ShowConsoleMsg("")
  --retval, file = reaper.GetUserFileNameForRead("data", "Choose data file", "txt" )
  --retval, folder = reaper.JS_Dialog_BrowseForFolder(caption, initialFolder)
  file = "D:/Tempakshawn/Lua Orfeo project/Datafile.txt"
  folder = "D:/Tempakshawn/Lua Orfeo project/media"
  data = read_file (file)
  msg ("number of lines in data file: "..#data)
  process_file (data, folder)
  reaper.UpdateArrange()
end 

--[[to do: 
allow adding more than one media item a single track; prevent errors if tracks in datfile
already contain items.--]]
  
Main()






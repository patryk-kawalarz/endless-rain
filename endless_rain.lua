-- Endless Rain
-- 0.0.1 @sundrugs
-- llllllll.co/t/endlessrain
--
-- Four MIDI LFOs
--
-- E2 : Go to next param 
-- E3 : Change value
--

local SCREEN_FRAMERATE = 15
local LFO_UPDATE_FREQ = 128
local LFO_RESOLUTION = 128 
local CURRENT_ITEM = 0
local TOP_MARGIN = 17

local lfo = {}
local lfo_freqs = {}
local lfo_progress = {}
local lfo_last = {}
local lfo_grow = {}
local lfo_step = {}
local LFO_LENGTH = 4
local LFO_PARAM_LENGTH = 5
local CURRENT_LFO = 0
local CURRENT_LFO_PARAM = 0
local MAX_ITEMS = LFO_LENGTH * LFO_PARAM_LENGTH - 1

local function draw_line(lfo_num) 
  local line_min = lfo[lfo_num][2]
  local line_max = lfo[lfo_num][3]

  if line_max and line_max >0 then
    screen.level(1)
    screen.rect(0, TOP_MARGIN + (lfo_num * 13) + 2, line_min, 4)
    screen.fill()

    screen.level(15)
    screen.rect(line_min, TOP_MARGIN + (lfo_num * 13) + 2, line_max + 2, 4)
    screen.fill()

    screen.level(1)
    screen.rect(line_max + 2, TOP_MARGIN + (lfo_num * 13) + 2, 128, 4)
    screen.fill()
  end
end

local function draw_params() 
  for x=0,(LFO_LENGTH - 1)
  do 
    for y=0,(LFO_PARAM_LENGTH - 1)
    do
      screen.move(4 + (y * 24), TOP_MARGIN + (x * 13)) 

      local val_to_show = lfo[x][y]

      if x == CURRENT_LFO and y == CURRENT_LFO_PARAM then
        screen.level(15)
      else
        screen.level(3)
      end

      if val_to_show then
        screen.text("" .. val_to_show)
      else
        screen.text(".")
      end

      if x == CURRENT_LFO and y == CURRENT_LFO_PARAM then
        screen.move((y * 24), TOP_MARGIN + (x * 13)) 
        screen.text("\u{25B6}")
      end

      screen.level(3)
    end

    draw_line(x)
    
  end
end

local function screen_update()
  if screen_dirty then
    screen_dirty = false
    redraw()
  end
end

local function next_item(delta)
  local new_val = util.round(CURRENT_ITEM + (1 * delta))

  if new_val > MAX_ITEMS then
    CURRENT_ITEM = MAX_ITEMS
  elseif new_val < 0 then
    CURRENT_ITEM = 0
  else
    CURRENT_ITEM = new_val
  end

  CURRENT_LFO = math.floor(CURRENT_ITEM / LFO_PARAM_LENGTH)
  CURRENT_LFO_PARAM = CURRENT_ITEM - (CURRENT_LFO * LFO_PARAM_LENGTH)

  screen_dirty = true
end

local function change_lfo_val(delta)
  local curr_lfo_val = lfo[CURRENT_LFO][CURRENT_LFO_PARAM]
  local new_val = util.round(curr_lfo_val + (delta * 1))
  local max_val = 127
  
  if CURRENT_LFO_PARAM == 0 then
    max_val = 16
  elseif CURRENT_LFO_PARAM == 4 then
    max_val = 3600
  end

  if new_val > max_val then
    lfo[CURRENT_LFO][CURRENT_LFO_PARAM] = max_val
  elseif new_val < 0 then
    lfo[CURRENT_LFO][CURRENT_LFO_PARAM] = 0
  else
    lfo[CURRENT_LFO][CURRENT_LFO_PARAM] = new_val
  end

  screen_dirty = true
end

local function lfo_update()
  for i = 0, LFO_LENGTH do
    local min = lfo[i][2]
    local max = lfo[i][3]
    local time = lfo[i][4]

    if max > min and time > 0 then      
      if lfo_progress[i] == nil then lfo_progress[i] = 0 end
      if lfo_grow[i] == nil then lfo_grow[i] = true end

      lfo_step = (max - min) / (time * LFO_UPDATE_FREQ)

      if lfo_grow[i] then
        lfo_progress[i] = lfo_progress[i] + lfo_step

        if lfo_progress[i] < min then
          lfo_progress[i] = min
        end

        if lfo_progress[i] >= max then 
          lfo_progress[i] = max
          lfo_grow[i] = false
        end
      elseif lfo_grow[i] == false then
        lfo_progress[i] = lfo_progress[i] - lfo_step

        if lfo_progress[i] < min then
          lfo_progress[i] = min
          lfo_grow[i] = true
        end
      end

      if(lfo_last ~= util.round(lfo_progress[i])) then 
        screen_dirty = true 
        midi_out_device:cc(lfo[i][1], util.round(lfo_progress[i]), lfo[i][0])
      end

      lfo_last = util.round(lfo_progress[i])
    end
  end
end


function init()
  midi_out_device = midi.connect(1)

  for i=CURRENT_ITEM,MAX_ITEMS 
  do 
    lfo[i] = {} 
    for x = 0,LFO_PARAM_LENGTH do 
      lfo[i][x] = 0 
      lfo[i][3] = 127
    end
  end

  lfo_update()

  metro.init(lfo_update, 1 / LFO_UPDATE_FREQ):start()
  metro.init(screen_update, 1 / SCREEN_FRAMERATE):start()  
end

local function draw_header()
  screen.level(1)
  screen.font_size(8)
  screen.font_face(1)
  screen.move(3, 5)
  screen.text("CH")
  screen.move(28, 5)
  screen.text("CC")
  screen.move(52, 5)
  screen.text("Min")
  screen.move(76, 5)
  screen.text("Max")
  screen.move(100, 5)
  screen.text("Time(s)")
  screen.level(3)
end

function redraw()
  screen.clear()
  screen.level(3)
  
  draw_header()

  screen.move(1, 12)
  draw_params()

  screen.level(0)
  screen.fill()

  for i = 0, LFO_LENGTH do
    if lfo_progress[i] then
      local row_y = TOP_MARGIN + (i * 13) + 3      
      screen.rect(util.round(lfo_progress[i]), row_y, 2, 2)
      screen.fill()
    end
  end

  screen.fill()
  screen.update()
end


-- Encoder input
function enc(n, delta)
  if n == 2 then
    next_item(delta)
  elseif n == 3 then
    change_lfo_val(delta)
  end
end


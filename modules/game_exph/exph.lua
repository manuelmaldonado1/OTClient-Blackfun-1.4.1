exphWindow = nil
exphButton = nil

function init()
  connect(LocalPlayer, {
	onExperienceChange = onExperienceChange
  })
  
  connect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })
  
  exphWindow = g_ui.loadUI('exph', modules.game_interface.getRightPanel())
  exphButton =  modules.client_topmenu.addRightGameToggleButton('exphButton', tr('Experience Stats'), '/images/topbuttons/exph', toggle)
  exphButton:setOn(exphWindow:isVisible())
  g_keyboard.bindKeyDown('Ctrl+H', toggle)

  --refresh()
  exphWindow:setup()
  
  startFreshExpHWindow()
  
end

--//########## REAL MAGIC ##########//--
expHUpdateEvent = 0
expHVar = {
	originalExpAmount = 0,
	lastExpAmount = 0,
	historyIndex = 0,
	sessionStart = 0,
}
expHistory = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

function startFreshExpHWindow()
	resetExpH()
	if expHUpdateEvent ~= 0 then
		removeEvent(expHUpdateEvent)
	end
	updateExpHWindow()
end

function updateExpHWindow()
	expHUpdateEvent = scheduleEvent(updateExpHWindow, 5000)
	local player = g_game.getLocalPlayer()
	if not player then return end --Wont go future if there's no player
  
	local currentExp = player:getExperience()
	if expHVar.lastExpAmount == 0 then
		expHVar.lastExpAmount = currentExp
	end
	if expHVar.originalExpAmount == 0 then
		expHVar.originalExpAmount = currentExp
	end
	local expDiff = math.floor(currentExp-expHVar.lastExpAmount)
	updateExpHistory(expDiff)
	expHVar.lastExpAmount = currentExp
	
	local _expGained = math.floor(currentExp-expHVar.originalExpAmount)
	
	local _expHistory = getExpGained()
	if _expHistory <= 0 and (expHVar.sessionStart > 0 or _expGained > 0) then --No Exp gained last 5 min, lets stop
		resetExpH()
		return false
	end
	
	local _session = 0
	local _start = expHVar.sessionStart
	if _start > 0 and _expGained > 0 then
		_session = math.floor(g_clock.seconds()-_start)
	end
	
	local string_session = getTimeFormat(_session)
	local string_expGain = number_format(_expGained)
	-----------------------------------------------------
	local _getExpHour = getExpPerHour(_expHistory, _session)
	local string_expph = number_format(_getExpHour)
	-----------------------------------------------------

	local _lvl = player:getLevel()
	local _nextLevelExp = getExperienceForLevel(_lvl+1)
	local _expToNextLevel = math.floor(_nextLevelExp-currentExp)
	
	local string_exptolevel = number_format(_expToNextLevel)
	
	local _timeToNextLevel = getNextLevelTime(_expToNextLevel, _getExpHour)
	local string_timetolevel = getTimeFormat(_timeToNextLevel)
	
	setSkillValue('session',		string_session)
	setSkillValue('expph',			string_expph)
	setSkillValue('expgained',		string_expGain)
	setSkillValue('exptolevel',		string_exptolevel)
	setSkillValue('timetolevel',	string_timetolevel)
end

function getNextLevelTime(_expToNextLevel, _getExpHour)
	if _getExpHour <= 0 then
		return 0
	end
	local _expperSec = (_getExpHour/3600)
	local _secToNextLevel = math.ceil(_expToNextLevel/_expperSec)
	return _secToNextLevel
end

function getExperienceForLevel(lv)
	lv = lv - 1
	return ((50 * lv * lv * lv) - (150 * lv * lv) + (400 * lv)) / 3
end

function getNumber(msg)
	b, e = string.find(msg, "%d+")
	
	if b == nil or e == nil then
		count = 0
	else
		count = tonumber(string.sub(msg, b, e))
	end	
	return count
end

function number_format(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function getExpPerHour(_expHistory, _session)
	if _session < 10 then
		_session = 10
	elseif _session > 300 then
		_session = 300
	end
	
	local _expSec = _expHistory/_session
	local _expH = math.floor(_expSec*3600)
	if _expH <= 0 then
		_expH = 0
	end
	return getNumber(_expH)
end

function getTimeFormat(_secs)
	local _hour = math.floor(_secs/3600)
	_secs = math.floor(_secs-(_hour*3600))
	local _min = math.floor(_secs/60)
	
	if _hour <= 0 then
		_hour = "00"
	elseif _hour <= 9 then
		_hour = "0".. _hour
	end
	if _min <= 0 then
		_min = "00"
	elseif _min <= 9 then
		_min = "0".. _min
	end
	return _hour ..":".. _min
end

function updateExpHistory(dif)
	if dif > 0 then
		if expHVar.sessionStart == 0 then
			expHVar.sessionStart = g_clock.seconds()
		end
	end
	
	local _index = expHVar.historyIndex
	expHistory[_index] = dif
	_index = _index+1
	if _index < 0 or _index > 59 then
		_index = 0
	end
	expHVar.historyIndex = _index
end

function getExpGained()
	local totalExp = 0
	for key,value in pairs(expHistory) do
		totalExp = totalExp+value
	end
	return totalExp
end

function resetExpH()
	expHVar.originalExpAmount = 0
	expHVar.lastExpAmount = 0
	expHVar.historyIndex = 0
	expHVar.sessionStart = 0

	setSkillValue('session',		"00:00")
	setSkillValue('expph',			0)			setSkillColor('expph',			'#1eff00')
	setSkillValue('expgained',		0)			setSkillColor('expgained',		'#d8ff00')
	setSkillValue('exptolevel',		0)			setSkillColor('exptolevel',		'#ff9600')
	setSkillValue('timetolevel',	"00:00")	setSkillColor('timetolevel',	'#ff6767')
	
	for key,value in pairs(expHistory) do
		value = 0
	end
end
--//########## REAL MAGIC ##########//--

function terminate()
  disconnect(LocalPlayer, {
	onExperienceChange = onExperienceChange
  })
  disconnect(g_game, {
    onGameStart = refresh,
    onGameEnd = offline
  })

  g_keyboard.unbindKeyDown('Ctrl+H')
  exphWindow:destroy()
  exphButton:destroy()
end

function expForLevel(level)
  return math.floor((50*level*level*level)/3 - 100*level*level + (850*level)/3 - 200)
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel+1) - currentExp
end

function resetSkillColor(id)
  local skill = exphWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setColor('#bbbbbb')
end

function setSkillValue(id, value)
  local skill = exphWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setText(value)
end

function setSkillColor(id, value)
  local skill = exphWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setColor(value)
end

function setSkillTooltip(id, value)
  local skill = exphWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('value')
  widget:setTooltip(value)
end

function setSkillPercent(id, percent, tooltip)
  local skill = exphWindow:recursiveGetChildById(id)
  local widget = skill:getChildById('percent')
  widget:setPercent(math.floor(percent))

  if tooltip then
    widget:setTooltip(tooltip)
  end
end

function comma_value(n)
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function onExperienceChange(localPlayer, currentExperience, print_s)
	--Not entierly sure if this is the event function whenever you gain exp ingame
end

function refresh()
	local player = g_game.getLocalPlayer()
	if not player then return end

	resetExpH()

	local contentsPanel = exphWindow:getChildById('contentsPanel')
	exphWindow:setContentMinimumHeight(44)
	exphWindow:setContentMaximumHeight(87)

	exphButton:setOn(exphWindow:isVisible())
end

function offline()
	startFreshExpHWindow()
end

function toggle()
  exphButton:setOn(not exphWindow:isVisible())
  if exphWindow:isVisible() then
      exphWindow:close()
  else
	  exphWindow:open()
  end
end

function onMiniWindowClose()
    exphButton:setOn(false)
end

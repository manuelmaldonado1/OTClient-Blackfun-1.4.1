local walkEvent = nil
local stop = false
local isAttacking = false
local isFollowing = false
local looting = false
local currentTargetPositionId = 1
local waypoints = {}
local targets = {}
local loot = {}
local autowalkTargetPosition = waypoints[currentTargetPositionId]
local atkLoopId = nil
local lootLoopId = nil
local atkSpellLoopId = nil
local atkRuneLoopId = nil
local healingLoopId = nil
local manaLoopId = nil
local hasteLoopId = nil
local hasLured = false
local shieldLoopId = nil
local player = nil
local currTarget = nil
local offset = 3
local healingItem 
local manaItem
local lurePos = nil
local lurePath = nil
local lurePathResult = nil
local lureCurrStep = 1
local healingCooldown = os.time()
local manaCooldown = os.time()

function init()
	poxBotWindow = g_ui.displayUI('poxbot')
	waypointList = poxBotWindow:recursiveGetChildById('waypoints')
	targetList = poxBotWindow:recursiveGetChildById('targets')
	itemList = poxBotWindow:recursiveGetChildById('lootitems')
	atkButton = poxBotWindow:recursiveGetChildById('autoAttack')
	healButton = poxBotWindow:recursiveGetChildById('AutoHeal')
	lootButton = poxBotWindow:recursiveGetChildById('autoLoot')
	walkButton = poxBotWindow:recursiveGetChildById('walking')
	atkSpellButton = poxBotWindow:recursiveGetChildById('AtkSpell')
	atkRuneButton = poxBotWindow:recursiveGetChildById('AtkRune')
	manaTrainButton = poxBotWindow:recursiveGetChildById('ManaTrain')
	hasteButton = poxBotWindow:recursiveGetChildById('AutoHaste')
	manaShieldButton = poxBotWindow:recursiveGetChildById('AutoManaShield')
	poxBotWindow:hide()
	g_keyboard.bindKeyDown('Ctrl+Alt+B', toggle)
	poxBotWindow:recursiveGetChildById("offsetCenter"):setChecked(true)
	scheduleEvent(setPlayer, 1500)
	connect(g_game, {
					onGameStart = logIn,
					onGameEnd = terminate
					})
	
	disconnect(g_game, { 
						onGameStart = logIn,
						onGameEnd = terminate
						})
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function logIn()

end

function setPlayer()
    if not g_game.isOnline() then
		scheduleEvent(setPlayer,1500)
        return
	end
	player = g_game.getLocalPlayer()
end


function terminate()
	g_keyboard.unbindKeyDown('Ctrl+Alt+B', toggle)
	poxBotWindow:destroy()
end

function hide()
	poxBotWindow:hide()
end

function show()
	poxBotWindow:show()
	poxBotWindow:raise()
	poxBotWindow:focus()
end

function toggle()
	if poxBotWindow:isVisible() then
		hide()
	else
		show()
	end
end
function selectPanel(key)
	if key == "cavebot" then
		poxBotWindow:recursiveGetChildById('cavebot'):setVisible(true)
		poxBotWindow:recursiveGetChildById('targeting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('looting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('healing'):setVisible(false)
		poxBotWindow:recursiveGetChildById('tools'):setVisible(false)
	elseif key == "targeting" then
		poxBotWindow:recursiveGetChildById('cavebot'):setVisible(false)
		poxBotWindow:recursiveGetChildById('targeting'):setVisible(true)
		poxBotWindow:recursiveGetChildById('looting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('healing'):setVisible(false)
		poxBotWindow:recursiveGetChildById('tools'):setVisible(false)
	elseif key == "healing" then
		poxBotWindow:recursiveGetChildById('cavebot'):setVisible(false)
		poxBotWindow:recursiveGetChildById('targeting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('looting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('healing'):setVisible(true)
		poxBotWindow:recursiveGetChildById('tools'):setVisible(false)
	elseif key == "tools" then
		poxBotWindow:recursiveGetChildById('cavebot'):setVisible(false)
		poxBotWindow:recursiveGetChildById('targeting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('looting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('healing'):setVisible(false)
		poxBotWindow:recursiveGetChildById('tools'):setVisible(true)
	elseif key == "looting" then
		poxBotWindow:recursiveGetChildById('cavebot'):setVisible(false)
		poxBotWindow:recursiveGetChildById('targeting'):setVisible(false)
		poxBotWindow:recursiveGetChildById('looting'):setVisible(true)
		poxBotWindow:recursiveGetChildById('healing'):setVisible(false)
		poxBotWindow:recursiveGetChildById('tools'):setVisible(false)
	end
end

function toggleOffset(key)
	local bts = {"offsetNorth","offsetSouth","offsetCenter","offsetWest","offsetEast"}
	local bt = poxBotWindow:recursiveGetChildById(key)
	local offsets = 1
	if bt == nil then
		return
	end
	if bt:isChecked() then
		for _,it in pairs(bts) do
			if key ~= it then
				poxBotWindow:recursiveGetChildById(it):setChecked(false)
				offsets = offsets + 1
			else
				offset = offsets
			end
		end
	else
		for _,it in pairs(bts) do
			if poxBotWindow:recursiveGetChildById(it):isChecked() then
				break
			end
			offsets = offsets + 1
		end
	end
	if offsets == 6 then
		poxBotWindow:recursiveGetChildById("offsetCenter"):setChecked(true)
		offset = 3
	end
end

function toggleLoop(key)
	--maybe remove some looops, for example healing could be done through events
	local bts = {
		autoAttack = {atkLoop, atkLoopId},
		autoLoot = {lootLoop, lootLoopId},
		walking = {walkToTarget, walkEvent},
		AutoHeal = {healingLoop, healingLoopId},
		AtkSpell = {atkSpellLoop, atkSpellLoopId},
		AtkRune = {atkRuneLoop, atkRuneLoopId},
		ManaTrain = {manaTrainLoop, manaLoopId},
		AutoHaste = {hasteLoop, hasteLoopId},
		AutoManaShield = {shieldLoop, shieldLoopId},
	}

	local btn = poxBotWindow:recursiveGetChildById(key)
	local bt = bts[btn:getId()]
	if (btn:isChecked()) then
		if (bt) then
			bt[1]()
		end
	else
		if (bt) then
			removeEvent(bt[2])
		end
	end
end

function healingLoop()
	local first = {name = poxBotWindow:recursiveGetChildById('Heal1Text'):getText(), pc = tonumber(poxBotWindow:recursiveGetChildById('Heal1Pc'):getText())}
	local second = {name = poxBotWindow:recursiveGetChildById('Heal2Text'):getText(), pc = tonumber(poxBotWindow:recursiveGetChildById('Heal2Pc'):getText())}
	local third = {name = poxBotWindow:recursiveGetChildById('Heal3Text'):getText(), pc = tonumber(poxBotWindow:recursiveGetChildById('Heal3Pc'):getText())}
	local mana = {checked = getBoolean("Mana1"), pc = tonumber(poxBotWindow:recursiveGetChildById('Mana1Pc'):getText())}
	
	if player:getHealth() ~= -1 and healingCooldown < os.time() then
			if first.name and player:getHealth() <= (player:getMaxHealth() * (first.pc/100)) and player:getHealth() >= (player:getMaxHealth() * (second.pc/100)) then
				g_game.talk(first.name)
				healingCooldown = os.time() + 1
			elseif second.name and player:getHealth() <= player:getMaxHealth() * (second.pc/100) and player:getHealth() >= player:getMaxHealth() * (third.pc/100) then
				g_game.talk(second.name)
				healingCooldown = os.time() + 1
			elseif third.name and player:getHealth() <= player:getMaxHealth() * (third.pc/100) then
				g_game.talk(third.name)
				healingCooldown = os.time() + 1
			end
	end
	
	if player:getMana() ~= -1 then
		if poxBotWindow:recursiveGetChildById("Mana1"):isChecked() and manaCooldown < os.time() then
			print("test")
			g_game.useInventoryItemWithSelf(2874,player)
			manaCooldown = os.time() + 1
			
		end
	end
	
	healingLoopId = scheduleEvent(healingLoop, 200)
end

function autoHealPotion()
	healingItem = healthItemButton:isChecked()
	if (healingItem and itemHealingLoopId == nil) then
		itemHealingLoop()
	end
	if (not manaItem and not healingItem) then
		removeEvent(itemHealingLoopId)
		itemHealingLoopId = nil
	end
end

function autoManaPotion()
	manaItem = manaRestoreButton:isChecked()
	if (manaItem and itemHealingLoopId == nil) then
		itemHealingLoop()
	end
	if (not manaItem and not healingItem) then
		removeEvent(itemHealingLoopId)
		itemHealingLoopId = nil
	end
end

function toggle()
	if poxBotWindow:isVisible() then
		hide()
	else
		show()
	end
end

local function getDistanceBetween(p1, p2)
    return math.max(math.abs(p1.x - p2.x), math.abs(p1.y - p2.y))
end

function Player.canAttack(self)
    return not self:hasState(16384) and not g_game.isAttacking()
end

function Creature:canReach(creature)
	--function from candybot
	if not creature then
		return false
	end
	local myPos = self:getPosition()
	local otherPos = creature:getPosition()

	local neighbours = {
		{x = 0, y = -1, z = 0},
		{x = -1, y = -1, z = 0},
		{x = -1, y = 0, z = 0},
		{x = -1, y = 1, z = 0},
		{x = 0, y = 1, z = 0},
		{x = 1, y = 1, z = 0},
		{x = 1, y = 0, z = 0},
		{x = 1, y = -1, z = 0}
	}

	for k,v in pairs(neighbours) do
	local checkPos = {x = myPos.x + v.x, y = myPos.y + v.y, z = myPos.z + v.z}
	if postostring(otherPos) == postostring(checkPos) then
		return true
	end

	local steps, result = g_map.findPath(otherPos, checkPos, 40000, 0)
		if result == PathFindResults.Ok then
			return true
		end
	end
	return false
end

function atkLoop() 
		if g_game.isAttacking() and poxBotWindow:recursiveGetChildById('LureTarget'):isChecked() and lurePos ~= nil then
			if lurePath == nil then
				lurePath, lurePathResult = g_map.findPath(player:getPosition(), lurePos, 5000, 0)
				lureCurrStep = 1
			end
			local target = g_game.getAttackingCreature()
			if getDistanceBetween(player:getPosition(), target:getPosition()) <= 4 and player:getPosition() ~= lurePos then
				g_game.walk(lurePath[lureCurrStep])
				lureCurrStep = lureCurrStep+1
			end
			atkLoopId = scheduleEvent(atkLoop, 100)
			return
		end
		if g_game.isAttacking() and poxBotWindow:recursiveGetChildById('KeepDistance'):isChecked() then
			local target = g_game.getAttackingCreature()
			local keepPosition = player:getPosition()
			if getDistanceBetween(player:getPosition(), target:getPosition()) <= 4 then
				print(target:getDirection())
				if target:getDirection() == 0 then
					keepPosition.y = keepPosition.y - 1
				elseif target:getDirection() == 1 then
					keepPosition.x = keepPosition.x + 1
				elseif target:getDirection() == 2 then
					keepPosition.y = keepPosition.y + 1
				elseif target:getDirection() == 1 then
					keepPosition.x = keepPosition.x - 1
				end
				step, results = g_map.findPath(player:getPosition(), keepPosition, 100, 0)
				if results == PathFindResults.Ok then
					g_game.walk(step[1])
				end
			end
			atkLoopId = scheduleEvent(atkLoop, 100)
			return
		end
	if(player:canAttack()) then
		local pPos = player:getPosition()
		if pPos then
			local creatures = g_map.getSpectators(pPos, false)
			for _, creature in ipairs(creatures) do
				cPos = creature:getPosition()
				if table.contains(targets,creature:getName():lower()) and getDistanceBetween(pPos, cPos) <= 5 then
					g_game.stop()
					currTarget = creature:getId()
					g_game.attack(creature)
					atkLoopId = scheduleEvent(atkLoop, 200)
					return
				end
			end
		end
	end
	atkLoopId = scheduleEvent(atkLoop, 200)
end

function addWaypoint(waypointType)
	local label = g_ui.createWidget('Waypoint', waypointList)
	local pos = player:getPosition()
	if offset == 1 then
		pos.y = pos.y - 1
	elseif offset == 2 then
		pos.y = pos.y + 1
	elseif offset == 4 then
		pos.x = pos.x - 1
	elseif offset == 5 then
		pos.x = pos.x + 1
	end
	label:setText(waypointType .. " (".. pos.x .. "," .. pos.y .. "," .. pos.z .. ")")
	local waypointTable = {
		option = waypointType,
		position = pos
	}
	table.insert(waypoints, waypointTable)
end

function addTarget()
	local label = g_ui.createWidget('Waypoint', targetList)
	local name = poxBotWindow:recursiveGetChildById('TargetText'):getText():lower()
	label:setText(name)
	table.insert(targets, name)
end

function addLoot()
	local label = g_ui.createWidget('Waypoint', itemList)
	local name = poxBotWindow:recursiveGetChildById('lootText'):getText():lower()
	label:setText(name)
	table.insert(loot, name)
end

function walkToTarget()
	autowalkTargetPosition = waypoints[currentTargetPositionId]
	lureCurrStep = 1
	lurePath = nil
	lurePathResult = nil
	local playerPos = player:getPosition()
    if not g_game.isOnline() then
		walkEvent = scheduleEvent(walkToTarget, 500)
        return
	end
	if looting then
		walkEvent = scheduleEvent(walkToTarget, 1500)
	end
	if g_game.isAttacking() or isFollowing then
		walkEvent = scheduleEvent(walkToTarget, 500)
        return
	end
	
	if (playerPos and autowalkTargetPosition) then
		if autowalkTargetPosition.option == "Shovel" then
			if (getDistanceBetween(playerPos, autowalkTargetPosition.position) <= 5) then
				for _,it in pairs(g_map.getTile(autowalkTargetPosition.position):getItems()) do
					g_game.useInventoryItemWith(3457,it)
				end
			end
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
			walkEvent = scheduleEvent(walkToTarget, 1500)
			return
		elseif autowalkTargetPosition.option == "Rope" then
			if (getDistanceBetween(playerPos, autowalkTargetPosition.position) <= 5) then
				for _,it in pairs(g_map.getTile(autowalkTargetPosition.position):getItems()) do
					g_game.useInventoryItemWith(3003,it)
					if player:getPosition().z ~= autowalkTargetPosition.position.z then
						break
					end
				end
			end
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
			walkEvent = scheduleEvent(walkToTarget, 1500)
			return
		elseif autowalkTargetPosition.option == "Use" then
			if (getDistanceBetween(playerPos, autowalkTargetPosition.position) <= 5) then
				for _,it in pairs(g_map.getTile(autowalkTargetPosition.position):getItems()) do
					g_game.use(it)
					if player:getPosition().z ~= autowalkTargetPosition.position.z then
						break
					end
				end
			end
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
			walkEvent = scheduleEvent(walkToTarget, 1500)
			return
		elseif autowalkTargetPosition.option == "Lure" then
			lurePos = autowalkTargetPosition.position
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
			walkEvent = scheduleEvent(walkToTarget, 100)
			return
		elseif autowalkTargetPosition.option == "Wait" then
			walkEvent = scheduleEvent(walkToTarget, 1500)
			return
		end
		if (getDistanceBetween(playerPos, autowalkTargetPosition.position) >= 150) then
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
			walkEvent = scheduleEvent(walkToTarget, 1500)
			return 
		end
	end

	if not autowalkTargetPosition then
		currentTargetPositionId = currentTargetPositionId + 1
		if (currentTargetPositionId > #waypoints) then
			currentTargetPositionId = 1
		end
		walkEvent = scheduleEvent(walkToTarget, 100)
		return
	end
	if playerPos == autowalkTargetPosition.position then
		currentTargetPositionId = currentTargetPositionId + 1
		if (currentTargetPositionId > #waypoints) then
			currentTargetPositionId = 1
		end
	end
	if not player:isWalking() then
		steps, result = g_map.findPath(g_game.getLocalPlayer():getPosition(), autowalkTargetPosition.position, 5000, 0)
		if result == PathFindResults.Ok then
			g_game.autoWalk(steps, true)
		elseif result == PathFindResults.Position then
			currentTargetPositionId = currentTargetPositionId + 1
			if (currentTargetPositionId > #waypoints) then
				currentTargetPositionId = 1
			end
		else
			steps, result = g_map.findPath(g_game.getLocalPlayer():getPosition(), autowalkTargetPosition.position, 25000, 1)
			if result == PathFindResults.Ok then
				g_game.autoWalk(steps, true)
			else
				currentTargetPositionId = currentTargetPositionId + 1
			end
		end
	end

    walkEvent = scheduleEvent(walkToTarget, math.max(100, g_game.getLocalPlayer():getStepTicksLeft()))
end

function getBoolean(key)
	if poxBotWindow:recursiveGetChildById(key):isChecked() then
		return "true"
	end
	return "false"
end

function saveWaypoints() 
	local saveText = '{\n'
	saveText = saveText .. "cavebot = {\n"
	for _,v in pairs(waypoints) do
		saveText = saveText .. '{option = "'.. v.option ..'", position = {x = '.. v.position.x ..', y = ' .. v.position.y .. ', z = ' .. v.position.z .. '}},\n'
	end
	saveText = saveText .. '},\n'
	saveText = saveText .. "targeting = {\n"
	saveText = saveText .. "creatures = {\n"
	for _,v in pairs(targets) do
		saveText = saveText .. '{name = "'.. v ..'"},\n'
	end
	saveText = saveText .. '},\n'
	saveText = saveText .. "settings = {\n"
	saveText = saveText .. "useRune = ".. getBoolean("AtkSpell") ..","
	saveText = saveText .. "rune1 = '".. poxBotWindow:recursiveGetChildById("AtkSpellText"):getText() .."',"
	saveText = saveText .. "rune2 = '".. poxBotWindow:recursiveGetChildById("AtkRuneName"):getText() .."',"
	saveText = saveText .. "aoeAmount = '".. poxBotWindow:recursiveGetChildById("AtkRuneAmount"):getText() .."',"
	saveText = saveText .. "keepDistance = ".. getBoolean("KeepDistance") ..","
	saveText = saveText .. "lureTarget = ".. getBoolean("LureTarget") .."\n"
	saveText = saveText .. '}\n'
	saveText = saveText .. '},\n'
	saveText = saveText .. "looting = {\n"
	for _,v in pairs(loot) do
		saveText = saveText .. '"'.. v ..'",'
	end
	saveText = saveText .. '\n},\n'
	saveText = saveText .. "healing = {\n"
	saveText = saveText .. "heal1 = '".. poxBotWindow:recursiveGetChildById("Heal1Text"):getText() .."', heal1pc = '".. poxBotWindow:recursiveGetChildById("Heal1Pc"):getText() .."',"
	saveText = saveText .. "heal2 = '".. poxBotWindow:recursiveGetChildById("Heal2Text"):getText() .."', heal2pc = '".. poxBotWindow:recursiveGetChildById("Heal2Pc"):getText() .."',"
	saveText = saveText .. "heal3 = '".. poxBotWindow:recursiveGetChildById("Heal3Text"):getText() .."', heal3pc = '".. poxBotWindow:recursiveGetChildById("Heal3Pc"):getText() .."',"
	saveText = saveText .. '}\n'
	saveText = saveText .. '}'

	local file = io.open('modules/game_poxbot/savedfiles/'.. poxBotWindow:recursiveGetChildById('WptName'):getText() ..'.lua', 'w')
	file:write(saveText)
	file:close()
end

function loadWaypoints() 
	local f = io.open('modules/game_poxbot/savedfiles/'.. poxBotWindow:recursiveGetChildById('WptName'):getText() ..'.lua', "rb")
	if f then

		local content = f:read("*all")
		f:close()

		clearWaypoints()
		
		local loadedData = loadstring("return " .. content)()
		waypoints = loadedData.cavebot
		for _,v in ipairs(waypoints) do
			local labelt = g_ui.createWidget('Waypoint', waypointList)
			labelt:setText(v.option .. " (".. v.position.x .. "," .. v.position.y .. "," .. v.position.z .. ")")
		end
		
		clearTargets()
		targets = loadedData.targeting.creatures
		for _,v in ipairs(targets) do
			local labelt = g_ui.createWidget('Waypoint', targetList)
			labelt:setText(v.name)
		end
		
		clearItems()
		loot = loadedData.looting
		for _,v in ipairs(loot) do
			local labelt = g_ui.createWidget('Waypoint', itemList)
			labelt:setText(v.name)
		end
		
		poxBotWindow:recursiveGetChildById("Heal1Text"):setText(loadedData.healing.heal1)
		poxBotWindow:recursiveGetChildById("Heal1Pc"):setText(loadedData.healing.heal1pc)
		poxBotWindow:recursiveGetChildById("Heal2Text"):setText(loadedData.healing.heal2)
		poxBotWindow:recursiveGetChildById("Heal2Pc"):setText(loadedData.healing.heal2pc)
		poxBotWindow:recursiveGetChildById("Heal3Text"):setText(loadedData.healing.heal3)
		poxBotWindow:recursiveGetChildById("Heal3Pc"):setText(loadedData.healing.heal3pc)
	end
end

function clearWaypoints()
	waypoints = {}
	autowalkTargetPosition = currentTargetPositionId
	autowalkTargetPosition = waypoints[currentTargetPositionId]
	clearLabels()
	walkButton:setChecked(false)
end

function clearLabels()
	while waypointList:getChildCount() > 0 do
		local child = waypointList:getLastChild()
		waypointList:destroyChildren(child)
	end
end

function clearTargets()
	targets = {}
	clearLabels2()
	atkButton:setChecked(false)
end

function clearLabels2()
	while targetList:getChildCount() > 0 do
		local child = targetList:getLastChild()
		targetList:destroyChildren(child)
	end
end

function clearItems()
	items = {}
	clearLabels3()
	lootButton:setChecked(false)
end

function clearLabels3()
	while itemList:getChildCount() > 0 do
		local child = itemList:getLastChild()
		itemList:destroyChildren(child)
	end
end

function itemHealingLoop()
	-- Prioritize healing item instead of mana
	if healingItem then
		local hpItemPercentage = tonumber(poxBotWindow.HealItemPercent:getText())
		local hpItemId = tonumber(poxBotWindow.HealItem:getText())
		if (player:getHealth() <= (player:getMaxHealth() * (hpItemPercentage/100))) then
			g_game.useInventoryItemWith(hpItemId, player)
			-- maybe don't try using mana after healing item?
		end
	end
	if manaItem then
		local manaItemPercentage = tonumber(poxBotWindow.ManaPercent:getText())
		local manaItemId = tonumber(poxBotWindow.ManaItem:getText())
		if (player:getMana() <= (player:getMaxMana() * (manaItemPercentage/100))) then
			g_game.useInventoryItemWith(manaItemId, player)
		end
	end
	itemHealingLoopId = scheduleEvent(itemHealingLoop, 250)
end

local lootList = {}
local getLootContainersId = nil
local corpseOpen = false
local itemsToLoot = {}

function lootLoop()
--[[
	if g_game.isAttacking() then
		local target = g_game.getAttackingCreature()
		if not table.contains(lootList,target:getPosition()) then
			print("added tile")
			lootList[#lootList + 1] = target:getPosition()
		end
		lootLoopId = scheduleEvent(lootLoop, 300)
		looting = true
		return
	end
	if looting then
		print("trying to loot")
		if itemsToLoot[1] then
			g_game.move(itemsToLoot[1], g_game.getContainers()[0]:getSlotPosition(0), itemsToLoot[1]:getCount())
			table.remove(itemsToLoot, 1)
			if not itemsToLoot[1] then
				g_game.open(lootList[1].container)
				corpseOpen = false
				itemsToLoot = {}
				table.remove(lootList, 1)
			end
			lootLoopId = scheduleEvent(lootLoop, 300)
			return
		end
		print(#lootList)
		if lootList[1] then
			if not player:isWalking() and getDistanceBetween(player:getPosition(), lootList[1]) > 1 then
				steps, result = g_map.findPath(g_game.getLocalPlayer():getPosition(), lootList[1], 1000, 1)

				if result == PathFindResults.Ok then
					g_game.autoWalk(steps, true)
				end
			end
			
			if player:isWalking() then
				lootLoopId = scheduleEvent(lootLoop, 1000)
			end
			
			if getDistanceBetween(player:getPosition(), lootList[1]) <= 1 then
				if not corpseOpen then
					for _,it in pairs(g_map.getTile(lootList[1]):getItems()) do
						g_game.open(it)
					end
					--corpseOpen = true
					lootLoopId = scheduleEvent(lootLoop, 500)
				elseif corpseOpen then
					for slot,it in ipairs(g_game.getContainers()[#g_game.getContainers()]:getItems()) do
						--if table.contains(loot,tostring(it:getId())) then
							print("add loot")
							table.insert(itemsToLoot, it)
						--end
					end
					if #itemsToLoot >= 1 then
						lootLoopId = scheduleEvent(lootLoop, 300)
						return
					end
					g_game.open(lootList[1].container)
					corpseOpen = false
					table.remove(lootList, 1)
				end
			end
			if result == 1 and not corpseOpen then
				g_game.open(lootList[1].container)
				corpseOpen = true
				lootLoopId = scheduleEvent(lootLoop, 1000)
				return
			end
			if corpseOpen then
				for slot,it in ipairs(g_game.getContainers()[#g_game.getContainers()]:getItems()) do
					print(it:getId())
					if table.contains(loot,tostring(it:getId())) then
						print("add loot")
						table.insert(itemsToLoot, it)
					end
				end
				if #itemsToLoot >= 1 then
					lootLoopId = scheduleEvent(lootLoop, 300)
					return
				end
				g_game.open(lootList[1].container)
				corpseOpen = false
				table.remove(lootList, 1)
			end
		else
			looting = false
		end
	end
	lootLoopId = scheduleEvent(lootLoop, 100)]]
end

local lastTarget = nil
local lastTargetLocation = nil

function getLootContainers()
	if getBoolean("autoLoot") == "false" then
		getLootContainersId = nil
		corpseOpen = false
		looting = false
		lastTarget = nil
		lastTargetLocation = nil
		lootList = {}
		return
	end
	
	local creature = g_game.getAttackingCreature()
	if not creature then
		if lastTarget == nil then
			scheduleEvent(getLootContainers, 50)
			return
		end
	end
	if lastTarget == nil and creature then
		lastTarget = creature
	else
		creature = lastTarget
	end
	if g_game.getAttackingCreature() then
		lastTargetLocation = creature:getPosition()
	end
	local pos = player:getPosition()

    local tile = g_map.getTile(lastTargetLocation)
    if not tile then 
		scheduleEvent(getLootContainers, 50)
		return
	end
    local container = tile:getTopUseThing()
    if not container or not container:isContainer() then
		scheduleEvent(getLootContainers, 50)
		return
	end
    if not g_map.findPath(player:getPosition(), lastTargetLocation, 6, 0) then
		scheduleEvent(getLootContainers, 50)
		return 
	end
    table.insert(lootList, {pos=lastTargetLocation, container=container, added=now, tries=0})
	lastTarget = nil
	lastTargetLocation = nil
	
	scheduleEvent(getLootContainers, 300)
end

function healingSpellLoop()
	local healingSpellPercentage = tonumber(poxBotWindow:recursiveGetChildById('HealthSpellPercent'):getText())
	local healSpell = poxBotWindow.HealSpellText:getText()
	if (not player) then
		spellHealingLoopId = scheduleEvent(healingSpellLoop, 502)
	end
	if (player:getHealth() <= (player:getMaxHealth() * (healingSpellPercentage/100))) then
		g_game.talk(healSpell)
	end
	spellHealingLoopId = scheduleEvent(healingSpellLoop, 502)
end

function manaTrainLoop()
	local manaTrainPercentage = tonumber(poxBotWindow:recursiveGetChildById('ManaTrainPercent'):getText())
	local manaSpell = poxBotWindow:recursiveGetChildById('ManaSpellText'):getText()
	if (not player) then
		manaLoopId = scheduleEvent(manaTrainLoop, 1000)
	end
	if (player:getMana() >= (player:getMaxMana() * (manaTrainPercentage/100))) then
		g_game.talk(manaSpell)
	end
	manaLoopId = scheduleEvent(manaTrainLoop, 1000)
end

function hasteLoop()
	local hasteSpell = poxBotWindow:recursiveGetChildById('HasteText'):getText()
	if (not player) then
		hasteLoopId = scheduleEvent(hasteLoop, 1000)
	end
	if (player:getHealth() >= (player:getMaxHealth() * (70/100))) then -- only cast when healthy
		if (not player:hasState(PlayerStates.Haste, player:getStates())) then
			g_game.talk(hasteSpell)
		end
	end
	hasteLoopId = scheduleEvent(hasteLoop, 1000)
end

function shieldLoop()
	if (not player) then
		shieldLoopId = scheduleEvent(shieldLoop, 1000)
	end
	if (not player:hasState(PlayerStates.ManaShield, player:getStates())) then
		g_game.talk('utamo vita')
	end
	shieldLoopId = scheduleEvent(shieldLoop, 1000)
end

local runeToId = {
	["avalanche rune"] = 3161,
	["heavy magic missile rune"] = 3198
}

function atkSpellLoop()
	local atkSpell = poxBotWindow:recursiveGetChildById('AtkSpellText'):getText()
	local atkRune = poxBotWindow:recursiveGetChildById('AtkRuneName'):getText()
	if (g_game.isAttacking()) then
		if runeToId[atkRune:lower()] then
			local total = 0
			local bestTotal = 0
			local bestCreature = nil
			for _,it in pairs(g_map.getSpectators(player:getPosition(), false)) do
				total = 0
				if table.contains(targets,it:getName():lower()) and g_map.isLookPossible(it:getPosition()) then
					for _,it2 in pairs(g_map.getSpectators(it:getPosition(), false)) do
						if table.contains(targets,it2:getName():lower()) and getDistanceBetween(it:getPosition(), it2:getPosition()) <= 3 then
							total = total+1
						end
					end
					if total > bestTotal then
						bestTotal = total
						bestCreature = it
					end
				end
			end
			if bestTotal >= tonumber(poxBotWindow:recursiveGetChildById('AtkRuneAmount'):getText()) and bestCreature ~= nil then
				g_game.useInventoryItemWith(runeToId[atkRune:lower()],bestCreature)
				atkSpellLoopId = scheduleEvent(atkSpellLoop, 1000)
				return
			end
		end
		if runeToId[atkSpell:lower()] then
			g_game.useInventoryItemWith(runeToId[atkSpell:lower()],g_game.getAttackingCreature())
		else
			g_game.talk(atkSpell)
		end
	end
	atkSpellLoopId = scheduleEvent(atkSpellLoop, 1000)
end

local backpackToId = {
	["blue backpack"] = 2869
}

function itemcount(itemId)
	local count = 0
	if g_game.findItemInContainers(itemId,-1) ~= nil then
		count = g_game.findItemInContainers(itemId,-1):getCount()
	end
	
	return count
end

function atkRuneLoop()
	local atkRune = poxBotWindow:recursiveGetChildById('AtkRuneName'):getText()
	if (g_game.isAttacking() and poxBotWindow:recursiveGetChildById('AtkRune'):isChecked()) then
		local total = 0
		local bestTotal = 0
		local bestCreature = nil
		for _,it in pairs(g_map.getSpectators(player:getPosition(), false)) do
			total = 0
			if table.contains(targets,it:getName():lower()) and g_map.isLookPossible(it:getPosition()) then
				for _,it2 in pairs(g_map.getSpectators(it:getPosition(), false)) do
					if table.contains(targets,it2:getName():lower()) and getDistanceBetween(it:getPosition(), it2:getPosition()) <= 3 then
						total = total+1
					end
				end
				if total > bestTotal then
					bestTotal = total
					bestCreature = it
				end
			end
		end
		if bestTotal >= tonumber(poxBotWindow:recursiveGetChildById('AtkRuneAmount'):getText()) and bestCreature ~= nil then
			g_game.useInventoryItemWith(runeToId[atkRune:lower()],bestCreature)
		end
	end
	atkRuneLoopId = scheduleEvent(atkRuneLoop, 502)
end
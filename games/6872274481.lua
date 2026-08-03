local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/Catv67/'..readfile('catnext/profiles/commit.txt')..'/'..select(1, path:gsub('catnext/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local rankCache = {}
local store = {
	attackReach = 0,
	lastHit = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	rank = setmetatable({}, {
		__index = function(self, index)
			return {async = function()
				if rankCache[index] then
					return rankCache[index]
				end

				if index then
					local rank = bedwars.Handler:Get('FetchRanks'):Fire('CallServer', {index.UserId})
					if typeof(rank) == 'table' and rank[1] and rank[1].rankDivision then
						rankCache[index] = rank[1].rankDivision
						return rankCache[index]
					end
				end

				return nil
			end}
		end
	}),
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {},
	ping = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('catnext/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end
getgenv().collection = collection

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end
getgenv().getBestArmor = getBestArmor

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end
getgenv().getBow = getBow

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end
getgenv().getItem = getItem

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end
getgenv().getSword = getSword

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end
getgenv().getTool = getTool

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end
getgenv().getWool = getWool

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end
getgenv().getStrength = getStrength

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end
getgenv().getPlacedBlock = getPlacedBlock

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end
getgenv().getBlocksInPoints = getBlocksInPoints

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end
getgenv().getNearGround = getNearGround

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end
getgenv().getShieldAttribute = getShieldAttribute

local knockbackSpeed, knockbackBoost = 0, tick()
local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return (20 + (knockbackBoost > tick() and knockbackSpeed or 0)) * (multi + 1)
end
getgenv().getSpeed = getSpeed

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end
getgenv().getTableSize = getTableSize

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end
getgenv().hotbarSwitch = hotbarSwitch

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end
getgenv().notif = notif

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end
getgenv().removeTags = removeTags

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end
getgenv().roundPos = roundPos

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Handler:Get('SetInvItem'):Fire('CallServerAsync', {hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKits')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKits')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local direction = (a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)
		local direction2 = (b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)
		local angle = direction.Magnitude > 0 and math.acos(math.clamp(localfacing:Dot(direction.Unit), -1, 1)) or 0
		local angle2 = direction2.Magnitude > 0 and math.acos(math.clamp(localfacing:Dot(direction2.Unit), -1, 1)) or 0
		return angle < angle2
	end,
	Mouse = function(a, b)
		local mouse = lplr:GetMouse()
		local origin = Vector2.new(mouse.X, mouse.Y)

		local posa, visa = gameCamera:WorldToScreenPoint(a.Entity.RootPart.Position)
		local posb, visb = gameCamera:WorldToScreenPoint(b.Entity.RootPart.Position)
		local dista = visa and (Vector2.new(posa.X, posa.Y) - origin).Magnitude or math.huge
        local distb = visb and (Vector2.new(posb.X, posb.Y) - origin).Magnitude or math.huge
        return (dista == dista and dista or math.huge) < (distb == distb and distb or math.huge)
	end
}
getgenv().sortmethods = sortmethods
local getBlockHits
local function getBlockDistance(a)
	local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
	return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude
end

local breakmethods = {
	Health = function(a, b)
		return getBlockHits(a, b)
	end,
	Distance = function(a, b)
		return getBlockDistance(a) + getBlockHits(a, b) * 0.01
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') and not ent:HasTag('trainingRoomDummy') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKits'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

local require, debug = require, debug
shared.gg = {}
run(function()
	canDebug = not table.find({'Solara', 'Xeno'}, ({identifyexecutor()})[1]) and true or false
	if not canDebug then
		local cheatenginelib = loadstring(downloadFile('catnext/libraries/cheatenginelib.lua'), 'cheatenginelib')(vape, vapeEvents, entitylib)
		require = function(v) 
			return cheatenginelib[({v:GetFullName():gsub(lplr.Name, 'PlayerTemplate')})[1]]:await()
		end
		debug = setmetatable({getproto = function() return function() end end}, {
			__index = function(self, index)
				self[index] = function() end
				return self[index]
			end
		})
	end
end)

local CheatersFlagged = {}
vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
	CheatersFlagged[plr] = nil
end))
run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Remotes = require(game:GetService("ReplicatedStorage").TS.remotes).default

	local Client = Remotes.Client
	local OldGet, OldBreak, OldHit = Client.Get

	local RemoteHandler = {} -- thanks lr <3
	RemoteHandler.CachedRemotes = {}
	RemoteHandler.__index = RemoteHandler

	local RemoteDefinitionConstruct, RemotesInConstruct = next(getupvalue(getrawmetatable(Remotes.Server).Get, 1))
	local GlobalMiddleware = RemoteDefinitionConstruct and getupvalue(RemoteDefinitionConstruct.globalMiddleware[2], 1)
	if not GlobalMiddleware or typeof(GlobalMiddleware) ~= "table" then
		notif('Cat', 'Failed to load ratelimits, report this to a developer.', 30, 'alert')
	end

	function RemoteHandler.Get(self, RemoteID: string)
		if RemoteHandler.CachedRemotes[RemoteID] then
			return RemoteHandler.CachedRemotes[RemoteID]
		end

		local Remote = {}
		setmetatable(Remote, RemoteHandler)

		Remote.ID = RemoteID
		Remote.RequestsInLastMinute = 0
		Remote.MaxRequestsPerMinute = Remote:GetRateLimit()
		Remote.LastRateLimitReset = 0
		
		local Success, AttempedRemote = pcall(Client.Get, Client, Remote.ID)
		Remote.Success = Success
		Remote.Remote = AttempedRemote

		if not Success or not Remote.Remote then
			notif('Cat', `Tried to Get remote {Remote.ID}, remote is invalid`, 15, 'alert')
			Remote.Remote = nil
		end

		RemoteHandler.CachedRemotes[RemoteID] = Remote
		return Remote
	end

	local lastNotify = 0
	function RemoteHandler:Fire(Method: string?, ...)
		local Remote = self.Remote
		if not self.Success or not Remote then
			if tick() - lastNotify > 0.5 then
				lastNotify = tick()
				--notif('Cat', `Tried to Fire remote {Remote.ID}, remote is invalid`, 10, 'alert')
			end
			return {
				andThen = function() end
			}
		end

		if (os.clock() - self.LastRateLimitReset) >= 60 then
			self:ResetRateLimit()
		end

		if self:GetCurrentRequests() >= self:GetRateLimit() then
			if tick() - lastNotify > 0.5 then
				lastNotify = tick()
				--notif('Cat', `{self.ID} has hit its rate limit of {self.MaxRequestsPerMinute} requests per min`, 15, 'alert')
			end
			return {andThen = function() end}
		end

		self:IncrementRequests()
		local CallingFunction = (Method and Remote[Method]) or (Remote.CallServer or Remote.CallServerAsync or Remote.SendToServer)
		if CallingFunction then
			return CallingFunction(Remote, ...)
		end

		return
	end

	function RemoteHandler:ResetRateLimit()
		self.RequestsInLastMinute = 0
		self.LastRateLimitReset = os.clock()
	end

	function RemoteHandler:GetCurrentRequests()
		return self.RequestsInLastMinute
	end

	function RemoteHandler:IncrementRequests()
		self.RequestsInLastMinute = self.RequestsInLastMinute + 1
	end

	function RemoteHandler:GetRateLimit()
		local RemoteName: string = self.ID
		if self.CachedRemotes[RemoteName] then
			return self.CachedRemotes[RemoteName].MaxRequestsPerMinute
		end

		if not GlobalMiddleware then
			return 300
		end

		local GlobalFind = GlobalMiddleware[RemoteName]
		local RateLimitValue: number = (typeof(GlobalFind) ~= "number" and 300) or GlobalFind

		if not GlobalFind then
			local TargetRemote = RemotesInConstruct[RemoteName]
			local RemoteRateLimit = (TargetRemote and TargetRemote.ServerMiddleware)
			if RemoteRateLimit and typeof(RemoteRateLimit) == "table" then
				for i,v in RemoteRateLimit do
					if typeof(v) == "function" and (#getupvalues(v) >= 6 and tostring(getupvalue(v, 6)):find("Request limit")) then
						local Value: number = getupvalue(v, 3)
						RateLimitValue = (typeof(Value) == "number" and Value) or RateLimitValue
						break
					end
				end
			end
		end
		
		return RateLimitValue
	end

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector,
		BlockSelectorMode = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelectorMode,
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		EmoteMeta = require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		EnchantMeta = require(replicatedStorage.TS.enchant['enchant-meta']).EnchantMeta,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getItemSkinMeta = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-meta']).getItemSkinMeta,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		Handler = RemoteHandler,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		ItemSkinType = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType,
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SettingsMeta = require(replicatedStorage.TS.settings['settings-meta']).SettingMeta,
		SharedConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 2),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	store.enchants = setmetatable({}, {
		__index = function(self, plr)
			return {
				async = function()
					if plr and plr.Character then
						for i in plr.Character:GetAttributes() do
							if i:find('StatusEffect_') and not i:find('_stacks') then
								local name = bedwars.StatusEffectMeta[({i:gsub('StatusEffect_', '')})[1]]
								if bedwars.StatusEffectMeta[name] then
									name = bedwars.StatusEffectMeta[name]
                                    for num = 1, 3 do
                                        name = name:gsub("_" .. tostring(num), '')
                                    end

									if bedwars.EnchantMeta[name] then
										return bedwars.EnchantMeta[name].image
									end
								end
							end
						end
					end
					return nil
				end,
			}
		end
	})

	local function createMethodHook(object, method)
		local original = object[method]
		local hooks, order = {}, 0
		local wrapper

		local function sync()
			if #hooks > 0 then
				object[method] = wrapper
			elseif object[method] == wrapper then
				object[method] = original
			end
		end

		wrapper = function(...)
			local index = 0
			local function nextHook(...)
				index += 1
				local hook = hooks[index]
				if hook then
					return hook.Callback(nextHook, ...)
				end
				return original(...)
			end
			return nextHook(...)
		end

		return {
			Add = function(_, id, priority, callback)
				for i = #hooks, 1, -1 do
					if hooks[i].Id == id then
						table.remove(hooks, i)
					end
				end

				order += 1
				local entry = {
					Id = id,
					Priority = priority or 100,
					Order = order,
					Callback = callback,
				}

				table.insert(hooks, entry)
				table.sort(hooks, function(a, b)
					return a.Priority == b.Priority and a.Order < b.Order or a.Priority < b.Priority
				end)
				sync()

				return function()
					for i = #hooks, 1, -1 do
						if hooks[i] == entry then
							table.remove(hooks, i)
						end
					end
					sync()
				end
			end,
			Destroy = function()
				table.clear(hooks)
				sync()
			end,
		}
	end

	bedwars.ProjectileLaunchHook = createMethodHook(bedwars.ProjectileController, 'calculateImportantLaunchValues')
	vape:Clean(function()
		bedwars.ProjectileLaunchHook:Destroy()
	end)

	local projectileCharge = {}
	local chargeOwner
	local chargeSession

	local function chargeOwnerActive()
		return chargeOwner and chargeOwner.IsEnabled()
	end

	local function sameChargeItem(session)
		if not entitylib.isAlive or session.Controller.projectileHandler ~= session.Handler then return false end
		local handItem = session.Controller:getHandItem()
		if not handItem or handItem.itemType ~= session.ItemType then return false end
		return not session.Tool or handItem.tool == session.Tool
	end

	local function cancelChargeSession()
		local session = chargeSession
		chargeSession = nil
		if not session then return end
		if session.DeathConnection then
			session.DeathConnection:Disconnect()
		end
		if session.Thread and session.Thread ~= coroutine.running() then
			task.cancel(session.Thread)
		end
	end

	local function getModifiedChargeTime(value)
		value = tonumber(value)
		if not value or value ~= value or value <= 0 or value == math.huge then return 0 end
		local modified = bedwars.ClientSyncEvents.ProjectileMaxChargeTimeModifierCheck:fire(value)
		local modifiedMaximum = modified and tonumber(modified.maxChargeTime)
		if modifiedMaximum and modifiedMaximum == modifiedMaximum and modifiedMaximum > 0 and modifiedMaximum < math.huge then
			value = modifiedMaximum
		end
		return value
	end

	local function getChargeRange(source, controller)
		local strengthMaximum = getModifiedChargeTime(source and source.maxStrengthChargeSec)
		local multiMaximum = 0
		if controller and type(controller.getChargeTime) == 'function' then
			multiMaximum = tonumber(controller:getChargeTime()) or 0
			if multiMaximum ~= multiMaximum or multiMaximum < 0 or multiMaximum == math.huge then multiMaximum = 0 end
		end
		local maximum = strengthMaximum + multiMaximum
		if maximum ~= maximum or maximum <= 0 or maximum == math.huge then return end
		local minimum = tonumber(source and (source.minStrengthChargeSec or source.minChargeTimeSec)) or 0
		if minimum ~= minimum or minimum < 0 or minimum == math.huge then minimum = 0 end
		return math.clamp(minimum, 0, maximum), maximum, strengthMaximum, multiMaximum
	end

	local function getChargePercentage(value)
		value = tonumber(value) or 100
		return math.clamp(value == value and value or 100, 0, 100)
	end

	local function scheduleChargeSession(session)
		if chargeSession ~= session or not chargeOwnerActive() then return end
		if session.Thread and session.Thread ~= coroutine.running() then
			task.cancel(session.Thread)
		end
		local percentage = getChargePercentage(chargeOwner.GetPercentage())
		local duration = session.Minimum + (session.Maximum - session.Minimum) * (percentage / 100)
		session.Duration = duration
		local remaining
		if session.MultiMaximum > 0 and duration > session.StrengthMaximum then
			local overchargeStarted = tonumber(session.Controller.overchargeStartTime)
			if not overchargeStarted or overchargeStarted <= 0 then return end
			remaining = duration - session.StrengthMaximum - math.max(tick() - overchargeStarted, 0)
		else
			local elapsed = math.clamp(tonumber(session.Handler.drawDurationSeconds) or 0, 0, session.StrengthMaximum)
			remaining = duration - elapsed
		end
		session.Thread = task.delay(math.max(remaining, 0), function()
			session.Thread = nil
			if chargeSession ~= session or not chargeOwnerActive() or not sameChargeItem(session) then
				if chargeSession == session then cancelChargeSession() end
				return
			end
			session.Controller:releaseChargeInput(session.Maid, function()
				return sameChargeItem(session)
			end, session.Input)
		end)
	end

	local chargeBeginHook = createMethodHook(bedwars.ProjectileSourceController, 'beginHolding')
	chargeBeginHook:Add('ProjectileCharge', 100, function(nextBegin, controller, handItem, input, maid, ...)
		local result = nextBegin(controller, handItem, input, maid, ...)
		if not result then return result end
		cancelChargeSession()
		if not chargeOwnerActive() or not controller.projectileHandler then return result end
		local source = controller:getProjectileSource(handItem)
		local minimum, maximum, strengthMaximum, multiMaximum = getChargeRange(source, controller)
		if not maximum then return result end
		local session = {
			Controller = controller,
			Handler = controller.projectileHandler,
			Input = input,
			ItemType = handItem.itemType,
			Maid = maid,
			Maximum = maximum,
			Minimum = minimum,
			MultiMaximum = multiMaximum,
			StrengthMaximum = strengthMaximum,
			Tool = handItem.tool
		}
		chargeSession = session
		local humanoid = entitylib.character.Humanoid
		if humanoid then
			session.DeathConnection = humanoid.Died:Connect(function()
				if chargeSession == session then cancelChargeSession() end
			end)
		end
		scheduleChargeSession(session)
		return result
	end)

	local chargeReleaseHook = createMethodHook(bedwars.ProjectileSourceController, 'releaseChargeInput')
	chargeReleaseHook:Add('ProjectileCharge', 100, function(nextRelease, controller, ...)
		if chargeSession and chargeSession.Controller == controller then
			cancelChargeSession()
		end
		return nextRelease(controller, ...)
	end)

	local chargeFireHook = createMethodHook(bedwars.ProjectileSourceController, 'fireWithCurrentData')
	chargeFireHook:Add('ProjectileCharge', 100, function(nextFire, controller, ...)
		if chargeSession and chargeSession.Controller == controller then
			cancelChargeSession()
		end
		return nextFire(controller, ...)
	end)

	local chargeDisableHook = createMethodHook(bedwars.ProjectileSourceController, 'onDisable')
	chargeDisableHook:Add('ProjectileCharge', 100, function(nextDisable, controller, ...)
		if chargeSession and chargeSession.Controller == controller then
			cancelChargeSession()
		end
		return nextDisable(controller, ...)
	end)

	function projectileCharge:Register(id, getPercentage, isEnabled)
		cancelChargeSession()
		chargeOwner = {
			GetPercentage = getPercentage,
			Id = id,
			IsEnabled = isEnabled
		}
		local registered = true
		return function()
			if not registered then return end
			registered = false
			if chargeOwner and chargeOwner.Id == id then
				cancelChargeSession()
				chargeOwner = nil
			end
		end
	end

	function projectileCharge:Refresh(id)
		if chargeOwner and chargeOwner.Id == id and chargeSession then
			scheduleChargeSession(chargeSession)
		end
	end

	function projectileCharge:IsOwned()
		return chargeOwnerActive() == true
	end

	function projectileCharge:GetLaunchMultiplier(handler, fullCharge)
		local multiplier = tonumber(handler and handler.velocityMultiplier) or 1
		if multiplier ~= multiplier or multiplier < 0 or multiplier == math.huge then multiplier = 1 end
		return self:IsOwned() and multiplier or fullCharge and 1 or multiplier
	end

	function projectileCharge:GetDrawDuration(handler, fullCharge)
		local duration = tonumber(handler and handler.drawDurationSeconds) or 0
		if duration ~= duration or duration < 0 or duration == math.huge then duration = 0 end
		return self:IsOwned() and duration or fullCharge and 5 or duration
	end

	function projectileCharge:GetDuration(source, percentage, controller)
		local minimum, maximum = getChargeRange(source, controller)
		if not maximum then return end
		return minimum + (maximum - minimum) * (getChargePercentage(percentage) / 100), minimum, maximum
	end

	bedwars.ProjectileCharge = projectileCharge
	local chargeStoreConnection = bedwars.Store.changed:connect(function()
		if chargeSession and not sameChargeItem(chargeSession) then
			cancelChargeSession()
		end
	end)
	local maxChargeConnection = bedwars.ClientSyncEvents.ProjectileMaxCharged:connect(function(itemType)
		local session = chargeSession
		if not session or session.ItemType ~= itemType or session.MultiMaximum <= 0 then return end
		task.defer(function()
			if chargeSession == session then scheduleChargeSession(session) end
		end)
	end)
	vape:Clean(lplr.CharacterAdded:Connect(cancelChargeSession))
	vape:Clean(function()
		cancelChargeSession()
		chargeOwner = nil
		chargeStoreConnection:disconnect()
		maxChargeConnection:Destroy()
		chargeBeginHook:Destroy()
		chargeReleaseHook:Destroy()
		chargeFireHook:Destroy()
		chargeDisableHook:Destroy()
		if bedwars.ProjectileCharge == projectileCharge then
			bedwars.ProjectileCharge = nil
		end
	end)

	local function getproto(...)
		local success, res = pcall(debug.getproto, ...)
		return success and res or function() end
	end
	local remoteNames = {
		AfkStatus = canDebug and getproto(Knit.Controllers.AfkController.KnitStart, 1) or function() end,
		AttackEntity = canDebug and Knit.Controllers.SwordController.sendServerRequest or function() end,
		BeePickup = canDebug and Knit.Controllers.BeeNetController.trigger or function() end,
		CannonAim = canDebug and getproto(Knit.Controllers.CannonController.startAiming, 5) or function() end,
		CannonLaunch = canDebug and Knit.Controllers.CannonHandController.launchSelf or function() end,
		ConsumeBattery = canDebug and getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1) or function() end,
		ConsumeItem = canDebug and getproto(Knit.Controllers.ConsumeController.onEnable, 1) or function() end,
		ConsumeSoul = canDebug and Knit.Controllers.GrimReaperController.consumeSoul or function() end,
		ConsumeTreeOrb = canDebug and getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1) or function() end,
		DepositPinata = canDebug and getproto(getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5) or function() end,
		DragonBreath = canDebug and getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5) or function() end,
		DragonEndFly = canDebug and getproto(Knit.Controllers.VoidDragonController.flapWings, 1) or function() end,
		DragonFly = canDebug and Knit.Controllers.VoidDragonController.flapWings or function() end,
		DropItem = canDebug and Knit.Controllers.ItemDropController.dropItemInHand or function() end,
		EquipItem = canDebug and getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4) or function() end,
		FireProjectile = canDebug and debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) or function() end,
		GroundHit = canDebug and Knit.Controllers.FallDamageController.KnitStart or function() end,
		GuitarHeal = canDebug and Knit.Controllers.GuitarController.performHeal or function() end,
		HannahKill = canDebug and getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1) or function() end,
		HarvestCrop = canDebug and getproto(getproto(Knit.Controllers.CropController.KnitStart, 4), 1) or function() end,
		KaliyahPunch = canDebug and getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1) or function() end,
		MageSelect = canDebug and getproto(Knit.Controllers.MageController.registerTomeInteraction, 1) or function() end,
		MinerDig = canDebug and getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1) or function() end,
		PickupItem = canDebug and Knit.Controllers.ItemDropController.checkForPickup or function() end,
		PickupMetal = canDebug and getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4) or function() end,
		ReportPlayer = canDebug and require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer or function() end,
		ResetCharacter = canDebug and getproto(Knit.Controllers.ResetController.createBindable, 1) or function() end,
		SpawnRaven = canDebug and getproto(Knit.Controllers.RavenController.KnitStart, 1) or function() end,
		SummonerClawAttack = canDebug and Knit.Controllers.SummonerClawHandController.attack or function() end,
		WarlockTarget = canDebug and getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2) or function() end
	}

	local packages = httpService:JSONDecode(downloadFile('catnext/profiles/packages.json'))	
	local function dumpRemote(tab)
		if not tab then return '' end
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' and packages.remotes[i] then
			remote = packages.remotes[i]
		end
		if remote == '' then
			notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
		remotes[i] = remote
	end
    getgenv().remotes = remotes

	entitylib.Raycast = function(origin, direction, params)
		return bedwars.QueryUtil:raycast(origin, direction, params)
	end
	prediction.Raycast = entitylib.Raycast

	OldBreak = bedwars.BlockController.isBlockBreakable
	OldHit = bedwars.BlockBreaker.hitBlock

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == 'SwordHit' then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end
	bedwars.BlockBreaker.hitBlock = function(...)
        store.lastHit = tick()
        return OldHit(...)
    end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	calculatePath = function(target, blockpos, solidonly, breakmethod)
		local heap = {}
		local function push(cost, node)
			local index = #heap + 1
			heap[index] = {cost, node}

			while index > 1 do
				local parent = index // 2
				if heap[parent][1] <= heap[index][1] then break end
				heap[parent], heap[index] = heap[index], heap[parent]
				index = parent
			end
		end

		local function pop()
			local size = #heap
			if size == 0 then return end
			local root = heap[1]

			heap[1], heap[size], size = heap[size], nil, size - 1
			local index = 1

			while true do
				local left, right, smallest = index * 2, (index * 2) + 1, index
				if left <= size and heap[left][1] < heap[smallest][1] then smallest = left end
				if right <= size and heap[right][1] < heap[smallest][1] then smallest = right end
				if smallest == index then break end

				heap[index], heap[smallest] = heap[smallest], heap[index]
				index = smallest
			end

			return root[1], root[2]
		end

		local visited, distances, exposed, path = {}, {[blockpos] = 0}, {}, {}
		local gaps, sources = {[blockpos] = 0}, {[blockpos] = blockpos}
		push(0, blockpos)

		for _ = 1, 10000 do
			local cost, node = pop()
			if not node then break end
			if visited[node] then continue end
			visited[node] = true
			local current, source = getPlacedBlock(node), sources[node]

			for _, side in sides do
				side = node + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block then
					if current then
						local cells = exposed[node]
						if cells then
							table.insert(cells, side)
						else
							exposed[node] = {side}
						end
					end

					local gap = current and 1 or (gaps[node] + 1)
					if not solidonly and gap <= 2 and (side - blockpos).Magnitude <= 15 and cost < (distances[side] or math.huge) then
						distances[side] = cost
						gaps[side] = gap
						sources[side] = source
						push(cost, side)
					end
					continue
				end

				if block:GetAttribute('NoBreak') or block == target then continue end

				local curdist = cost + (breakmethod or getBlockHits)(block, side)
				if curdist < (distances[side] or math.huge) then
					distances[side] = curdist
					gaps[side] = 0
					sources[side] = side
					path[side] = source
					push(curdist, side)
				end
			end
		end

		local origin = entitylib.character.RootPart.Position
		local candidates = {}
		for node, cells in exposed do
			table.insert(candidates, {distances[node], node, cells})
		end
		table.sort(candidates, function(a, b)
			if a[1] == b[1] then
				return (a[2] - origin).Magnitude < (b[2] - origin).Magnitude
			end
			return a[1] < b[1]
		end)

		local routes = {}
		local function isOpen(cell)
			if routes[cell] ~= nil then
				return routes[cell]
			end
			local queue, seen, open = {cell}, {[cell] = true}, true

			for _ = 1, 400 do
				local current = table.remove(queue)
				if not current then
					open = false
					break
				end
				if (current - blockpos).Magnitude > 15 then break end

				for _, side in sides do
					side = current + side
					if seen[side] or getPlacedBlock(side) then continue end
					seen[side] = true
					table.insert(queue, side)
				end
			end

			for reached in seen do
				routes[reached] = open
			end
			return open
		end

		--[[
			Sampling a line every stud rounds each point to a cell and can report a block
			the line never enters, so the grid is walked one crossing at a time instead.
		]]
		local function boundary(index, component, delta)
			if delta == 0 then
				return 0, math.huge, math.huge
			end
			local step = delta > 0 and 1 or -1
			return step, ((((index + (step * 0.5)) * 3) - component) / delta), (3 / math.abs(delta))
		end

		local sightlines = {}
		local function canSee(cell)
			if sightlines[cell] ~= nil then
				return sightlines[cell]
			end
			local start, direction = bedwars.BlockController:getBlockPosition(origin), cell - origin
			local x, y, z, clear = start.X, start.Y, start.Z, true

			local stepx, nextx, deltax = boundary(x, origin.X, direction.X)
			local stepy, nexty, deltay = boundary(y, origin.Y, direction.Y)
			local stepz, nextz, deltaz = boundary(z, origin.Z, direction.Z)

			for _ = 1, 100 do
				if nextx > 1 and nexty > 1 and nextz > 1 then break end

				if nextx <= nexty and nextx <= nextz then
					x, nextx = x + stepx, nextx + deltax
				elseif nexty <= nextz then
					y, nexty = y + stepy, nexty + deltay
				else
					z, nextz = z + stepz, nextz + deltaz
				end

				if getPlacedBlock(Vector3.new(x, y, z) * 3) then
					clear = false
					break
				end
			end

			sightlines[cell] = clear
			return clear
		end

		local pos, cost = nil, nil
		for _, candidate in candidates do
			if (candidate[2] - origin).Magnitude > 30 then continue end
			local bed = not solidonly and getPlacedBlock(candidate[2]) == target

			for _, cell in candidate[3] do
				if isOpen(cell) and (not bed or canSee(cell)) then
					pos, cost = candidate[2], candidate[1]
					break
				end
			end

			if pos then break end
		end

		if not pos then
			for _, candidate in candidates do
				if solidonly or getPlacedBlock(candidate[2]) ~= target then
					pos, cost = candidate[2], candidate[1]
					break
				end
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end

		return
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, autotool, wallcheck, method)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, not wallcheck, method or nil)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if autotool then
						local hotbar = getHotbar(tool.tool)
						if hotbar then
							hotbarSwitch(hotbar)
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.blockHealthbar:destroy()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	vape:Clean(bedwars.ZapNetworking.BreakBlockEventZap.On(function(...)
		local data = {
			blockRef = {
				blockPosition = ...,
			},
			player = select(5, ...)
		}
		for i, v in cache do
			if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
				table.clear(v[3])
				table.clear(v)
				cache[i] = nil
			end
		end
		vapeEvents.BreakBlockEvent:Fire(data)
	end))

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			local map = workspace:WaitForChild('Map', 9e9):WaitForChild('Worlds', 9e9):GetChildren()[1]
			mapname = map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			store.map = map
			vape:Clean(map.Blocks.ChildAdded:Connect(function(v)
				task.defer(function()
					if v:IsA('BasePart') and v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
						local pos = v.Position / 3
						vapeEvents.PlaceBlockEvent:Fire({
							blockRef = {blockPosition = Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))},
							player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId'))
						})
					end
				end)
			end))
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat task.wait() until store.map or vape.Loaded == nil
		if vape.Loaded == nil then return end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = {store.map}
		store.airRay = rayParams

		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		task.wait(1)
		Client.Get = OldGet
		bedwars.BlockBreaker.hitBlock = OldHit
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

local function getFunctionRange(func)
	local last = false
	for _, v in debug.getconstants(func) do
		if v == 'maxActivationDistance' then
			last = true
		elseif last then
			return v and typeof(v) == 'number' and v or nil
		end
	end
	return nil
end
getgenv().getFunctionRange = getFunctionRange

for _, v in {'AntiRagdoll', 'TriggerBot', 'SafeWalk', 'SilentAim', 'Jesus', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'Wallhop', 'Xray', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end

run(function()
	local AimAssist
	local AimMode
	local Mode
	local Targets
	local Sort
	local AimPart
	local AimSpeed
	local Shake
	local Distance
	local AngleSlider
	local StrafeIncrease
	local BlockBreak
	local KillauraTarget
	local ClickAim
	local Mouse
	local Limit
	
	local function ease(t)
		return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
	end
	
	local cache = setmetatable({}, { __mode = 'k' })
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService.GetMouseLocation(inputService)
	end
	
	local function getAim(ent)
		if AimPart.Value == 'Closest' then
			if not cache[ent.Character] then
				cache[ent.Character] = ent.Character:GetChildren()
			end
			local localPosition, magnitude, part = getMousePosition(), 9e9, nil
			for _, v in cache[ent.Character] do
				if v and v.Parent and v:IsA('BasePart') then
					local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
	
					if vis then
						local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
	
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			if part then
				return part.Position
			end
		end
		return ent.RootPart.Position
	end
	
	local started, lasttarget = 0, nil
	local aimfuncs = {
		Simple = function(localcframe, ent, fps)
			local rng = Random.new()
			local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0))
	
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end,
		Adaptive = function(localcframe, ent, fps)
			local prog, rng = ease(math.min(tick() - started, 1)), Random.new()
			local speed = (AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end
	}
	
	local function GetTarget()
		if lasttarget then
			local localPosition = entitylib.character.RootPart.Position
			if not lasttarget or not lasttarget.RootPart or not lasttarget.Humanoid or not lasttarget.Humanoid.Health or lasttarget.Humanoid.Health <= 0 then
				return false
			end
			if (localPosition - lasttarget.RootPart.Position).Magnitude > Distance.Value then
				return false
			end
			if Targets.Walls.Enabled and entitylib.Wallcheck(localPosition, lasttarget.RootPart.Position, Targets.Walls.Enabled) then
				return false
			end
			return lasttarget
		end
	
		return false
	end
	
	local function getAttackData()
		if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15 then
			return false
		end
		if ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
			return false
		end
		if BlockBreak.Enabled and (tick() - store.lastHit) < 0.3 then
			return false
		end
		if Limit.Enabled and store.hand.toolType ~= 'sword' then
			return false
		end
	
		if (tick() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
			local ent = GetTarget() or KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
				Range = Distance.Value,
				Part = 'RootPart',
				Wallcheck = Targets.Walls.Enabled,
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Sort = sortmethods[Sort.Value]
			})
			if ent then
				started = tick()
			end
			lasttarget = ent
		else
			lasttarget = nil
		end
		return lasttarget
	end
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				local rotate = 0
				
				AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive then
						entitylib.character.Humanoid.AutoRotate = tick() > rotate
	
						local ent = getAttackData()
						if ent then
							local root = entitylib.character.RootPart
							local delta = (ent.RootPart.Position - root.Position)
							local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local horizontal = delta * Vector3.new(1, 0, 1)
							local angle = localfacing.Magnitude > 0 and horizontal.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(horizontal.Unit), -1, 1)) or 0
							if angle >= (math.rad(AngleSlider.Value) / 2) then
								return
							end
							targetinfo.Targets[ent] = tick() + 1
	
							local firstPerson = entitylib.character.Head.LocalTransparencyModifier == 1
							local perspective = AimMode.Value
	
							if perspective == 'Mouse' then
								local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
								local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
								mousemoverel(pos.X, pos.Y)
							elseif perspective == 'First person' or (perspective == 'Dynamic' and firstPerson) then
								if not firstPerson then return end
								local cframe = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								gameCamera.CFrame = cframe
							elseif perspective == 'Third person' or (perspective == 'Dynamic' and not firstPerson) then
								if firstPerson then return end
								local cframe = aimfuncs[Mode.Value](root.CFrame, ent, dt)
								local direction = cframe.LookVector * Vector3.new(1, 0, 1)
								if direction.Magnitude > 0 then
									entitylib.character.Humanoid.AutoRotate = false
									root.CFrame = CFrame.lookAlong(root.Position, direction)
									rotate = tick() + 0.1
								end
							end
						end
					else
						lasttarget = nil
					end
				end))
			else
				lasttarget = nil
				if entitylib.isAlive then
					entitylib.character.Humanoid.AutoRotate = true
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	local modes = {}
	for i in aimfuncs do
		table.insert(modes, i)
	end
	AimMode = AimAssist:CreateDropdown({
		Name = 'Aim perspective',
		Tooltip = 'First person - Uses your camera to aim\nThird person - Moves your character to where your supposed to look\nMouse - Moves your mouse & camera\nDynamic - Uses first person mode if ur in first person, and uses third person if ur in third person',
		List = {'First person', 'Third person', 'Dynamic'},
		Default = 'First person'
	})
	Mode = AimAssist:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
		Default = modes[1],
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true,
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click aim',
		Default = true,
	})
	Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
	BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
	KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 6,
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
	})
	Shake = AimAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter to simulate human aim',
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70,
	})
	Limit = AimAssist:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks when sword is held',
	})
	Sort = AimAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Angle',
	})
	AimPart = AimAssist:CreateDropdown({
		Name = 'Target area',
		List = {'Center', 'Closest'},
		Default = 'Center',
	})
end)

run(function()
	local AutoClicker
	local CPS
	local Wool
	local BlockCPS = {}
	local Thread
	
	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end
	
		Thread = task.delay(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue(), function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and (Wool.Enabled and store.hand.tool.Name:find('wool_') or not Wool.Enabled) and blockPlacer then
						if inputService.TouchEnabled then
							task.spawn(blockPlacer.autoBridge, blockPlacer, workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
						else
							if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
								local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
								end
							end
						end
					elseif store.hand.toolType == 'sword' then
						bedwars.SwordController:swingSwordAtMouse(0.39)
					end
				end
	
				task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
			until not AutoClicker.Enabled
		end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						AutoClick()
					end
				end))
	
				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))
	
				if inputService.TouchEnabled then
					for _, v in {'2', '5'} do
						pcall(function()
							AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
							AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(function()
								if Thread then
									task.cancel(Thread)
									Thread = nil
								end
							end))
						end)
					end
				end
			else
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
	
			if Wool and Wool.Object then
				Wool.Object.Visible = callback
			end
		end
	})
	Wool = AutoClicker:CreateToggle({Name = 'Wool only', Tooltip = 'Only clicks when you are holding wool.', Darker = true})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)

run(function()
	local BlockReach
	local BlockRange
	local BreakReach
	local BreakRange
	local SwordReach
	local SwordRange
	
	local old
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Tooltip = 'Allows you to place, attack, and break further',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
			if callback then
				old = bedwars.BlockSelector.getMouseInfo
				bedwars.BlockSelector.getMouseInfo = function(...)
					local Self, Select, Args = ...
					if not Args then
						Args = {}
					end
					if Select == 0 then
						Args.range = BlockReach.Enabled and BlockRange.Value or 24
					elseif Select == 1 then
						Args.range = BreakReach.Enabled and BreakRange.Value or 18
					end
					return old(Self, Select, Args)
				end
			else
				bedwars.BlockSelector.getMouseInfo = old
				old = nil
			end
		end,
	})
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
			pcall(function()
				SwordRange.Object.Visible = callback
			end)
		end,
		Default = true
	})
	SwordRange = Reach:CreateSlider({
		Name = 'Sword Range',
		Min = 1,
		Max = 18,
		Default = 18,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Function = function(val)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
		end
	})
	BlockReach = Reach:CreateToggle({
		Name = 'Placement Reach',
		Function = function(callback)
			BlockRange.Object.Visible = callback
		end
	})
	BlockRange = Reach:CreateSlider({
		Name = 'Placement Range',
		Min = 1,
		Max = 60,
		Default = 18,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	BreakReach = Reach:CreateToggle({
		Name = 'Break Reach',
		Function = function(callback)
			BreakRange.Object.Visible = callback
		end
	})
	BreakRange = Reach:CreateSlider({
		Name = 'Break Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	Reach:CreateButton({
		Name = 'Reset to default reach',
		Tooltip = 'Resets every range back to default',
		Function = function()
			BreakRange:SetValue(18)
			BlockRange:SetValue(24)
			SwordRange:SetValue(12.4)
		end
	})
end)

run(function()
	local SilentAim
	local Targets
	local TargetPart
	local Sort
	local Prediction
	local FOV
	local OtherProjectiles
	local Blacklist
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	
	local hooked = false
	local removeNamecall
	local fireRemote
	local hookVersion = 0
	
	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService.GetMouseLocation(inputService)
	end
	
	local function getPosition(ent)
		if TargetPart.Value == 'Closest' then
			local localPosition, magnitude, part = getMousePosition(), 9e9, nil
			for _, v in ent:GetChildren() do
				if v:IsA('BasePart') then
					local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)
					if vis then
						local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			return part and part.Position or ent.PrimaryPart and ent.PrimaryPart.Position
		elseif TargetPart.Value == 'Dynamic' then
			local tool = store.hand.tool
			if tool and tool.Name:find('headhunter') and ent:FindFirstChild('Head') then
				return ent.Head.Position
			end
			return ent.PrimaryPart and ent.PrimaryPart.Position
		end
		return
	end
	
	local function solveSilent(args)
		local origin, velocity, projType = args[4], args[6], args[3]
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or type(projType) ~= 'string' then
			return
		end
	
		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end
	
		if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then
			return
		end
	
		local meta = bedwars.ProjectileMeta[projType]
		if not meta then return end
	
		local speed = velocity.Magnitude
		if speed <= 0 then return end
		local gravity = meta.gravitationalAcceleration or 196.2
	
		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[Sort.Value or 'Distance'],
			Origin = origin,
		})
		if not plr then return end
	
		local targetpart = plr[TargetPart.Value]
		local targetpos = getPosition(plr.Character) or targetpart and targetpart.Position
		if not targetpos then return end
		local playerGravity = workspace.Gravity
		local balloons = plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
	
		local pearl = projType == 'telepearl'
		local targetVelocity = pearl and Vector3.zero or plr.RootPart.AssemblyLinearVelocity
		local targetAirborne = not pearl and plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
		local calc, _, travelTime = prediction.SolveTrajectory(origin, speed * Prediction.Value, gravity, targetpos, targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
		if not calc or not travelTime or travelTime > (meta.lifetimeSec or 3) then return end
	
		targetinfo.Targets[plr] = tick() + 1
		return CFrame.lookAt(origin, calc).LookVector * speed
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			hookVersion += 1
			if callback and not namecall then
				namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
					if SilentAim.Enabled and not checkcaller() and getnamecallmethod() == 'InvokeServer' and tostring(...) == 'ProjectileFire' then
						local self = ...
						local args = {select(2, ...)}
						print('yo its kinda working')
						local newVelocity = solveSilent(args)
						if newVelocity then
							args[6] = newVelocity
						end
						return namecall(self, self.InvokeServer(self, unpack(args)))
					end
					return namecall(...)
				end))
			end
		end,
		Tooltip = 'Redirects only the projectile values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen'
	})
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true,
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Dynamic', 'Closest'},
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = SilentAim:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Function = function(call)
			if Blacklist and Blacklist.Object then
				Blacklist.Object.Visible = call
			end
		end,
	    Default = true
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile'
	})
end)

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)

run(function()
	local TriggerBot
	local CPS
	local rayParams = RaycastParams.new()
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local doAttack
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
							rayParams.FilterDescendantsInstances = {lplr.Character}
	
							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								local limit = (attackRange)
								for _, ent in entitylib.List do
									doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end
	
							doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
					end
	
					task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
end)

run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
					
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)

run(function()
	local AntiDeath
	local StopThreshold
	local Threshold
	local Notify
	local Delay
	local Mode
	
	local oldroot, clone, hip = nil, nil, 2.7
	
	local function createClone()
	    if store.rootpart then return false end
	    if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
	        hip = entitylib.character.Humanoid.HipHeight
	        oldroot = entitylib.character.HumanoidRootPart
	        if not lplr.Character.Parent then return false end
	        lplr.Character.Parent = replicatedStorage
	        clone = oldroot:Clone()
	        clone.Parent = lplr.Character
	        oldroot.Transparency = 1
	        oldroot.Parent = workspace
	        store.rootpart = oldroot
	        lplr.Character.PrimaryPart = clone
	        lplr.Character.Parent = workspace
	        bedwars.QueryUtil:setQueryIgnored(clone, true)
	        bedwars.QueryUtil:setQueryIgnored(oldroot, true)
	        return true
	    end
	    return false
	end
	
	local function destroyClone()
	    local char = lplr.Character
	    if oldroot and oldroot.Parent and char then 
	        char.Parent = replicatedStorage
	        oldroot.Parent = char
	        if clone then
	            clone:Destroy()
	            clone = nil
	        end
	        char.PrimaryPart = oldroot
	        char.Parent = workspace
	        oldroot.CanCollide = true
	        local humanoid = char:FindFirstChildOfClass('Humanoid')
	        if humanoid then
	            humanoid.HipHeight = hip or 2.6
	        end
	        oldroot.Transparency = 1
	        oldroot = nil
	        store.rootpart = nil
	        return true
	    end
	    if clone then
	        clone:Destroy()
	        clone = nil
	    end
	    oldroot = nil
	    store.rootpart = nil
	    return false
	end
	
	local Paused, Activated = 0, 0
	
	AntiDeath = vape.Categories.Blatant:CreateModule({
	    Name = 'AntiDeath',
	    Function = function(call)
	        if call then
	            local FloatTime = tick();
	
	            AntiDeath:Clean(runService.PreSimulation:Connect(function()
	                if oldroot and oldroot.Parent then
	                    if (tick() - entitylib.character.AirTime) > 1.7 then
	                        FloatTime = tick() + 0.2
	                    end
	                    oldroot.Velocity = Vector3.new(0, 1, 0)
	                    oldroot.CFrame = clone.CFrame - (tick() > FloatTime and Vector3.new(0, 200, 0) or Vector3.zero)
	                end
	            end))
	
	            repeat
	                if tick() > Paused and entitylib.isAlive and (entitylib.character.Humanoid.Health <= Threshold.Value) then
	                    if (tick() - Activated) >= Delay.Value then
	                        Activated = tick()
	
	                        if Notify.Enabled then
	                            notif('AntiDeath', `Health below {Threshold.Value}%`, 12, 'warning')
	                        end
	
	                        if Mode.Value == 'Teleport' then
	                            lplr.Character.PrimaryPart.CFrame += Vector3.new(0, 100, 0)
	                            Paused = tick() + 5
	                        elseif Mode.Value == 'Invincibility' then
	                            if createClone() then
	                                Paused = tick() + 5
	                                task.delay(0, function()
	                                    repeat task.wait() until not AntiDeath.Enabled or not entitylib.isAlive or (entitylib.character.Humanoid.Health >= StopThreshold.Value)
	                                    local old = clone and clone.CFrame or nil
	                                    if destroyClone() and old then
	                                        entitylib.character.RootPart.CFrame = old
	                                    end
	                                    Paused = tick() + 5
	
	                                    if AntiDeath.Enabled and Notify.Enabled then
	                                        notif('AntiDeath', 'You are visible again', 12, 'info')
	                                    end
	                                end)
	                            end
	                        end
	                    end
	                end
	                task.wait()
	            until not AntiDeath.Enabled
	        else
	            destroyClone()
	        end
	    end,
	    Tooltip = 'Uses selected mode when on a threshold'
	})
	
	Mode = AntiDeath:CreateDropdown({
	    Name = 'Mode',
	    List = {'Teleport', 'Invincibility'},
	    Default = 'Invincibility',
	    Tooltip = 'Teleport - Teleports you high up\nInvincibility - Makes you unhittable'
	})
	StopThreshold = AntiDeath:CreateSlider({
	    Name = 'Stop Threshold',
	    Min = 1,
	    Max = 100,
	    Default = 30,
	    Suffix = function()
	        return '%'
	    end,
	    Tooltip = 'Health percentage to untrigger at'
	})
	Threshold = AntiDeath:CreateSlider({
	    Name = 'Threshold',
	    Min = 1,
	    Max = 100,
	    Default = 30,
	    Suffix = function()
	        return '%'
	    end,
	    Tooltip = 'Health percentage to trigger at'
	})
	Delay = AntiDeath:CreateSlider({
	    Name = 'Delay',
	    Min = 1,
	    Max = 20,
	    Default = 5,
	    Suffix = function(val)
	        return val <= 1 and 'sec' or 'secs'
	    end,
	    Tooltip = 'Delay between triggers'
	})
	Notify = AntiDeath:CreateToggle({
	    Name = 'Notify on trigger',
	    Default = true
	})
	
end)

local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect() -- i fixed, inffly doesnt exist
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos.Y, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)

run(function()
    local AutoChargeProj
    local Percentage

    local old

    AutoChargeProj = vape.Categories.Blatant:CreateModule({
        Name = 'AutoChargeProj',
        Function = function(callback)
            if callback then
                old = bedwars.ProjectileController.calculateImportantLaunchValues
                bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
                    local args = {...}
                    args[2].drawDurationSeconds = math.max(args[2].drawDurationSeconds, bedwars.ProjectileMeta[args[2].projectile].predictionLifetimeSec * (Percentage.Value / 100))
                    args[2].velocityMultiplier = math.max(args[2].velocityMultiplier, 1 * (Percentage.Value / 100))
                    return old(unpack(args))
                end
            elseif old then
                bedwars.ProjectileController.calculateImportantLaunchValues = old
                old = nil
            end
        end,
        Tooltip = 'Instantly charges your projectile item to a certain percentage'
    })

    Percentage = AutoChargeProj:CreateSlider({
        Name = 'Percentage',
        Min = 0,
        Max = 100,
        Default = 50,
        Suffix = '%'
    })
end)

run(function()
	local CannonSpeed
	local Value
	
	CannonSpeed = vape.Categories.Blatant:CreateModule({
	    Name = 'CannonSpeed',
	    Function = function(callback)
	        debug.setconstant(bedwars.CannonHandController.launchSelf, 15, callback and Value.Value or 200)
	    end,
	    Tooltip = 'Makes you go faster with cannon.'
	})
	
	Value = CannonSpeed:CreateSlider({
	    Name = 'Speed',
	    Min = 1,
	    Max = 400,
	    Default = 200,
	    Function = function(val)
	        if CannonSpeed.Enabled then
	            debug.setconstant(bedwars.CannonHandController.launchSelf, 15, val)
	        end
	    end,
	    Suffix = function(val)
	        return val <= 1 and 'stud' or 'studs'
	    end
	})
	CannonSpeed:CreateButton({
	    Name = 'Sync to legit speed',
	    Function = function()
	        Value:SetValue(200)
	    end
	})
end)

run(function()
	local DamageBoost
	local stack
	
	DamageBoost = vape.Categories.Blatant:CreateModule({
		Name = 'DamageBoost',
		Function = function(callback)
			if callback then
				DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not vape.Modules.LongJump.Enabled then
						local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
						knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = horizontal,
						}).Magnitude * (0.9 + store.ping.total)
	                    stack = tick() + (knockbackSpeed / 45)
	                    knockbackBoost = tick() + (horizontal / 3.5)
					end
				end))
			end
		end,
	    Tooltip = 'Makes you go slightly faster when damaged'
	})
end)

run(function()
	local FastBreak
	local BedCheck
	local Blacklist
	local Blacklisted
	local Time
	
	local newlist, old = {}, nil
	local function find(tab, ind)
		for i, v in tab do
			if v == ind or v:find(ind) then
				return i
			end
		end
		return nil
	end
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, ...)
					local _, params = unpack({...})
					pcall(function()
						local block, info = nil, self.clientManager:getBlockSelector():getMouseInfo(1, {ray = params})
						block = info and info.target and info.target.blockInstance or nil
						if block and (not Blacklist.Enabled or not find(newlist, block.Name)) and (not BedCheck.Enabled or block.Name ~= 'bed') then
							bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
						end
					end)
	
					return old(self, ...)
				end
	
				repeat
					if (tick() - store.lastHit) > 0.3 then
						bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
					end
					task.wait(0.1)
				until not FastBreak.Enabled
			elseif old then
				bedwars.BlockBreaker.hitBlock = old
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	FastBreak:CreateButton({
		Name = 'Sync to legit speed',
		Function = function()
			Time:SetValue(0.3)
		end
	})
	BedCheck = FastBreak:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Doesn\'t increase speed if ur breaking a bed'
	})
	Blacklist = FastBreak:CreateToggle({
		Name = 'Use blacklist',
		Function = function(callback)
			if Blacklisted and Blacklisted.Object then
				Blacklisted.Object.Visible = callback
			end
		end
	})
	Blacklisted = FastBreak:CreateTextList({
		Name = 'Blocks',
		Function = function(list)
			newlist = {}
			for _, v in list do
				if v:find('iron') then
					table.insert(newlist, 'iron_ore_mesh_block')
				else
					table.insert(newlist, v)
				end
			end
		end,
		Darker = true,
		Visible = false
	})
end)

local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end
				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
						local mass = (-0.02 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = (tick() - entitylib.character.AirTime)
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
										root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
end)

run(function()
	local Mode
	local Expand
	local objects, set = {}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)

local Attacking
run(function()
    local AimAssist
    local AimMode
    local Mode
    local Targets
    local Sort
    local AimPart
    local AimSpeed
    local Shake
    local Distance
    local AngleSlider
    local StrafeIncrease
    local BlockBreak
    local KillauraTarget
    local ClickAim
    local Mouse
    local Limit

    local function ease(t)
    	return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
    end

    local cache = setmetatable({}, { __mode = 'k' })
    local function getMousePosition()
    	if inputService.TouchEnabled then
    		return gameCamera.ViewportSize / 2
    	end
    	return inputService.GetMouseLocation(inputService)
    end

    local function getAim(ent)
    	if AimPart.Value == 'Closest' then
    		if not cache[ent.Character] then
    			cache[ent.Character] = ent.Character:GetChildren()
    		end
    		local localPosition, magnitude, part = getMousePosition(), 9e9, nil
    		for _, v in cache[ent.Character] do
    			if v and v.Parent and v:IsA('BasePart') then
    				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)

    				if vis then
    					local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude

    					if mag < magnitude then
    						magnitude = mag
    						part = v
    					end
    				end
    			end
    		end
    		if part then
    			return part.Position
    		end
    	end
    	return ent.RootPart.Position
    end

    local started, lasttarget = 0, nil
    local aimfuncs = {
    	Simple = function(localcframe, ent, fps)
    		local rng = Random.new()
    		local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0))

    		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    	end,
    	Adaptive = function(localcframe, ent, fps)
    		local prog, rng = ease(math.min(tick() - started, 1)), Random.new()
    		local speed = (AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)
    		return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
    	end
    }

    local function GetTarget()
    	if lasttarget then
    		local localPosition = entitylib.character.RootPart.Position
    		if not lasttarget or not lasttarget.RootPart or not lasttarget.Humanoid or not lasttarget.Humanoid.Health or lasttarget.Humanoid.Health <= 0 then
    			return false
    		end
    		if (localPosition - lasttarget.RootPart.Position).Magnitude > Distance.Value then
    			return false
    		end
    		if Targets.Walls.Enabled and entitylib.Wallcheck(localPosition, lasttarget.RootPart.Position, Targets.Walls.Enabled) then
    			return false
    		end
    		return lasttarget
    	end

    	return false
    end

    local function getAttackData()
    	if Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15 then
    		return false
    	end
    	if ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
    		return false
    	end
    	if BlockBreak.Enabled and (tick() - store.lastHit) < 0.3 then
    		return false
    	end
    	if Limit.Enabled and store.hand.toolType ~= 'sword' then
    		return false
    	end

    	if (tick() - started) > 1 or not lasttarget or not lasttarget.Parent or not lasttarget.Humanoid or lasttarget.Humanoid.Health <= 0 then
    		local ent = GetTarget() or KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
    			Range = Distance.Value,
    			Part = 'RootPart',
    			Wallcheck = Targets.Walls.Enabled,
    			Players = Targets.Players.Enabled,
    			NPCs = Targets.NPCs.Enabled,
    			Sort = sortmethods[Sort.Value],
    		})
    		if ent then
    			started = tick()
    		end
    		lasttarget = ent
    	end
    	return lasttarget
    end

    AimAssist = vape.Categories.Combat:CreateModule({
    	Name = 'Aim Assist',
    	Function = function(callback)
    		if callback then
    			local rotate = 0
    			
    			AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
    				if entitylib.isAlive then
    					entitylib.character.Humanoid.AutoRotate = tick() > rotate

    					local ent = getAttackData()
    					if ent then
    						local root = entitylib.character.RootPart
    						local delta = (ent.RootPart.Position - root.Position)
    						local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
    						local horizontal = delta * Vector3.new(1, 0, 1)
    						local angle = localfacing.Magnitude > 0 and horizontal.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(horizontal.Unit), -1, 1)) or 0
    						if angle >= (math.rad(AngleSlider.Value) / 2) then
    							return
    						end
    						targetinfo.Targets[ent] = tick() + 1

    						local firstPerson = entitylib.character.Head.LocalTransparencyModifier == 1
    						local perspective = AimMode.Value

    						if perspective == 'Mouse' then
    							local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
    							local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
    							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
    							mousemoverel(pos.X, pos.Y)
    						elseif perspective == 'First person' or (perspective == 'Dynamic' and firstPerson) then
    							if not firstPerson then return end
    							local cframe = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
    							gameCamera.CFrame = cframe
    						elseif perspective == 'Third person' or (perspective == 'Dynamic' and not firstPerson) then
    							if firstPerson then return end
    							local cframe = aimfuncs[Mode.Value](root.CFrame, ent, dt)
    							local direction = cframe.LookVector * Vector3.new(1, 0, 1)
    							if direction.Magnitude > 0 then
    								entitylib.character.Humanoid.AutoRotate = false
    								root.CFrame = CFrame.lookAlong(root.Position, direction)
    								rotate = tick() + 0.1
    							end
    						end
    					end
    				end
    			end))
    		else
    			if entitylib.isAlive then
    				entitylib.character.Humanoid.AutoRotate = true
    			end
    		end
    	end,
    	Tooltip = 'Smoothly aims to closest valid target with sword'
    })
    local modes = {}
    for i in aimfuncs do
    	table.insert(modes, i)
    end
    AimMode = AimAssist:CreateDropdown({
    	Name = 'Aim perspective',
    	Tooltip = 'First person - Uses your camera to aim\nThird person - Moves your character to where your supposed to look\nMouse - Moves your mouse & camera\nDynamic - Uses first person mode if ur in first person, and uses third person if ur in third person',
    	List = {'First person', 'Third person', 'Dynamic'},
    	Default = 'First person'
    })
    Mode = AimAssist:CreateDropdown({
    	Name = 'Mode',
    	List = modes,
    	Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
    	Default = modes[1],
    })
    Targets = AimAssist:CreateTargets({
    	Players = true,
    	Walls = true,
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
    	if not table.find(methods, i) then
    		table.insert(methods, i)
    	end
    end
    ClickAim = AimAssist:CreateToggle({
    	Name = 'Click aim',
    	Default = true,
    })
    Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
    StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
    BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
    KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
    AimSpeed = AimAssist:CreateSlider({
    	Name = 'Aim speed',
    	Min = 1,
    	Max = 20,
    	Default = 6,
    })
    Distance = AimAssist:CreateSlider({
    	Name = 'Distance',
    	Min = 1,
    	Max = 30,
    	Default = 30,
    	Suffix = function(val)
    		return val == 1 and 'stud' or 'studs'
    	end,
    })
    Shake = AimAssist:CreateSlider({
    	Name = 'Shake',
    	Min = 0,
    	Max = 100,
    	Default = 0,
    	Tooltip = 'Adds random jitter to simulate human aim',
    })
    AngleSlider = AimAssist:CreateSlider({
    	Name = 'Max angle',
    	Min = 1,
    	Max = 360,
    	Default = 70,
    })
    Limit = AimAssist:CreateToggle({
    	Name = 'Limit to items',
    	Tooltip = 'Only attacks when sword is held',
    })
    Sort = AimAssist:CreateDropdown({
    	Name = 'Target mode',
    	List = methods,
    	Default = 'Angle',
    })
    AimPart = AimAssist:CreateDropdown({
    	Name = 'Target area',
    	List = {'Center', 'Closest'},
    	Default = 'Center',
    })
end)

run(function()
    local AutoClicker
    local CPS
    local BlockCPS
    local Wool
    local Thread

    local function AutoClick()
    	if Thread then
    		task.cancel(Thread)
    	end

    	Thread = task.delay(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue(), function()
    		repeat
    			if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
    				local blockPlacer = bedwars.BlockPlacementController.blockPlacer
    				local tool = store.hand.tool
    				if store.hand.toolType == 'block' and blockPlacer and tool and (not Wool.Enabled or tool.Name:find('wool')) then
    					if inputService.TouchEnabled then
    						task.spawn(function()
    							blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
    						end)
    					else
    						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
    							local mouseinfo
    							if canDebug then
    								mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
    							else
    								mouseinfo = {placementPosition = lplr:GetMouse().Hit.Position}
    							end
    							if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
    								if canDebug then
    									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
    								else
    									bedwars.placeBlock(({getPlacedBlock(mouseinfo.placementPosition)})[2])
    								end
    							end
    						end
    					end
    				elseif store.hand.toolType == 'sword' then
    					bedwars.SwordController:swingSwordAtMouse(0.39)
    				end
    			end

    			task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue()) --
    		until not AutoClicker.Enabled
    	end)
    end

    AutoClicker = vape.Categories.Combat:CreateModule({
    	Name = 'Auto Clicker',
    	Function = function(callback)
    		if callback then
    			local function stopClick()
    				if Thread then
    					task.cancel(Thread)
    					Thread = nil
    				end
    			end

    			AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
    				if input.UserInputType == Enum.UserInputType.MouseButton1 then
    					AutoClick()
    				end
    			end))

    			AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
    				if input.UserInputType == Enum.UserInputType.MouseButton1 then
    					stopClick()
    				end
    			end))

    			if inputService.TouchEnabled then
    				AutoClicker:Clean(task.spawn(function()
    					local mobileUI = lplr.PlayerGui:WaitForChild('MobileUI', 10)
    					if not mobileUI then return end

    					for _, name in {'2', '5'} do
    						local button = mobileUI:WaitForChild(name, 5)
    						if button then
    							AutoClicker:Clean(button.MouseButton1Down:Connect(AutoClick))
    							AutoClicker:Clean(button.MouseButton1Up:Connect(stopClick))
    						end
    					end
    				end))
    			end
    		else
    			if Thread then
    				task.cancel(Thread)
    				Thread = nil
    			end
    		end
    	end,
    	Tooltip = 'Hold attack button to automatically click',
    })
    CPS = AutoClicker:CreateTwoSlider({
    	Name = 'CPS',
    	Min = 1,
    	Max = 9,
    	DefaultMin = 7,
    	DefaultMax = 7,
    })
    AutoClicker:CreateToggle({
    	Name = 'Place Blocks',
    	Default = true,
    	Function = function(callback)
    		if BlockCPS and BlockCPS.Object then
    			BlockCPS.Object.Visible = callback
    		end
    		if Wool and Wool.Object then
    			Wool.Object.Visible = callback
    		end
    	end,
    })
    BlockCPS = AutoClicker:CreateTwoSlider({
    	Name = 'Block CPS',
    	Min = 1,
    	Max = 20,
    	DefaultMin = 12,
    	DefaultMax = 12,
    	Darker = true,
    })
    Wool = AutoClicker:CreateToggle({
    	Name = 'Wool only',
    	Darker = true,
    	Tooltip = 'Only autoclick placing with wool.'
    })
end)

run(function()
    local NoClickDelay
    local old, newClickCheck

    NoClickDelay = vape.Categories.Combat:CreateModule({
        Name = 'No Click Delay',
        Function = function(callback)
            if callback then
                local original = bedwars.SwordController.isClickingTooFast
                old = original
                newClickCheck = function(self)
                    if not NoClickDelay.Enabled then
                        return original(self)
                    end
                    self.lastSwing = os.clock()
                    return false
                end
                bedwars.SwordController.isClickingTooFast = newClickCheck
            else
                if old and bedwars.SwordController.isClickingTooFast == newClickCheck then
                    bedwars.SwordController.isClickingTooFast = old
                end
                old = nil
                newClickCheck = nil
            end
        end,
        Tooltip = 'Remove the CPS cap'
    })
end)

run(function()
    if canDebug then
    	run(function()
    		local BlockReach
    		local BlockRange
    		local BreakReach
    		local BreakRange
    		local SwordReach
    		local SwordRange

    		local old

    		Reach = vape.Categories.Combat:CreateModule({
    			Name = 'Reach',
    			Tooltip = 'Allows you to place, attack, and break further',
    			Function = function(callback)
    				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
    				if callback then
    					old = bedwars.BlockSelector.getMouseInfo
    					bedwars.BlockSelector.getMouseInfo = function(...)
    						local Self, Select, Args = ...
    						if not Args then
    							Args = {}
    						end
    						if Select == 0 then
    							Args.range = BlockReach.Enabled and BlockRange.Value or 24
    						elseif Select == 1 then
    							Args.range = BreakReach.Enabled and BreakRange.Value or 18
    						end
    						return old(Self, Select, Args)
    					end
    				else
    					bedwars.BlockSelector.getMouseInfo = old
    					old = nil
    				end
    			end,
    		})
    		SwordReach = Reach:CreateToggle({
    			Name = 'Sword Reach',
    			Default = true,
    			Function = function(callback)
    				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
    				pcall(function()
    					SwordRange.Object.Visible = callback
    				end)
    			end,
    		})
    		SwordRange = Reach:CreateSlider({
    			Name = 'Sword Range',
    			Min = 1,
    			Max = 18,
    			Default = 18,
    			Decimal = 5,
    			Darker = true,
    			Suffix = function(val)
    				return val <= 1 and 'stud' or 'studs'
    			end,
    			Function = function(val)
    				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
    			end,
    		})
    		BlockReach = Reach:CreateToggle({
    			Name = 'Placement Reach',
    			Function = function(callback)
    				BlockRange.Object.Visible = callback
    			end,
    		})
    		BlockRange = Reach:CreateSlider({
    			Name = 'Placement Range',
    			Min = 1,
    			Max = 60,
    			Default = 18,
    			Darker = true,
    			Suffix = function(val)
    				return val <= 1 and 'stud' or 'studs'
    			end,
    			Visible = false,
    		})
    		BreakReach = Reach:CreateToggle({
    			Name = 'Break Reach',
    			Function = function(callback)
    				BreakRange.Object.Visible = callback
    			end,
    		})
    		BreakRange = Reach:CreateSlider({
    			Name = 'Break Range',
    			Min = 1,
    			Max = 30,
    			Default = 30,
    			Decimal = 5,
    			Darker = true,
    			Suffix = function(val)
    				return val <= 1 and 'stud' or 'studs'
    			end,
    			Visible = false,
    		})
    		Reach:CreateButton({
    			Name = 'Reset to default reach',
    			Tooltip = 'Resets every range back to default',
    			Function = function()
    				BreakRange:SetValue(18)
    				BlockRange:SetValue(24)
    				SwordRange:SetValue(12.4)
    			end,
    		})
    	end)
    else
    	local Value
    	local rayParams = RaycastParams.new()
    	rayParams.RespectCanCollide = true

    	Reach = vape.Categories.Combat:CreateModule({
    		Name = 'Reach',
    		Function = function(callback)
    			if callback then
    				Reach:Clean(vapeEvents.CEAttacked.Event:Connect(function()
    					local doAttack
    					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
    						if
    							entitylib.isAlive
    							and store.hand.toolType == 'sword'
    							and bedwars.DaoController.chargingMaid == nil
    						then
    							local attackRange = Value.Value + 2
    							rayParams.FilterDescendantsInstances = { lplr.Character }

    							local unit = lplr:GetMouse().UnitRay
    							local localPos = entitylib.character.RootPart.Position
    							local rayRange = (attackRange or 14.4)
    							local ray = workspace:Raycast(unit.Origin, unit.Direction * 200, rayParams)
    							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
    								for _, ent in entitylib.List do
    									doAttack = ent.Targetable
    										and ray.Instance:IsDescendantOf(ent.Character)
    										and (localPos - ent.RootPart.Position).Magnitude <= rayRange
    									if doAttack then
    										break
    									end
    								end
    							end

    							local region = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
    							if doAttack then
    								doAttack = region
    							end
    							if doAttack then
    								local selfpos = entitylib.character.RootPart.Position
    								local delta = (doAttack.RootPart.Position - selfpos)
    								local dir = CFrame.lookAt(selfpos, doAttack.RootPart.Position).LookVector
    								local pos = selfpos + dir * math.max(delta.Magnitude - 14.4, 0)

    								bedwars.Client:Get('SwordHit'):SendToServer({
    									weapon = store.hand.tool,
    									chargedAttack = {chargeRatio = 0},
    									entityInstance = doAttack.Character,
    									validate = {
    										raycast = {},
    										targetPosition = {value = doAttack.RootPart.Position},
    										selfPosition = {value = pos},
    									},
    								})
    							end
    						end
    					end
    				end))
    			end
    		end,
    	})
    	Value = Reach:CreateSlider({
    		Name = 'Range',
    		Min = 0,
    		Max = 18,
    		Default = 18,
    		Suffix = function(val)
    			return val == 1 and 'stud' or 'studs'
    		end,
    	})
    end
end)

run(function()
    local ShopQuickBuy -- coded by seven
    local HoldDelay
    local CPS

    local holding = false
    local clickThread

    local function getShopId()
        if not entitylib.isAlive then return nil end
        local localPosition = entitylib.character.RootPart.Position
        local id
        for _, v in store.shop do
            if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                id = v.Id
            end
        end
        return id
    end

    local function getHoveredItem()
        local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
            local obj = v
            while obj and obj ~= lplr.PlayerGui do
                local itemType = obj.Name:match('^(.+)_ShopItemCard$')
                if itemType then
                    return itemType
                end
                obj = obj.Parent
            end
        end
    end

    local function canBuy(item)
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
                return false
            end
        end
        local currency = getItem(item.currency)
        return (currency and currency.amount or 0) >= item.price
    end

    local function purchase(itemType, shopId)
        if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end

        local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
        if not item or not canBuy(item) then return end

        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
            shopItem = item,
            shopId = shopId
        }):andThen(function(suc)
            if not suc then return end
            bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
            bedwars.Store:dispatch({
                type = 'BedwarsAddItemPurchased',
                itemType = itemType
            })
            if item.tiered then
                bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
            end
        end)
    end

    local function startClicking(itemType)
        if clickThread then
            task.cancel(clickThread)
        end
        clickThread = task.spawn(function()
            repeat
                local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end

    ShopQuickBuy = vape.Categories.Combat:CreateModule({
        Name = 'Shop Clicker',
        Function = function(callback)
            if callback then
                ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end

                    local itemType = getHoveredItem()
                    if not itemType then return end

                    holding = true
                    task.delay(HoldDelay.Value, function()
                        if holding and getHoveredItem() == itemType then
                            startClicking(itemType)
                        end
                    end)
                end))

                ShopQuickBuy:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        holding = false
                    end
                end))
            else
                holding = false
                if clickThread then
                    task.cancel(clickThread)
                    clickThread = nil
                end
            end
        end,
        Tooltip = 'Hold on a shop item to rapidly buy it.'
    })
    HoldDelay = ShopQuickBuy:CreateSlider({
        Name = 'Hold Delay',
        Min = 0,
        Max = 1,
        Default = 0.15,
        Decimal = 20,
        Suffix = 'seconds'
    })
    CPS = ShopQuickBuy:CreateSlider({
        Name = 'CPS',
        Min = 1,
        Max = 20,
        Default = 20,
        Darker = true
    })
end)

run(function()
    local Sprint
    local old, newStop

    Sprint = vape.Categories.Combat:CreateModule({
        Name = 'Sprint',
        Function = function(callback)
            if callback then
                local original = bedwars.SprintController.stopSprinting
                old = original
                newStop = function(...)
                    local call = original(...)
                    if Sprint.Enabled then
                        bedwars.SprintController:startSprinting()
                    end
                    return call
                end
                bedwars.SprintController.stopSprinting = newStop
                Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
                    task.delay(0.1, function() 
                        if Sprint.Enabled then
                            bedwars.SprintController:stopSprinting()
                        end
                    end) 
                end))
                bedwars.SprintController:stopSprinting()
            else
                if inputService.TouchEnabled then 
    				local mobile = lplr.PlayerGui:FindFirstChild('MobileUI')
    				local button = mobile and mobile:FindFirstChild('4')
    				if button then button.Visible = true end
                end
                if old and bedwars.SprintController.stopSprinting == newStop then
                    bedwars.SprintController.stopSprinting = old
                end
                bedwars.SprintController:stopSprinting()
                old = nil
                newStop = nil
            end
        end,
        Tooltip = 'Sets your sprinting to true.'
    })
end)

run(function()
    local TriggerBot
    local CPS
    local rayParams = RaycastParams.new()

    TriggerBot = vape.Categories.Combat:CreateModule({
        Name = 'Trigger Bot',
        Function = function(callback)
            if callback then
                repeat
                    local doAttack
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
                            local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
                            rayParams.FilterDescendantsInstances = {lplr.Character}

                            local unit = lplr:GetMouse().UnitRay
                            local localPos = entitylib.character.RootPart.Position
                            local rayRange = (attackRange or 14.4)
                            local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
                            if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
                                local limit = (attackRange)
                                for _, ent in entitylib.List do
                                    doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
                                    if doAttack then
                                        break
                                    end
                                end
                            end

                            doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
                            if doAttack then
                                bedwars.SwordController:swingSwordAtMouse()
                            end
                        end
                    end

                    task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
                until not TriggerBot.Enabled
            end
        end,
        Tooltip = 'Automatically swings when hovering over a entity'
    })
    CPS = TriggerBot:CreateTwoSlider({
        Name = 'CPS',
        Min = 1,
        Max = 9,
        DefaultMin = 7,
        DefaultMax = 7
    })
end)

run(function()
    local Velocity
    local Horizontal
    local Vertical
    local Chance
    local TargetCheck
    local rand, old = Random.new()

    Velocity = vape.Categories.Combat:CreateModule({
        Name = 'Velocity',
        Function = function(callback)
            if callback then
                old = bedwars.KnockbackUtil.applyKnockback
                bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
                    if rand:NextNumber(0, 100) > Chance.Value then return end
                    local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
                        Range = 50,
                        Part = 'RootPart',
                        Players = true
                    })

                    if check then
                        knockback = knockback or {}
                        if Horizontal.Value == 0 and Vertical.Value == 0 then return end
                        knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
                        knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
                    end
                    
                    return old(root, mass, dir, knockback, ...)
                end
            else
                bedwars.KnockbackUtil.applyKnockback = old
            end
        end,
        Tooltip = 'Reduces knockback taken'
    })
    Horizontal = Velocity:CreateSlider({
        Name = 'Horizontal',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%'
    })
    Vertical = Velocity:CreateSlider({
        Name = 'Vertical',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%'
    })
    Chance = Velocity:CreateSlider({
        Name = 'Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%'
    })
    TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)

--[[
    Blatant
]]

run(function()
    local AntiDeath
    local StopThreshold
    local Threshold
    local Notify
    local Delay
    local Mode

    local oldroot, clone, hip = nil, nil, 2.7

    local function createClone()
        if store.rootpart then return false end
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and (not oldroot or not oldroot.Parent) then
            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            lplr.Character.Parent = replicatedStorage
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 1
            oldroot.Parent = workspace
            store.rootpart = oldroot
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            bedwars.QueryUtil:setQueryIgnored(clone, true)
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            return true
        end
        return false
    end

    local function destroyClone()
        local char = lplr.Character
        if oldroot and oldroot.Parent and char then 
            char.Parent = replicatedStorage
            oldroot.Parent = char
            if clone then
                clone:Destroy()
                clone = nil
            end
            char.PrimaryPart = oldroot
            char.Parent = workspace
            oldroot.CanCollide = true
            local humanoid = char:FindFirstChildOfClass('Humanoid')
            if humanoid then
                humanoid.HipHeight = hip or 2.6
            end
            oldroot.Transparency = 1
            oldroot = nil
            store.rootpart = nil
            return true
        end
        if clone then
            clone:Destroy()
            clone = nil
        end
        oldroot = nil
        store.rootpart = nil
        return false
    end

    local Paused, Activated = 0, 0

    AntiDeath = vape.Categories.Blatant:CreateModule({
        Name = 'Anti Death',
        Function = function(call)
            if call then
                local FloatTime = tick();

                AntiDeath:Clean(runService.PreSimulation:Connect(function()
                    if oldroot and oldroot.Parent then
                        if (tick() - entitylib.character.AirTime) > 1.7 then
                            FloatTime = tick() + 0.2
                        end
                        oldroot.Velocity = Vector3.new(0, 1, 0)
                        oldroot.CFrame = clone.CFrame - (tick() > FloatTime and Vector3.new(0, 200, 0) or Vector3.zero)
                    end
                end))

                repeat
                    if os.clock() > Paused and entitylib.isAlive and (entitylib.character.Humanoid.Health <= Threshold.Value) then
                        if (os.clock() - Activated) >= Delay.Value then
                            Activated = os.clock()

                            if Notify.Enabled then
                                notif('AntiDeath', 'Health below ' .. tostring(Threshold.Value) .. '%', 12, 'warning')
                            end

                            if Mode.Value == 'Teleport' then
                                lplr.Character.PrimaryPart.CFrame += Vector3.new(0, 100, 0)
                                Paused = os.clock() + 5
                            elseif Mode.Value == 'Invincibility' then
                                if createClone() then
                                    Paused = os.clock() + 5
                                    task.delay(0, function()
                                        repeat task.wait() until not AntiDeath.Enabled or not entitylib.isAlive or (entitylib.character.Humanoid.Health >= StopThreshold.Value)
                                        local old = clone and clone.CFrame or nil
                                        if destroyClone() and old then
                                            entitylib.character.RootPart.CFrame = old
                                        end
                                        Paused = os.clock() + 5

                                        if AntiDeath.Enabled and Notify.Enabled then
                                            notif('AntiDeath', 'You are visible again', 12, 'info')
                                        end
                                    end)
                                end
                            end
                        end
                    end
                    task.wait()
                until not AntiDeath.Enabled
            else
                destroyClone()
            end
        end,
        Tooltip = 'Uses selected mode when on a threshold',
    })

    Mode = AntiDeath:CreateDropdown({
        Name = 'Mode',
        List = {'Teleport', 'Invincibility'},
        Default = 'Invincibility',
        Tooltip = 'Teleport - Teleports you high up\nInvincibility - Makes you unhittable'
    })
    StopThreshold = AntiDeath:CreateSlider({
        Name = 'Stop Threshold',
        Min = 1,
        Max = 100,
        Default = 30,
        Suffix = function()
            return '%'
        end,
        Tooltip = 'Health percentage to untrigger at'
    })
    Threshold = AntiDeath:CreateSlider({
        Name = 'Threshold',
        Min = 1,
        Max = 100,
        Default = 30,
        Suffix = function()
            return '%'
        end,
        Tooltip = 'Health percentage to trigger at'
    })
    Delay = AntiDeath:CreateSlider({
        Name = 'Delay',
        Min = 1,
        Max = 20,
        Default = 5,
        Suffix = function(val)
            return val <= 1 and 'sec' or 'secs'
        end,
        Tooltip = 'Delay between triggers'
    })
    Notify = AntiDeath:CreateToggle({
        Name = 'Notify on trigger',
        Default = true
    })
end)

run(function()
    local AntiFall
    local Mode
    local Material
    local Color
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true

    local function getLowGround()
        local mag = math.huge
        for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
            pos = pos * 3
            if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
                mag = pos.Y
            end
        end
        return mag
    end

    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'Anti Fall',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end

                local pos, debounce = getLowGround(), tick()
                if pos ~= math.huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = Vector3.new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    connection = runService.PreSimulation:Connect(function()
                                        if vape.Modules.Fly.Enabled or InfiniteFly.Enabled or vape.Modules['Long Jump'].Enabled then
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                            return
                                        end

                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
                                            local root = entitylib.character.RootPart
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
                                            root.Velocity *= Vector3.new(1, 0, 1)
                                            rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                            rayCheck.CollisionGroup = root.CollisionGroup

                                            local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
                                            if ray then
                                                for _ = 1, 10 do
                                                    local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
                                                    if not getPlacedBlock(dpos) then
                                                        top = Vector3.new(top.X, pos.Y, top.Z)
                                                        break
                                                    end
                                                end
                                            end

                                            root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
                                            if not frictionTable.Speed then
                                                root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                            end

                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
            end
        end,
        Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
    })
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.CanCollide = val == 'Collide'
            end
        end,
    Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
    })
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })
end)

run(function()
    local AutoChargeProjectile
    local Charge
    local unregister

    local function unregisterCharge()
    	if unregister then
    		local callback = unregister
    		unregister = nil
    		callback()
    	end
    end

    AutoChargeProjectile = vape.Categories.Blatant:CreateModule({
    	Name = 'Auto Charge Projectile',
    	Function = function(callback)
    		if callback then
    			unregisterCharge()
    			unregister = bedwars.ProjectileCharge:Register('AutoChargeProjectile', function()
    				return Charge.Value
    			end, function()
    				return AutoChargeProjectile.Enabled
    			end)
    			AutoChargeProjectile:Clean(unregisterCharge)
    		else
    			unregisterCharge()
    		end
    	end,
    	Tooltip = 'Automatically releases chargeable projectiles at the selected charge'
    })

    Charge = AutoChargeProjectile:CreateSlider({
    	Name = 'Charge',
    	Min = 0,
    	Max = 100,
    	Default = 100,
    	Suffix = '%',
    	Function = function()
    		bedwars.ProjectileCharge:Refresh('AutoChargeProjectile')
    	end
    })
end)

run(function()
    local AutoDodge
    local Targets
    local Melee
    local Range

    local oldroot, clone, hip = nil, nil, 2.5
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Include
    rayParams.RespectCanCollide = true

    local function doClone()
        if store.rootpart then return end
        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
            if oldroot and oldroot.Parent then
                return true
            end

            hip = entitylib.character.Humanoid.HipHeight
            oldroot = entitylib.character.HumanoidRootPart
            if not lplr.Character.Parent then return false end
            lplr.Character.Parent = replicatedStorage
            clone = oldroot:Clone()
            clone.Parent = lplr.Character
            oldroot.Transparency = 1
            oldroot.Parent = workspace
            store.rootpart = oldroot
            lplr.Character.PrimaryPart = clone
            lplr.Character.Parent = workspace
            bedwars.QueryUtil:setQueryIgnored(clone, true)
            bedwars.QueryUtil:setQueryIgnored(oldroot, true)
            return true
        end
        return false
    end

    local function revertClone()
        local char = lplr.Character
        if oldroot and oldroot.Parent and char then
            char.Parent = replicatedStorage
            oldroot.Parent = char
            if clone then
                oldroot.CFrame = clone.CFrame
                oldroot.Velocity = clone.Velocity
                clone:Destroy()
                clone = nil
            end
            char.PrimaryPart = oldroot
            char.Parent = workspace
            oldroot.CanCollide = true
            local humanoid = char:FindFirstChildOfClass('Humanoid')
            if humanoid then humanoid.HipHeight = hip or 2.6 end
            oldroot.Transparency = 1
            oldroot = nil
            store.rootpart = nil
            return true
        end
        if clone then
            clone:Destroy()
            clone = nil
        end
        oldroot = nil
        store.rootpart = nil
        return false
    end

    AutoDodge = vape.Categories.Blatant:CreateModule({
    	Name = 'Auto Dodge',
    	Tooltip = 'Dodges melee and projectiles "blatantly"',
    	Function = function(call)
    		if call then
    			repeat
    				task.wait()
    			until store.matchState ~= 0 and store.map or not AutoDodge.Enabled
    			if not AutoDodge.Enabled then
    				return
    			end

    			rayParams.FilterDescendantsInstances = {store.map}
    			local lowestpoint = 9e9
    			local Dodge = false
    			for _, v in store.blocks do
    				local point = (v.Position.Y - (v.Size.Y / 2)) - 50
    				if point < lowestpoint then
    					lowestpoint = point
    				end
    			end

                AutoDodge:Clean(runService.PostSimulation:Connect(function()
    				if oldroot and oldroot.Parent and clone and clone.Parent then
                        local newpoint, pos = lowestpoint, CFrame.new(clone.CFrame.X, lowestpoint - 6, clone.CFrame.Z)
                        if Dodge then
                            newpoint = workspace:Raycast(pos.Position, Vector3.new(0, 1000, 0), rayParams)
                            if newpoint then
                                newpoint = CFrame.new(clone.CFrame.X, newpoint.Position.Y - 6, clone.CFrame.Z) * CFrame.Angles(math.rad(90), 0, 0)
                            end
                        end
                        oldroot.Velocity = Vector3.zero
                        oldroot.CFrame = Dodge and (newpoint or pos) or (clone.CFrame + Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(90), 0, 0)
                    end
                end))

                local last = true
                repeat
                    if entitylib.isAlive then
                        if oldroot then
                            local ownership = isnetworkowner(oldroot)
                            if not ownership and ownership ~= last then
                                notif('AutoDodge', 'Network ownership disowned', 7, 'alert')
                            end
                            last = ownership
                            if not ownership then
                                Dodge = false
                                revertClone()
                                task.wait()
                                continue
                            end
                        end

                        if Melee.Enabled and entitylib.EntityPosition({
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Sort = sortmethods.Distance,
                            Part = 'RootPart',
                        }) and doClone() then
                            Dodge = false
                            task.wait(0.2)
                            Dodge = true
                            task.wait(0.4)
                        else
                            Dodge = false
                            revertClone()
                        end
                    end
                    task.wait()
                until not AutoDodge.Enabled
    		else
    			revertClone()
    		end
    	end,
    })

    Targets = AutoDodge:CreateTargets({
    	Players = true,
    	NPCs = false,
    })
    Melee = AutoDodge:CreateToggle({
    	Name = 'Melee',
    	Tooltip = 'Dodges melee attacks',
    	Default = true,
    	Function = function(call)
    		pcall(function()
    			Range.Object.Visible = call
    		end)
    	end,
    })
    Range = AutoDodge:CreateSlider({
    	Name = 'Melee Range',
    	Min = 1,
    	Max = 30,
    	Default = 30,
    	Decimal = 5,
    	Darker = true,
    })
    AutoDodge:CreateToggle({
    	Name = 'Projectiles',
    	Tooltip = 'Dodges projectiles',
    	Default = true,
    })
end)

run(function()
    local AutoKaida
    local Targets
    local SwingRange
    local AttackRange
    local Sort
    local Limit
    local Swing
    local Mouse
    local GUI
    local Perfect
    local Distance

    local function getAttackData()
        local claw = (Limit.Enabled and store.hand.tool and store.hand) or not Limit.Enabled and getItem('summoner_claw', nil, true)
        if claw and claw.tool.Name:find('summoner_claw') then
            if Mouse.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                return false
            end
            if GUI.Enabled and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                return false
            end
            return claw
        end
        return false
    end

    AutoKaida = vape.Categories.Blatant:CreateModule({
        Name = 'Auto Kaida',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive and (workspace:GetServerTimeNow() - bedwars.SummonerClawHandController.lastAttackTime) > bedwars.SummonerKitBalance.CLAW_COOLDOWN then
                        local claw = getAttackData()
                        if claw then
                            local ent = entitylib.EntityPosition({
                                Range = SwingRange.Value,
                                Wallcheck = Targets.Walls.Enabled or nil,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Sort = sortmethods[Sort.Value]
                            })
                            if ent then
                                local selfpos = entitylib.character.RootPart.Position
                                local dir = CFrame.lookAt(selfpos, ent.RootPart.Position).LookVector
                                local delta = (ent.RootPart.Position - selfpos)

                                if Perfect.Enabled and (selfpos - ent.RootPart.Position).Magnitude <= Distance.Value then
                                    if bedwars.AbilityController:canUseAbility('summoner_start_charging') and bedwars.AbilityController:canUseAbility('summoner_finish_charging') then
                                        bedwars.AbilityController:useAbility('summoner_start_charging')
                                        task.wait(0.5)
                                        bedwars.AbilityController:useAbility('summoner_finish_charging')
                                        if not Swing.Enabled then
                                            continue
                                        end
                                    end
                                end

                                if not Swing.Enabled then
                                    local active = false
                                    for _, v in workspace:QueryDescendants('#Summoner_SummonCircle') do
                                        local pivot = v:FindFirstChild('Pivot')
                                        if pivot and math.floor(pivot.Position.X) == math.floor(entitylib.character.RootPart.Position.X) and math.floor(pivot.Position.Z) == math.floor(entitylib.character.RootPart.Position.Z) then
                                            active = true
                                            break
                                        end
                                    end
                                    if active then
                                        task.wait()
                                        continue
                                    end
                                end

                                if (selfpos - ent.RootPart.Position).Magnitude <= AttackRange.Value then
                                    bedwars.Client:Get('SummonerClawAttackRequest'):SendToServer({
                                        position = selfpos + dir * math.max(delta.Magnitude - 16.399, 0),
                                        direction = dir,
                                        clientTime = workspace:GetServerTimeNow()
                                    })
                                end
                                bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
                                bedwars.SummonerClawController:clawAttack(lplr, selfpos, dir, claw.tool.Name)
                            end
                        end
                    end
                    task.wait(0.1)
                until not AutoKaida.Enabled
            end
        end
    })

    Targets = AutoKaida:CreateTargets({Players = true})
    SwingRange = AutoKaida:CreateSlider({
        Name = 'Swing Range',
        Min = 1,
        Max = 32,
        Default = 32,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
    AttackRange = AutoKaida:CreateSlider({
        Name = 'Attack Range',
        Min = 1,
        Max = 32,
        Default = 32,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    Sort = AutoKaida:CreateDropdown({
        Name = 'Target mode',
        List = methods,
        Default = methods[2]
    })
    Mouse = AutoKaida:CreateToggle({Name = 'Require mouse down'})
    GUI = AutoKaida:CreateToggle({Name = 'GUI check'})
    Swing = AutoKaida:CreateToggle({
        Name = 'Swing during ability',
        Default = true,
        Tooltip = 'Continue claw attacks while charging ability'
    })
    Limit = AutoKaida:CreateToggle({Name = 'Limit to items'})
    Perfect = AutoKaida:CreateToggle({
        Name = 'Perfect ability',
        Function = function(callback)
            pcall(function()
                Distance.Object.Visible = callback
            end)
        end
    })
    Distance = AutoKaida:CreateSlider({
        Name = 'Distance',
    	Min = 3,
    	Max = 15,
    	Default = 6,
    	Visible = false,
    	Suffix = function(val)
    		return val <= 1 and 'stud' or 'studs'
    	end,
        Darker = true
    })
end)

run(function()
    local DamageBoost
    local stack

    DamageBoost = vape.Categories.Blatant:CreateModule({
    	Name = 'Damage Boost',
    	Function = function(callback)
    		if callback then
    			DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
    				if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not LongJump.Enabled then
    					local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
    					knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
    						vertical = 0,
    						horizontal = horizontal,
    					}).Magnitude * (0.9 + lplr:GetNetworkPing())
                        stack = tick() + (knockbackSpeed / 45)
                        knockbackBoost = tick() + (horizontal / 3.5)
    				end
    			end))
    		end
    	end,
        Tooltip = 'Makes you go slightly faster when damaged'
    })
end)

run(function()
    local FastBreak
    local BedCheck
    local Blacklist
    local Blacklisted
    local Time

    local newlist, old = {}, nil
    local function find(tab, ind)
    	for i, v in tab do
    		if v == ind or v:find(ind) then
    			return i
    		end
    	end
    	return nil
    end

    FastBreak = vape.Categories.Blatant:CreateModule({
    	Name = 'Fast Break',
    	Function = function(callback)
    		if callback then
    			old = bedwars.BlockBreaker.hitBlock
    			bedwars.BlockBreaker.hitBlock = function(self, ...)
    				local _, params = unpack({ ... })
    				pcall(function()
    					local block, info = nil, self.clientManager:getBlockSelector():getMouseInfo(1, {ray = params})
    					block = info and info.target and info.target.blockInstance or nil
    					if block and (not Blacklist.Enabled or not find(newlist, block.Name)) and (not BedCheck.Enabled or block.Name ~= 'bed') then
    						bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
    					end
    				end)

    				return old(self, ...)
    			end

    			repeat
    				if (tick() - store.lastHit) > 0.3 then
    					bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
    				end
    				task.wait(0.1)
    			until not FastBreak.Enabled
    		else
    			bedwars.BlockBreaker.hitBlock = old
    			bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
    		end
    	end,
    	Tooltip = 'Decreases block hit cooldown'
    })
    Time = FastBreak:CreateSlider({
    	Name = 'Break speed',
    	Min = 0,
    	Max = 0.3,
    	Default = 0.25,
    	Decimal = 100,
    	Suffix = 'seconds',
    })
    BedCheck = FastBreak:CreateToggle({
    	Name = 'Bed Check',
    	Tooltip = "Doesn't increase speed if ur breaking a bed",
    })
    Blacklist = FastBreak:CreateToggle({
    	Name = 'Use blacklist',
    	Function = function(callback)
    		if Blacklisted and Blacklisted.Object then
    			Blacklisted.Object.Visible = callback
    		end
    	end,
    })
    Blacklisted = FastBreak:CreateTextList({
    	Name = 'Blocks',
    	Darker = true,
    	Visible = false,
    	Function = function(list)
    		newlist = {}
    		for _, v in list do
    			if v:find('iron') then
    				table.insert(newlist, 'iron_ore_mesh_block')
    			else
    				table.insert(newlist, v)
    			end
    		end
    	end,
    })
end)

run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old, newDeflate = 0, 0

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                local original = bedwars.BalloonController.deflateBalloon
                up, down, old = 0, 0, original
                newDeflate = function(...)
                    if not Fly.Enabled then
                        return original(...)
                    end
                end
                bedwars.BalloonController.deflateBalloon = newDeflate
                local tpTick, tpToggle, oldy = tick(), true

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end
                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                        bedwars.BalloonController:inflateBalloon()
                    end
                end))
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
                        local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
                        local mass = (0.9 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
                        local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
                        rayCheck.CollisionGroup = root.CollisionGroup

                        if WallCheck.Enabled then
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then
                                destination = ((ray.Position + ray.Normal) - root.Position)
                            end
                        end

                        if not flyAllowed then
                            if tpToggle then
                                local airleft = (tick() - entitylib.character.AirTime)
                                if airleft > 1.7 then
                                    if not oldy then
                                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = tick() + 0.07
                                            root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < tick() then
                                        local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
                    end
                end))
                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                        end))
                    end)
                end
            else
                if old and bedwars.BalloonController.deflateBalloon == newDeflate then
                    bedwars.BalloonController.deflateBalloon = old
                end
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
                old = nil
                newDeflate = nil
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Makes you go zoom.'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true
    })
end)

run(function()
    local Mode
    local Expand
    local objects, set = {}
    local oldFunction, oldRange

    local function createHitbox(ent)
        if ent.Targetable and ent.Player then
            local hitbox = Instance.new('Part')
            hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
            hitbox.Position = ent.RootPart.Position
            hitbox.CanCollide = false
            hitbox.Massless = true
            hitbox.Transparency = 1
            hitbox.Parent = ent.Character
            local weld = Instance.new('Motor6D')
            weld.Part0 = hitbox
            weld.Part1 = ent.RootPart
            weld.Parent = hitbox
            objects[ent] = hitbox
        end
    end

    HitBoxes = vape.Categories.Blatant:CreateModule({
        Name = 'Hit Boxes',
        Function = function(callback)
            if callback then
                if Mode.Value == 'Sword' then
                    oldFunction = bedwars.SwordController.swingSwordInRegion
                    oldRange = debug.getconstant(oldFunction, 6)
                    debug.setconstant(oldFunction, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
                    HitBoxes:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
                        if objects[ent] then
                            objects[ent]:Destroy()
                            objects[ent] = nil
                        end
                    end))
                    for _, ent in entitylib.List do
                        createHitbox(ent)
                    end
                end
            else
                if set then
                    debug.setconstant(oldFunction, 6, oldRange)
                    set = nil
                    oldFunction = nil
                end
                for _, part in objects do
                    part:Destroy()
                end
                table.clear(objects)
            end
        end,
        Tooltip = 'Expands attack hitbox'
    })
    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function()
            if HitBoxes.Enabled then
                HitBoxes:Toggle()
                HitBoxes:Toggle()
            end
        end,
        Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
    })
    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 14.4,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    if oldFunction then
                        debug.setconstant(oldFunction, 6, (val / 3))
                    end
                else
                    for _, part in objects do
                        part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
                    end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
end)

run(function()
    local InfiniteFly
    local HiddenPart = Instance.new('Part')
    local lastUp = os.clock()
    HiddenPart.Parent = workspace
    HiddenPart.Transparency = 1
    HiddenPart.CanQuery = false
    HiddenPart.CanTouch = false
    HiddenPart.CanCollide = false
    HiddenPart.Anchored = true
    vape:Clean(HiddenPart)

    local oldTransparency = setmetatable({}, {__mode = 'k'})
    local cameraSubjects = setmetatable({}, {__mode = 'k'})
    local function doCharacterThing(char)
        if char then
            for _, value in char:GetDescendants() do
                if value:IsA('BasePart') then
                    if oldTransparency[value] == nil then
                        oldTransparency[value] = value.Transparency
                    end

                    value.Transparency = 1
                end
            end
        end
    end

    local function revertCharacter()
        for value, transparency in oldTransparency do
            if value.Parent then
                value.Transparency = transparency
            end
        end
        table.clear(oldTransparency)
    end

    local function updateCamera()
        local camera = workspace.CurrentCamera
        if camera and cameraSubjects[camera] == nil then
            cameraSubjects[camera] = camera.CameraSubject
            camera.CameraSubject = HiddenPart
        end
    end

    local function setupCharacter()
        if not InfiniteFly.Enabled or not entitylib.isAlive then return end
        local char = entitylib.character.Character
        local root = entitylib.character.RootPart
        local head = entitylib.character.Head
        doCharacterThing(char)
        HiddenPart.CFrame = (head or root).CFrame
        root.CFrame = CFrame.new(root.Position.X, 175, root.Position.Z)
        lastUp = os.clock()
    end

    InfiniteFly = vape.Categories.Blatant:CreateModule({
        Name = 'InfiniteFly',
        Function = function(callback)
            if callback then
                updateCamera()
                setupCharacter()
                InfiniteFly:Clean(entitylib.Events.LocalAdded:Connect(setupCharacter))

                InfiniteFly:Clean(runService.PreSimulation:Connect(function(dt: number)
                    updateCamera()
                    if not entitylib.isAlive then
                        return
                    end

                    if os.clock() - lastUp < 0.35 then
                        entitylib.character.RootPart.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame -= Vector3.new(0, 0.3 * dt)
                    end

                    HiddenPart.CFrame = CFrame.new(Vector3.new(entitylib.character.RootPart.Position.X, HiddenPart.CFrame.Y, entitylib.character.RootPart.Position.Z))

                    if entitylib.character.RootPart.CFrame.Y < -75 then
                        entitylib.character.RootPart.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.new(Vector3.new(entitylib.character.RootPart.CFrame.X, 210, entitylib.character.RootPart.CFrame.Z))
                        lastUp = os.clock()
                    end
                end))
            else
                revertCharacter()
                for camera, subject in cameraSubjects do
                    if camera.Parent and camera.CameraSubject == HiddenPart then
                        camera.CameraSubject = subject
                    end
                end
                table.clear(cameraSubjects)
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end
    })
end)

run(function()
    local InstantKill
    local Mode
    local Range
    local Place

    local function getTurret(localPosition)
        for _, v in store.blocks do
            if v.Name == 'camera_turret' and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= 30 then
                return v
            end
        end
        return nil
    end

    local function getPlacedPosition(pos)
        for _, v in {Vector3.new(3, 0, 0), Vector3.new(0, 0, 3)} do
            for i = 1, 10 do
                local ray = workspace:Blockcast(CFrame.new(pos + (v * i)), Vector3.new(3, 3, 3), Vector3.new(0, -30, 0), store.airRay)
                if ray and not getPlacedBlock(ray.Position) then
                    return roundPos(ray.Position)
                end
            end
        end
        return
    end

    InstantKill = vape.Categories.Blatant:CreateModule({
        Name = 'Instant Kill',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or not InstantKill.Enabled
                if not InstantKill.Enabled then return end
                if store.equippedKit ~= 'vulcan' then
                    notif('InstantKill', 'You need vulcan equipped for this!', 8, 'warning')
                    return
                end

                local delay, pickups = 0, {}
                repeat
                    if entitylib.isAlive and tick() > delay then
                        local localPosition = entitylib.character.RootPart.Position
                        local ent = entitylib.EntityPosition({
                            Origin = localPosition,
                            Range = Range.Value,
                            Part = 'RootPart',
                            Players = true,
                            Wallcheck = true,
                            Sort = sortmethods.Health,
                        })
                        if ent then
                            local turret = getTurret(localPosition)
                            local tablet = getItem('tablet')
                            if not turret and Place.Enabled then
                                local pos = getPlacedPosition(localPosition)
                                local item = getItem('camera_turret')
                                if pos and item then
                                    bedwars.placeBlock(pos, 'camera_turret', false)
                                    turret = getPlacedPosition(pos)
                                    if turret then
                                        table.insert(pickups, turret)
                                    end
                                end
                            end
                            if turret and tablet then
                                switchItem(tablet.tool)
                                for i = 1, 12 do
                                    task.spawn(function()
                                        bedwars.Client:Get('VulcanArtilleryMark'):CallServer(ent.Player)
                                    end)
                                end
                                delay = tick() + 2
                            end
                        end
                    end
                    if Mode.Value == 'On bind' then
                        if #pickups > 0 then
                            task.wait(0.1)
                            for _, v in pickups do
                            
                            end
                        end
                        InstantKill:Toggle()
                        break
                    end
                    task.wait(0.1)
                until not InstantKill.Enabled
            end
        end,
        Tooltip = 'Automatically uses turret to instant kill targets.'
    })

    Mode = InstantKill:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On bind'},
        Default = 'Toggle'
    })
    Range = InstantKill:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
    Place = InstantKill:CreateToggle({
        Name = 'Auto place',
        Tooltip = 'Automatically places turrets if can\'t find any on ground.',
        Default = true
    })
end)

run(function()
    vape.Categories.Blatant:CreateModule({
        Name = 'Keep Sprint',
        Function = function(callback)
            debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
            bedwars.SprintController:stopSprinting()
        end,
        Tooltip = 'Lets you sprint with a speed potion.'
    })
end)

run(function()
    local Value
    local CameraDir
    local start
    local JumpTick, JumpSpeed, Direction = tick(), 0
    local function getDirection(vec)
        local horizontal = Vector3.new(vec.X, 0, vec.Z)
        return horizontal.Magnitude > 0 and horizontal.Unit or Vector3.zero
    end
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function launchProjectile(item, pos, proj, speed, dir)
        if not pos then return end

        pos = pos - dir * 0.1
        local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
        switchItem(item.tool, 0)
        task.wait(0.1)
        bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
        if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
            local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
            shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then
                bedwars.SoundManager:playSound(shoot)
            end
        end
    end

    local LongJumpMethods = {
        cannon = function(_, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            bedwars.placeBlock(rounded, 'cannon', false)

            task.delay(0, function()
                local block, blockpos = getPlacedBlock(rounded)
                if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
                    local breaktype = bedwars.ItemMeta[block.Name].block.breakType
                    local tool = store.tools[breaktype]
                    if tool then
                        switchItem(tool.tool)
                    end

                    bedwars.Client:Get(remotes.CannonAim):SendToServer({
                        cannonBlockPos = blockpos,
                        lookVector = dir
                    })

                    local broken = 0.1
                    if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
                        broken = 0.4
                        bedwars.breakBlock(block, true, true)
                    end

                    task.delay(broken, function()
                        for _ = 1, 3 do
                            local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
                            if call then
                                bedwars.breakBlock(block, true, true)
                                JumpSpeed = 5.25 * Value.Value
                                JumpTick = tick() + 2.3
                                Direction = getDirection(dir)
                                break
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end,
        cat = function(_, _, dir)
            LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
                JumpSpeed = 4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = getDirection(dir)
                entitylib.character.RootPart.Velocity = Vector3.zero
            end))

            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
            end

            if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
                bedwars.AbilityController:useAbility('CAT_POUNCE')
            end
        end,
        fireball = function(item, pos, dir)
            launchProjectile(item, pos, 'fireball', 60, dir)
        end,
        grappling_hook = function(item, pos, dir)
            launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
        end,
        jade_hammer = function(item, _, dir)
            if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
            end

            if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
                bedwars.AbilityController:useAbility(item.itemType..'_jump')
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
                Direction = getDirection(dir)
            end
        end,
        tnt = function(item, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
            bedwars.placeBlock(rounded, item.itemType, false)
        end,
        wood_dao = function(item, pos, dir)
            if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
                repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
            end

            if LongJump.Enabled then
                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                switchItem(item.tool, 0.1)
                replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
                    direction = dir,
                    origin = pos,
                    weapon = item.itemType
                })
                JumpSpeed = 4.5 * Value.Value
                JumpTick = tick() + 2.4
                Direction = getDirection(dir)
            end
        end
    }
    for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
        LongJumpMethods[v] = LongJumpMethods.wood_dao
    end
    LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
    LongJumpMethods.siege_tnt = LongJumpMethods.tnt
    LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

    LongJump = vape.Categories.Blatant:CreateModule({
        Name = 'Long Jump',
        Function = function(callback)
            frictionTable.LongJump = callback or nil
            updateVelocity()
            if callback then
                LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
                        local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
                            vertical = 0,
                            horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
                        }).Magnitude * 1.1

                        if knockbackBoost >= JumpSpeed then
                            local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                            if not pos then return end
                            local vec = (entitylib.character.RootPart.Position - pos)
                            JumpSpeed = knockbackBoost
                            JumpTick = tick() + 2.5
                            Direction = getDirection(vec)
                        end
                    end
                end))
                LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
                    if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
                        local vec = entitylib.character.RootPart.CFrame.LookVector
                        JumpSpeed = 2.5 * Value.Value
                        JumpTick = tick() + 2.5
                        Direction = getDirection(vec)
                    end
                end))

                start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
                LongJump:Clean(runService.PreSimulation:Connect(function(dt)
                    local root = entitylib.isAlive and entitylib.character.RootPart or nil

                    if root and isnetworkowner(root) then
                        if JumpTick > tick() then
                            root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
                                root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
                            else
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
                            end
                            start = nil
                        else
                            if start then
                                root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
                            end
                            root.AssemblyLinearVelocity = Vector3.zero
                            JumpSpeed = 0
                        end
                    else
                        start = nil
                    end
                end))

                if store.hand and LongJumpMethods[store.hand.tool.Name] then
                    task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                    return
                end

                for i, v in LongJumpMethods do
                    local item = getItem(i)
                    if item or store.equippedKit == i then
                        task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                        break
                    end
                end
            else
                JumpTick = tick()
                Direction = nil
                JumpSpeed = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Lets you jump farther'
    })
    Value = LongJump:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 37,
        Default = 37,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    CameraDir = LongJump:CreateToggle({
        Name = 'Camera Direction'
    })
end)

run(function()
    local MouseTP
    local Movement
    local Mode

    local rayParams = RaycastParams.new()
    rayParams.RespectCanCollide = true
    rayParams.FilterType = Enum.RaycastFilterType.Include

    local MouseTPs = {
    	Items = function(position)
    		local item = getItem('telepearl') or getItem('fireball')
    		local localPosition = entitylib.character.RootPart.Position
    		if item then
    			if item.itemType == 'telepearl' then
    				local meta = bedwars.ProjectileMeta.telepearl
    				local calc = prediction.SolveTrajectory(localPosition, meta.launchVelocity, meta.gravitationalAcceleration, position, Vector3.zero, workspace.Gravity, 0, 0)
    				if calc then
    					position = calc
    				end

    				local shootPosition = (CFrame.new(localPosition, position) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    				switchItem(item.tool)
    				bedwars.Client:Get(remotes.FireProjectile):CallServerAsync(
    					item.tool,
    					'telepearl',
    					'telepearl',
    					shootPosition,
    					localPosition,
    					CFrame.lookAt(localPosition, position).LookVector * meta.launchVelocity,
    					httpService:GenerateGUID(true),
    					{
    						drawDurationSeconds = 1,
    						shotId = httpService:GenerateGUID(false),
    					},
    					workspace:GetServerTimeNow() - 0.045
    				)
    				:andThen(function(result)
    					if result then
    						bedwars.SoundManager:playSound('rbxassetid://6866223756')
    					end
    				end)
    				return true
    			elseif item.itemType == 'fireball' and (localPosition - Vector3.new(position.X, localPosition.Y, position.Z)).Magnitude <= 200 then
    				local root = entitylib.character.RootPart
    				local ray = workspace:Raycast(localPosition, Vector3.new(0, -1000, 0), rayParams)
    				if ray then
    					localPosition = ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
    					root.Velocity = Vector3.zero
    					root.CFrame = CFrame.new(localPosition)

    					MouseTP:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
    						if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
    							local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
    								vertical = 0,
    								horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
    							}).Magnitude * 1.1

    							if knockbackBoost >= 38 then
    								repeat
    									task.wait()
    								until (root.Position - position).Magnitude <= 1
    							end
    						end
    					end))

    					local shootPosition = (CFrame.new(localPosition, position) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    					switchItem(item.tool)
    					bedwars.Client:Get(remotes.FireProjectile):CallServerAsync(
    						item.tool,
    						'fireball',
    						'fireball',
    						shootPosition,
    						localPosition,
    						Vector3.new(0, -68, 0),
    						httpService:GenerateGUID(true),
    						{
    							drawDurationSeconds = 1,
    							shotId = httpService:GenerateGUID(false),
    						},
    						workspace:GetServerTimeNow() - 0.045
    					)
    					:andThen(function(result)
    						if result then
    							bedwars.SoundManager:playSound('rbxassetid://7192289445')
    						end
    					end)
    					task.wait(2.5)
    					return true
    				end
    			end
    		end
    		return false
    	end,
    	Kits = function() end
    }

    MouseTP = vape.Categories.Blatant:CreateModule({
    	Name = 'Mouse TP',
    	Function = function(callback)
    		if callback then
    			local position = nil
    			if Mode.Value == 'Mouse' then
    				local map
    				repeat
    					map = workspace:FindFirstChild('Map')
    					if not map then task.wait(0.1) end
    				until map or not MouseTP.Enabled
    				if not MouseTP.Enabled then return end
    				rayParams.FilterDescendantsInstances = {map}
    				local ray = cloneref(lplr:GetMouse()).UnitRay
    				ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayParams)
    				position = ray and ray.Position + Vector3.new(0, entitylib.isAlive and entitylib.character.HipHeight or 2, 0)
    			elseif Mode.Value == 'Player' then
    				local ent = entitylib.EntityMouse({
    					Range = math.huge,
    					Part = 'RootPart',
    					Players = true,
    				})
    				position = ent and ent.RootPart.Position
    			end

    			if position then
                        if Movement.Value == 'All' then
                        if not MouseTPs.Kits(position) and not MouseTPs.Items(position) then
                        notif('MouseTP', 'Couldn\'t find an item or a kit to teleport with', 5)
                    end
                    elseif not MouseTPs[Movement.Value](position) then
                        notif('MouseTP', "Couldn't find " .. Movement.Value:lower() .. " to teleport with", 5)
                    end
                    end
    			else
    				notif('MouseTP', 'No position found.', 5)
    			end
    			if MouseTP.Enabled then
    				MouseTP:Toggle()
    			end
    		end
    	end,
        Tooltip = 'Teleports to a selected position'
    })

    Mode = MouseTP:CreateDropdown({
    	Name = 'Mode',
    	List = {'Mouse', 'Player'},
    	Tooltip = 'Where you\'re going to teleport to',
    })
    Movement = MouseTP:CreateDropdown({
    	Name = 'Movement',
    	List = {'All', 'Kits', 'Items'},
    	Tooltip = 'All - Uses Kits & Items to teleport',
    })
end)

run(function()
    local old

    vape.Categories.Blatant:CreateModule({
        Name = 'No Slow',
        Function = function(callback)
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if callback then
                old = modifier.addModifier
                modifier.addModifier = function(self, tab)
                    if tab.moveSpeedMultiplier then
                        tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                    end
                    return old(self, tab)
                end

                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then
                        modifier:removeModifier(i)
                    end
                end
            else
                modifier.addModifier = old
                old = nil
            end
        end,
        Tooltip = 'Prevents slowing down when using items.'
    })
end)

run(function()
    local OwlAura
    local Targets
    local Range

    local function getProjectileMeta()
        local meta = table.clone(bedwars.ProjectileMeta.owl_projectile)
        return meta
    end

    OwlAura = vape.Categories.Blatant:CreateModule({
        Name = 'Owl Aura',
        Function = function(callback)
            if callback then
                local owls = collection('Owl', OwlAura, function(self, obj)
                    task.delay(1, function()
                        if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then
                            table.insert(self, obj)
                        end
                    end)
                end)
                repeat
                    if store.equippedKit ~= 'owl' then
                        task.wait(3)
                        continue
                    end

                    if entitylib.isAlive then
                        local owl = owls[1]
                        if owl then
                            local origin = owl.Part.Position
                            local plr = entitylib.EntityPosition({
                                Origin = origin,
                                Range = Range.Value,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Wallcheck = Targets.Walls.Enabled,
                                Sort = sortmethods.Health,
                            })

                            if plr then
                                local meta = getProjectileMeta()
                                local targetVelocity = plr.RootPart.AssemblyLinearVelocity
                                local targetAirborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
                                local calc, _, travelTime = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, targetVelocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
                                if calc and travelTime and travelTime <= (meta.lifetimeSec or 3) then
                                    local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
                                    bedwars.Client:Get('OwlAiming'):SendToServer({
                                        owl = owl.Part,
                                        starting = true,
                                    })
                                    bedwars.Client:Get('OwlFireProjectile'):SendToServer({
                                        ProjectileRefId = httpService:GenerateGUID(true),
                                        direction = dir,
                                        fromPosition = origin,
                                        initialVelocity = dir,
                                    })
                                    task.wait(lplr:GetNetworkPing())
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not OwlAura.Enabled
            else
                bedwars.Client:Get('OwlAiming'):SendToServer({
                    starting = false,
                })
            end
        end,
        Tooltip = 'Automatically shoots projectiles with whisper kit'
    })

    Targets = OwlAura:CreateTargets({
        Players = true,
        Wallcheck = true,
    })
    Range = OwlAura:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 50,
        Suffix = function(val)
            return val <= 0 and 'stud' or 'studs'
        end,
        Default = 50,
    })
end)

run(function()
    local PlayerAttach
    local Range
    local Targets

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    PlayerAttach = vape.Categories.Blatant:CreateModule({
        Name = 'Player Attach',
        Tooltip = 'Attachs you to the nearest target',
        Function = function(call)
            if call then
                repeat
                    if entitylib.isAlive then
                        local plr = entitylib.AllPosition({
                            Range = Range.Value,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Limit = 1,
                            Sort = function(a, b)
                                return a.Entity.Health < b.Entity.Health
                            end
                        })[1]
                        if plr then
                            rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}

                            entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(0, entitylib.character.RootPart.Size.Y / 2 + entitylib.character.Humanoid.HipHeight + 0.25 * 3, 0)
                            entitylib.character.RootPart.CFrame = plr.RootPart.CFrame + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero)
                        end
                    end
                    task.wait()
                until not PlayerAttach.Enabled
            end
        end
    })

    Targets = PlayerAttach:CreateTargets({
        Players = true,
        NPCs = true
    })

    Range = PlayerAttach:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 35,
        Default = 23,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
end)

run(function()
    local Prediction
    local AutoCharge
    local TargetPart
    local Targets
    local FOV
    local Sort
    local OtherProjectiles
    local Blacklist
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
    local visibilityCheck = RaycastParams.new()
    visibilityCheck.FilterType = Enum.RaycastFilterType.Exclude
    visibilityCheck.IgnoreWater = true
    local launchHook

    local function ignored(instance)
    	return (instance:IsA('BasePart') and not instance.CanCollide)
    		or collectionService:HasTag(instance, 'DontBlockProjectileRaycast')
    		or collectionService:HasTag(instance, 'block:no-collision')
    		or bedwars.QueryUtil:isQueryIgnored(instance)
    end

    local function getMousePosition()
    	if inputService.TouchEnabled then
    		return gameCamera.ViewportSize / 2
    	end
    	return inputService.GetMouseLocation(inputService)
    end

    local function getPosition(ent, proj)
    	if TargetPart.Value == 'Closest' then
    		local localPosition, magnitude, part = getMousePosition(), 9e9, nil
    		for _, v in ent:GetChildren() do
    			if pcall(function() return v.Position; end) then
    				local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)

    				if vis then
    					local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude

    					if mag < magnitude then
    						magnitude = mag
    						part = v
    					end
    				end
    			end
    		end
    		return part and part.Position or ent.PrimaryPart.Position
    	elseif TargetPart.Value == 'Dynamic' then
    		local tool = store.hand.tool
    		if tool and tool.Name:find('headhunter') then
    			return ent.Head.Position
    		end
    		return ent.PrimaryPart.Position
    	end
    	return
    end

    local ProjectileAimbot
    ProjectileAimbot = vape.Categories.Blatant:CreateModule({
    	Name = 'Projectile Aimbot',
    	Disabled = not canDebug,
    	Function = function(callback)
    		if callback then
    			oldd = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
    			launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileAimbot', 100, function(nextLaunch, ...)
    				local self, projmeta, worldmeta, origin, shootpos = ...
    				local plr = entitylib.EntityMouse({
    					Part = 'RootPart',
    					Range = FOV.Value,
    					Players = Targets.Players.Enabled,
    					NPCs = Targets.NPCs.Enabled,
    					Sort = sortmethods[Sort.Value or 'Distance'],
    					Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero,
    				})

    				if plr then
    					local pos = shootpos or self:getLaunchPosition(origin)
    					if not pos then
    						return nextLaunch(...)
    					end

    					if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
    						return nextLaunch(...)
    					end

    					if table.find(Blacklist.ListEnabled or {}, ((projmeta.projectile == 'glue_trap' or projmeta.projectile == 'glue_projectile') and 'gloop' or projmeta.projectile)) then
    						return nextLaunch(...)
    					end

    					local meta = projmeta:getProjectileMeta()
    					local overrides = meta.getProjectileOverridesFunction and meta.getProjectileOverridesFunction(projmeta.player)
    					local lifetime
    					if worldmeta then
    						lifetime = overrides and overrides.predictionLifetimeOverride or meta.predictionLifetimeSec
    					else
    						lifetime = overrides and overrides.lifetimeOverride or meta.lifetimeSec
    					end
    					lifetime = tonumber(lifetime) or 3
    					if lifetime ~= lifetime or lifetime <= 0 or lifetime == math.huge then
    						lifetime = 3
    					end
    					local gravity = (tonumber(meta.gravitationalAcceleration) or 196.2) * (tonumber(projmeta.gravityMultiplier) or 1)
    					local projSpeed = tonumber(overrides and overrides.launchVelocityOverride or meta.launchVelocity) or 100
    					local launchSpeed = projSpeed * bedwars.ProjectileCharge:GetLaunchMultiplier(projmeta, AutoCharge.Enabled)
    					local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
    					local balloons = plr.Character:GetAttribute('InflatedBalloons')
    					local playerGravity = workspace.Gravity

    					if balloons and balloons > 0 then
    						playerGravity = (workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975)))
    					end

    					if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
    						playerGravity = 6
    					end

    					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
    						for _, owl in collectionService:GetTagged('Owl') do
    							if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
    								playerGravity = 0
    							end
    						end
    					end

    					local targetpos = getPosition(plr.Character) or plr[TargetPart.Value].Position
    					local pearl = projmeta.projectile == 'telepearl'
    					local targetVelocity = pearl and Vector3.zero or plr.RootPart.AssemblyLinearVelocity
    					local targetAirborne
    					if pearl then
    						targetAirborne = false
    					elseif plr.Player then
    						targetAirborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
    					end
    					local function solve(minimum)
    						return prediction.SolveTrajectory(offsetpos, launchSpeed * Prediction.Value, gravity, targetpos, targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, targetAirborne, plr.RootPart.Position, plr.RootPart, minimum, true)
    					end
    					local calc, _, travelTime = solve()
    					local initialVelocity = calc and CFrame.new(offsetpos, calc).LookVector * launchSpeed
    					local validTime = type(travelTime) == 'number' and travelTime == travelTime and travelTime > 0 and travelTime < math.huge
    					visibilityCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
    					local visible = initialVelocity and validTime and travelTime <= lifetime and prediction.IsTrajectoryClear(offsetpos, initialVelocity, gravity, travelTime, visibilityCheck, plr.Character, ignored)
    					if not visible and validTime then
    						calc, _, travelTime = solve(travelTime + 1e-6)
    						initialVelocity = calc and CFrame.new(offsetpos, calc).LookVector * launchSpeed
    						validTime = type(travelTime) == 'number' and travelTime == travelTime and travelTime > 0 and travelTime < math.huge
    						visibilityCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
    						visible = initialVelocity and validTime and travelTime <= lifetime and prediction.IsTrajectoryClear(offsetpos, initialVelocity, gravity, travelTime, visibilityCheck, plr.Character, ignored)
    					end
    					if visible then
    						targetinfo.Targets[plr] = tick() + 1
    						return {
    							initialVelocity = initialVelocity,
    							positionFrom = offsetpos,
    							deltaT = lifetime,
    							gravitationalAcceleration = gravity,
    							drawDurationSeconds = bedwars.ProjectileCharge:GetDrawDuration(projmeta, AutoCharge.Enabled),
    						}
    					end
    					return nextLaunch(...)
    				end

    				return nextLaunch(...)
    			end)
    		else
    			if launchHook then
    				launchHook()
    				launchHook = nil
    			end
    		end
    	end,
    	Tooltip = 'Silently adjusts your aim towards the enemy',
    })
    Targets = ProjectileAimbot:CreateTargets({
    	Players = true,
    	Walls = true,
    })
    TargetPart = ProjectileAimbot:CreateDropdown({
    	Name = 'Part',
    	List = {'RootPart', 'Head', 'Dynamic', 'Closest'},
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
    	if not table.find(methods, i) then
    		table.insert(methods, i)
    	end
    end
    Sort = ProjectileAimbot:CreateDropdown({
    	Name = 'Target Mode',
    	List = methods,
    	Default = 'Distance',
    })
    Prediction = ProjectileAimbot:CreateSlider({
    	Name = 'Prediction',
    	Min = 0.1,
    	Max = 2,
    	Default = 1,
    	Decimal = 10,
    })
    FOV = ProjectileAimbot:CreateSlider({
    	Name = 'FOV',
    	Min = 1,
    	Max = 1000,
    	Default = 1000,
    })
    AutoCharge = ProjectileAimbot:CreateToggle({
    	Name = 'Auto Charge',
    	Default = true,
    	Tooltip = 'Fully charges your bow, Allowing your projectile to deal more damage',
    })
    OtherProjectiles = ProjectileAimbot:CreateToggle({
    	Name = 'Other Projectiles',
    	Default = true,
    	Function = function(call)
    		if Blacklist and Blacklist.Object then
    			Blacklist.Object.Visible = call
    		end
    	end,
    })
    Blacklist = ProjectileAimbot:CreateTextList({
    	Name = 'Blacklist',
    	Default = {'gloop', 'telepearl'},
    	Darker = true,
    	Placeholder = 'projectile',
    })
end)

run(function()
    local ProjectileAura
    local FireRate
    local Targets
    local Range
    local Sort
    local List
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local visibilityCheck = RaycastParams.new()
    visibilityCheck.FilterType = Enum.RaycastFilterType.Exclude
    visibilityCheck.IgnoreWater = true
    local projectileRemote
    local projectilePending, projectileThread
    local FireDelays = {}

    local function getAmmo(check)
    	for _, item in store.inventory.inventory.items do
    		if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
    			return item.itemType
    		end
    	end
    	return nil
    end
    local function getProjectiles()
    	local items = {}
    	for _, item in store.inventory.inventory.items do
    		local itemData = bedwars.ItemMeta[item.itemType]
    		local proj = itemData and itemData.projectileSource
    		local ammo = proj and getAmmo(proj)
    		if ammo and table.find(List.ListEnabled, ammo) then
    			table.insert(items, {
    				item,
    				ammo,
    				proj.projectileType(ammo),
    				proj,
    			})
    		end
    	end
    	return items
    end

    local function getTarget()
    	local plrs = entitylib.AllPosition({
    		Part = 'RootPart',
    		Range = Range.Value,
    		Sort = sortmethods[Sort.Value],
    		Players = Targets.Players.Enabled,
    		NPCs = Targets.NPCs.Enabled,
    		Limit = 10
    	})
    	if #plrs > 0 then
    		return plrs[1]
    	end
    	return nil
    end

    local function ignored(instance)
    	return (instance:IsA('BasePart') and not instance.CanCollide)
    		or collectionService:HasTag(instance, 'DontBlockProjectileRaycast')
    		or collectionService:HasTag(instance, 'block:no-collision')
    		or bedwars.QueryUtil:isQueryIgnored(instance)
    end

    ProjectileAura = vape.Categories.Blatant:CreateModule({
    	Name = 'Projectile Aura',
    	Function = function(callback)
    		if callback then
    			projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    			repeat
    				if entitylib.isAlive and not projectilePending and projectileRemote and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
    					local ent = getTarget()
    					if ent then
    						local pos = entitylib.character.RootPart.Position
    						for _, data in getProjectiles() do
    							local item, ammo, projectile, itemMeta = unpack(data)
    							if (FireDelays[item.itemType] or 0) < tick() then
    								rayCheck.FilterDescendantsInstances = {store.map or workspace:FindFirstChild('Map')}
    								local meta = bedwars.ProjectileMeta[projectile]
    								if not meta or type(meta.launchVelocity) ~= 'number' then continue end
    								local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2

    								targetinfo.Targets[ent] = tick() + 1
    								local switched = switchItem(item.tool)
    								local targetpos = ent.RootPart.Position
    								local targetVelocity = ent.RootPart.AssemblyLinearVelocity
    								local targetAirborne = ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
    								local shootPosition = (CFrame.new(pos, targetpos) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    								local function solve(minimum)
    									return prediction.SolveTrajectory(shootPosition, projSpeed, gravity, targetpos, targetVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, targetAirborne, ent.RootPart.Position, ent.RootPart, minimum, true)
    								end
    								local calc, _, travelTime = solve()
    								local dir = calc and CFrame.lookAt(shootPosition, calc).LookVector
    								visibilityCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
    								local visible = dir and travelTime and travelTime <= (meta.lifetimeSec or 3) and prediction.IsTrajectoryClear(shootPosition, dir * projSpeed, gravity, travelTime, visibilityCheck, ent.Character, ignored)
    								if not visible and travelTime then
    									calc, _, travelTime = solve(travelTime + 1e-6)
    									dir = calc and CFrame.lookAt(shootPosition, calc).LookVector
    									visibilityCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
    									visible = dir and travelTime and travelTime <= (meta.lifetimeSec or 3) and prediction.IsTrajectoryClear(shootPosition, dir * projSpeed, gravity, travelTime, visibilityCheck, ent.Character, ignored)
    								end
    								if visible then
    									projectilePending = true
    									projectileThread = task.spawn(function()
    										local id = httpService:GenerateGUID(true)
    										local success, res = pcall(function() return projectileRemote:InvokeServer(
    											item.tool,
    											ammo,
    											projectile,
    											shootPosition,
    											pos,
    											dir * projSpeed,
    											id,
    											{ 
    												drawDurationSeconds = 1, 
    												shotId = httpService:GenerateGUID(false) 
    											},
    											workspace:GetServerTimeNow() - 0.045
    										) end)
    										projectilePending = false
    										if not success then
    											notif('Projectile Aura', tostring(res), 5, 'warning')
    											return
    										end
    										if not res then
    											FireDelays[item.itemType] = tick()
    										else
    											--res.Parent = replicatedStorage
    											local shoot = itemMeta.launchSound
    											shoot = shoot and shoot[math.random(1, #shoot)] or nil
    											if shoot then
    												bedwars.SoundManager:playSound(shoot)
    											end
    										end
    									end)

    									FireDelays[item.itemType] = tick() + (tonumber(itemMeta.fireDelaySec) or 0.1)
    									if switched then
    										local timeout = tick() + 5
    										repeat task.wait() until not projectilePending or not ProjectileAura.Enabled or tick() >= timeout
    										if FireRate.Value > 0 then
    											task.wait(FireRate.Value)
    										end
    									end
    								end
    							end
    						end
    					end
    				end
    				task.wait(0.012)
    			until not ProjectileAura.Enabled
    		else
    			if projectileThread and coroutine.status(projectileThread) ~= 'dead' then
    				task.cancel(projectileThread)
    			end
    			projectileThread = nil
    			projectilePending = false
    			projectileRemote = nil
    		end
    	end,
    	Tooltip = 'Shoots people around you',
    })
    Targets = ProjectileAura:CreateTargets({
    	Players = true,
    	Walls = true,
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
    	if not table.find(methods, i) then
    		table.insert(methods, i)
    	end
    end
    Sort = ProjectileAura:CreateDropdown({
    	Name = 'Target Mode',
    	List = methods,
    	Default = 'Distance'
    })
    List = ProjectileAura:CreateTextList({
    	Name = 'Projectiles',
    	Default = {'arrow', 'snowball'},
    })
    FireRate = ProjectileAura:CreateSlider({
    	Name = 'Fire Rate',
    	Min = 0,
    	Max = 2,
    	Default = 0.02,
    	Decimal = 100,
    	Suffix = 'seconds'
    })
    Range = ProjectileAura:CreateSlider({
    	Name = 'Range',
    	Min = 1,
    	Max = 50,
    	Default = 50,
    	Suffix = function(val)
    		return val == 1 and 'stud' or 'studs'
    	end,
    })
end)

run(function()
    local Mode
    local Value
    local WallCheck
    local AutoJump
    local AlwaysJump
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local speedFunction, speedIndex, oldSpeedConstant

    Speed = vape.Categories.Blatant:CreateModule({
        Name = 'Speed',
        Function = function(callback)
            frictionTable.Speed = callback or nil
            updateVelocity()
            if canDebug and type(bedwars.WindWalkerController.updateSpeed) == 'function' then
                if callback then
                    speedFunction = bedwars.WindWalkerController.updateSpeed
                    for index, value in debug.getconstants(speedFunction) do
                        if value == 'moveSpeedMultiplier' then
                            speedIndex = index
                            oldSpeedConstant = value
                            debug.setconstant(speedFunction, speedIndex, 'constantSpeedMultiplier')
                            break
                        end
                    end
    			elseif speedFunction then
    				if speedIndex then
    					debug.setconstant(speedFunction, speedIndex, oldSpeedConstant)
    				end
    				speedFunction = nil
    				speedIndex = nil
                    oldSpeedConstant = nil
                end
            end

            if callback then
                Speed:Clean(runService.PreSimulation:Connect(function(dt)
                    bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
                    if entitylib.isAlive then
                        if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
                            bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
                            if Mode.Value == 'CFrame' then
                                local state = entitylib.character.Humanoid:GetState()
                                if state == Enum.HumanoidStateType.Climbing then return end
            
                                local root, velo = entitylib.character.RootPart, getSpeed()
                                local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
                                local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
            
                                if WallCheck.Enabled then
                                    rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                    rayCheck.CollisionGroup = root.CollisionGroup
                                    local ray = workspace:Raycast(root.Position, destination, rayCheck)
                                    if ray then
                                        destination = ((ray.Position + ray.Normal) - root.Position)
                                    end
                                end
            
                                root.CFrame += destination
                                root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                                if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                end
                            end
                        end
                    end
                end))
            else
                bedwars.StatefulEntityKnockbackController.lastImpulseTime = time()
                bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Increases your movement with various methods.'
    })
    Mode = Speed:CreateDropdown({
        Name = 'Method',
        List = {'Bedwars', 'CFrame'},
        Default = 'CFrame'
    })
    Value = Speed:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Speed:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    AutoJump = Speed:CreateToggle({
        Name = 'AutoJump',
        Function = function(callback)
            AlwaysJump.Object.Visible = callback
        end
    })
    AlwaysJump = Speed:CreateToggle({
        Name = 'Always Jump',
        Visible = false,
        Darker = true
    })
end)

run(function()
    local Mode
    local Animation
    local Value
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local Active, Truss, Loaded

    local climbAnimation = Instance.new('Animation')
    climbAnimation.AnimationId = 'rbxassetid://11344417710'
    vape:Clean(climbAnimation)

    Spider = vape.Categories.Blatant:CreateModule({
    	Name = 'Spider',
    	Function = function(callback)
    		if callback then
    			if Truss then
    				Truss.Parent = gameCamera
    			end

    			Spider:Clean(runService.PreSimulation:Connect(function(dt)
    				if entitylib.isAlive then
    					local root = entitylib.character.RootPart
    					local chars = { gameCamera, lplr.Character, Truss }
    					for _, v in entitylib.List do
    						table.insert(chars, v.Character)
    					end
    					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
    					rayCheck.FilterDescendantsInstances = chars
    					rayCheck.CollisionGroup = root.CollisionGroup

                        local dir, stop = entitylib.character.Humanoid.MoveDirection, false
                        if dir.Magnitude <= 0 then
                            dir, stop = root.CFrame.LookVector, true
                        end
                        local vec = dir * 2.5
                        local ray = workspace:Raycast(
                            root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0),
                            vec,
                            rayCheck
                        )
                        if Active then
                            if not Loaded and Animation.Enabled then
                                Loaded = entitylib.character.Humanoid:LoadAnimation(climbAnimation)
                                Loaded:Play()
                            end
                            if Loaded then
                                Loaded:AdjustSpeed((not stop) and 2 or 0)
                            end
                            if not ray or stop then
                                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                            end
                        end

                        Active = ray
                        if Active and ray.Normal.Y == 0 and not stop then
                            if not vape.Modules.Phase.Enabled or not SpiderShift then
                                if Animation.Enabled then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                                end

                                root.Velocity *= Vector3.new(1, 0, 1)
                                if Mode.Value == 'CFrame' then
                                    root.CFrame += Vector3.new(0, Value.Value * dt, 0)
                                elseif Mode.Value == 'Impulse' then
                                    root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
                                else
                                    root.Velocity += Vector3.new(0, Value.Value, 0)
                                end
                            end
                        elseif not Active then
                            if Loaded then
                                Loaded:Stop()
    							Loaded:Destroy()
                            end
                            Loaded = nil
                        end
                    else
                        if Loaded then
                            Loaded:Stop()
    						Loaded:Destroy()
                        end
                        Loaded = nil
    				end
    			end))
    		else
    			if Truss then
    				Truss.Parent = nil
    			end
                if Loaded then
                    Loaded:Stop()
    				Loaded:Destroy()
                end
                Loaded = nil
    			SpiderShift = false
    		end
    	end,
    	Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)',
    })
    Mode = Spider:CreateDropdown({
    	Name = 'Mode',
    	List = {'Velocity', 'Impulse', 'CFrame'},
    	Function = function(val)
    		Value.Object.Visible = val ~= 'Part'
            if Truss then
    			Truss:Destroy()
    			Truss = nil
    		end
    		if val == 'Part' then
    			Truss = Instance.new('TrussPart')
    			Truss.Size = Vector3.new(2, 2, 2)
    			Truss.Transparency = 1
    			Truss.Anchored = true
    			Truss.Parent = Spider.Enabled and gameCamera or nil
    		end
    	end,
    	Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you',
    })
    Value = Spider:CreateSlider({
    	Name = 'Speed',
    	Min = 0,
    	Max = 100,
    	Default = 30,
    	Darker = true,
    	Suffix = function(val)
    		return val == 1 and 'stud' or 'studs'
    	end,
    })
    Animation = Spider:CreateToggle({
        Name = 'Use bedwars climbing',
        Tooltip = 'Makes you look like ur climbing with a kit (ex: Yamini)'
    })
end)

run(function()
    local TerraAimbot
    local Range
    local Mode

    local old

    TerraAimbot = vape.Categories.Blatant:CreateModule({
        Name = 'Terra Aimbot',
        Function = function(callback)
            if callback then
                old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
                bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
                    local origin, dir = select(2, ...)
                    local plr = entitylib['Entity'.. Mode.Value]({
                        Part = 'RootPart',
                        Range = Range.Value,
                        Origin = origin,
                        Players = true,
                        Wallcheck = true
                    })

                    if plr then
                        local targetVelocity = plr.RootPart.AssemblyLinearVelocity
                        local targetAirborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
                        local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, targetVelocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, targetAirborne, plr.RootPart.Position, plr.RootPart)

                        if calc then
                            for i, v in debug.getstack(2) do
                                if v == dir then
                                    debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
                                end
                            end
                        end
                    end

                    return old(...)
                end
            end
        end,
        Tooltip = 'Silently adjusts where terra blocks are heading towards.'
    })

    Mode = TerraAimbot:CreateDropdown({
        Name = 'Mode',
        List = {'Position', 'Mouse'},
        Default = 'Mouse'
    })
    Range = TerraAimbot:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 1000,
        Default = 1000,
        Suffix = function(val)
            return val <= 1 and 'studs' or 'stud'
        end
    })
end)

run(function()
    local VulcanAimbot
    local Targets
    local Range
    local Sort

    VulcanAimbot = vape.Categories.Blatant:CreateModule({
        Name = 'Vulcan Aimbot',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        local turret = bedwars.Store:getState().Game.selectedTurret
                        if turret then
                            local origin = turret.Rotate.Position
                            local ent = entitylib.EntityMouse({
                                Range = Range.Value,
                                Origin = origin,
                                Wallcheck = Targets.Walls.Enabled or nil,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Sort = sortmethods[Sort.Value]
                            })
                            if ent then
                                local targetVelocity = ent.RootPart.AssemblyLinearVelocity
                                local targetAirborne = ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
                                local pos = prediction.SolveTrajectory(origin, 320, 10, ent.RootPart.Position, targetVelocity, workspace.Gravity, ent.HipHeight, nil, store.airRay, targetAirborne, ent.RootPart.Position, ent.RootPart)
                                if pos then
                                    local delta = pos - origin

                                    -- mathing
                                    bedwars.TurretCameraController.angleX = math.atan2(-delta.X, -delta.Z)
                                    bedwars.TurretCameraController.angleY = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X^2 + delta.Z^2)), -0.8, 0.8)
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not VulcanAimbot.Enabled
            end
        end,
        Tooltip = 'Automatically aims ur camera toward opponents.'
    })

    Targets = VulcanAimbot:CreateTargets({Walls = true, Players = true})
    local methods = {'Distance', 'Damage'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    Sort = VulcanAimbot:CreateDropdown({
        Name = 'Target mode',
        List = methods,
        Default = methods[1]
    })
    Range = VulcanAimbot:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 1000,
        Default = 500
    })
end)

--[[
    Render
]]

run(function()
    local ArmorHighlight
    local Boots, Helmet, Chestplate, UseParts

    local Instances, Decoys = {}, {}
    local charChildConnection

    local function pruneDead()
        for i = #Instances, 1, -1 do
            if not Instances[i].Parent then
                table.remove(Instances, i)
            end
        end
        for i = #Decoys, 1, -1 do
            if not (Decoys[i].Main and Decoys[i].Main.Parent) then
                table.remove(Decoys, i)
            end
        end
    end

    local Properties = {
        OutlineTransparency = 'Slider',
        FillTransparency = 'Slider',
        FillColor = 'ColorSlider',
        OutlineColor = 'ColorSlider'
    }

    local function getArmor(v)
        if not v:FindFirstChild('Handle') then
            return nil
        end
        if v:GetAttribute('ArmorSlot') == 0 and Helmet.Enabled then
            return 'Helmet'
        elseif v:GetAttribute('ArmorSlot') == 1 and Chestplate.Enabled then
            return 'Chestplate'
        elseif v:GetAttribute('ArmorSlot') == 2 and Boots.Enabled then
            return 'Boots'
        end
        return nil
    end

    ArmorHighlight = vape.Categories.Render:CreateModule({
        Name = 'Armor Highlight',
        Function = function(call)
            if call then
                ArmorHighlight:Clean(lplr.CharacterAdded:Connect(function(char)
                    pruneDead()
                    if charChildConnection then
                        charChildConnection:Disconnect()
                    end
                    charChildConnection = char.ChildAdded:Connect(function(part)
                        task.wait(1)
                        if not ArmorHighlight.Enabled or not part.Parent then return end
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = part.Handle:Clone()
                                v.CanCollide = false
                                v.CanTouch = false
                                v.CanQuery = false
                                v.Anchored = true
                                local transparency = part.Handle.Transparency
                                part.Handle.Transparency = 1
                                v.Material = Enum.Material.Neon
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v,
                                    Transparency = transparency
                                })
                            else
                                local highlight = Instance.new('Highlight', part.Handle)
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end
                                
                                table.insert(Instances, highlight)
                            end
                        end
                    end)
                    for _, part in char:GetChildren() do
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = part.Handle:Clone()
                                v.CanCollide = false
                                v.CanTouch = false
                                v.CanQuery = false
                                local transparency = part.Handle.Transparency
                                part.Handle.Transparency = 1
                                v.Anchored = true
                                v.Material = Enum.Material.Neon
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v,
                                    Transparency = transparency
                                })
                            else
                                local highlight = Instance.new('Highlight', part.Handle)
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end
                                
                                table.insert(Instances, highlight)
                            end
                        end
                    end
                end))

                ArmorHighlight:Clean(runService.PreRender:Connect(function()
                    for _, data in Decoys do
                        if data.Main and data.Main.Parent and data.TP and data.TP.Parent then
                            data.Main.Velocity = Vector3.new(0, 1, 0)
                            data.Main.CFrame = data.TP.CFrame
                        end
                    end
                end))

                if entitylib.isAlive then
                    ArmorHighlight:Clean(lplr.Character.ChildAdded:Connect(function(part)
                        task.wait(1)
                        if not ArmorHighlight.Enabled or not part.Parent then return end
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = part.Handle:Clone()
                                v.CanCollide = false
                                v.CanTouch = false
                                v.CanQuery = false
                                v.Anchored = true
                                local transparency = part.Handle.Transparency
                                part.Handle.Transparency = 1
                                v.Material = Enum.Material.Neon
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v,
                                    Transparency = transparency
                                })
                            else
                                local highlight = Instance.new('Highlight', part.Handle)
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end
                                
                                table.insert(Instances, highlight)
                            end
                        end
                    end))

                    for _, part in lplr.Character:GetChildren() do
                        local armor = getArmor(part)
                        if armor then
                            if UseParts.Enabled then
                                local v = part.Handle:Clone()
                                v.CanCollide = false
                                v.CanTouch = false
                                v.CanQuery = false
                                local transparency = part.Handle.Transparency
                                part.Handle.Transparency = 1
                                v.Anchored = true
                                v.Material = Enum.Material.Neon
                                v.Parent = part
                                table.insert(Decoys, {
                                    TP = part.Handle,
                                    Main = v,
                                    Transparency = transparency
                                })
                            else
                                local highlight = Instance.new('Highlight', part.Handle)
                                for i,v in Properties do
                                    highlight[i] = typeof(v.Hue) == 'number' and Color3.fromHSV(v.Hue, v.Sat, v.Value) or v.Value
                                end
                                
                                table.insert(Instances, highlight)
                            end
                        end
                    end
                end
            else
                for i,v in Instances do
                    v:Destroy()
                end
                for _, data in Decoys do
                    if data.TP and data.TP.Parent then
                        data.TP.Transparency = data.Transparency
                    end
                    if data.Main then
                        data.Main:Destroy()
                    end
                end
                if charChildConnection then
                    charChildConnection:Disconnect()
                    charChildConnection = nil
                end
                table.clear(Decoys)
                table.clear(Instances)
            end
        end
    })

    for i,v in Properties do
        local name = i

        Properties[name] = ArmorHighlight['Create'.. v](ArmorHighlight, {
            Name = i,
            Min = 0,
            Max = 1,
            Decimal = 35,
            Function = function(hue, sat, val)
    			pruneDead()
    			for _, ins in Instances do
    				ins[name] = sat and Color3.fromHSV(hue, sat, val) or hue
    			end

                if sat then
                    for _, ins in Decoys do
                        if ins.Main and ins.Main.Parent then
                            ins.Main.Color = Color3.fromHSV(hue, sat, val)
                        end
                    end
                end
            end
        })
    end

    Helmet = ArmorHighlight:CreateToggle({
        Name = 'Helmet',
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    Chestplate = ArmorHighlight:CreateToggle({
        Name = 'Chestplate',
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    Boots = ArmorHighlight:CreateToggle({
        Name = 'Boots',
        Default = true,
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })

    UseParts = ArmorHighlight:CreateToggle({
        Name = 'Use Parts',
        Default = true,
        Function = function()
            if ArmorHighlight.Enabled then
                ArmorHighlight:Toggle()
                ArmorHighlight:Toggle()
            end
        end
    })
end)

run(function()
    local BedESP
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function Added(bed)
    	if not BedESP.Enabled then
    		return
    	end
    	local BedFolder = Instance.new('Folder')
    	BedFolder.Parent = Folder
    	Reference[bed] = BedFolder
    	local parts = bed:GetChildren()
    	table.sort(parts, function(a, b)
    		return a.Name > b.Name
    	end)

    	for _, part in parts do
    		if part:IsA('BasePart') and part.Name ~= 'Blanket' then
    			local handle = Instance.new('BoxHandleAdornment')
    			handle.Size = part.Size + Vector3.new(0.01, 0.01, 0.01)
    			handle.AlwaysOnTop = true
    			handle.ZIndex = 2
    			handle.Visible = true
    			handle.Adornee = part
    			handle.Color3 = part.Color
    			if part.Name == 'Legs' then
    				handle.Color3 = Color3.fromRGB(167, 112, 64)
    				handle.Size = part.Size + Vector3.new(0.01, -1, 0.01)
    				handle.CFrame = CFrame.new(0, -0.4, 0)
    				handle.ZIndex = 0
    			end
    			handle.Parent = BedFolder
    		end
    	end

    	table.clear(parts)
    end

    BedESP = vape.Categories.Render:CreateModule({
    	Name = 'Bed ESP',
    	Function = function(callback)
    		if callback then
    			BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
    				task.delay(0.2, Added, bed)
    			end))
    			BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
    				if Reference[bed] then
    					Reference[bed]:Destroy()
    					Reference[bed] = nil
    				end
    			end))
    			for _, bed in collectionService:GetTagged('bed') do
    				Added(bed)
    			end
    		else
    			Folder:ClearAllChildren()
    			table.clear(Reference)
    		end
    	end,
    	Tooltip = 'Render Beds through walls'
    })
end)

run(function()
    local HiveESP
    local Color
    local Transparency
    local Scale

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings = {}, {}
    local Updates = {}

    local function Added(ent)
    	local Name = playersService:GetNameFromUserIdAsync(ent:GetAttribute('PlacedByUserId')) or 'Unknown'

        Strings[ent] = Name .. "'s beehive | %s Bee%s"
    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value
    	nametag.Font = Enum.Font.Arial
    	local format = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
    	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = Name
    	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    	nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new()
    	nametag.BackgroundTransparency = 0.5
    	nametag.BorderSizePixel = 0
    	nametag.Visible = false
    	nametag.Text = format
    	nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	nametag.RichText = true
    	nametag.Parent = Folder
    	Reference[ent] = nametag

    	HiveESP:Clean(ent:GetAttributeChangedSignal('Level'):Connect(function()
    		Updates[ent] = tick() + 0.1
    	end))
    	Updates[ent] = tick() + 0.1
    end
    local function Updated(ent)
    	if Reference[ent] then
    		Reference[ent].TextSize = 14 * Scale.Value
    		Reference[ent].TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		Reference[ent].BackgroundTransparency = Transparency.Value
    	end
    end
    local function Removing(ent)
    	if Reference[ent] then
    		Reference[ent]:Destroy()
    		Reference[ent] = nil
    	end
    end

    HiveESP = vape.Categories.Render:CreateModule({
    	Name = 'Beehive ESP',
    	Function = function(call)
    		if call then
    			for _, v in collectionService:GetTagged('beehive') do
    				Added(v)
    			end
    			HiveESP:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(Added))
    			HiveESP:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(Removing))
    			HiveESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then
    						continue
    					end

    					if (Updates[ent] or 0) > tick() then
    						nametag.Text = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
    						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    					end

    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))
    		else
    			for i in Reference do
    				Removing(i)
    			end
    		end
    	end,
    	Tooltip = 'Renders hives locations and info'
    })

    Color = HiveESP:CreateColorSlider({
    	Name = 'Text Color',
    	Function = function(hue, sat, val)
    		if HiveESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end
    })
    Transparency = HiveESP:CreateSlider({
    	Name = 'Transparency',
    	Function = function()
    		if HiveESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end,
    	Default = 0.5,
    	Min = 0,
    	Max = 1,
    	Decimal = 100
    })
    Scale = HiveESP:CreateSlider({
    	Name = 'Scale',
    	Default = 1,
    	Min = 0.1,
    	Max = 1.5,
    	Decimal = 10,
    	Function = function()
    		if HiveESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end
    })
end)

run(function()
    local CustomTags
    local Color
    local TAG
    local old, old2, oldClanTag, oldCaptured
    local tagRenderConn
    local tagGuiConn

    local function Color3ToHex(r, g, b)
    	return string.lower(string.format('#%02X%02X%02X', r, g, b))
    end

    local function CompleteTagEffect()
    	if not lplr:FindFirstChild('Tags') then
    		return
    	end
    	local tagObj = lplr.Tags:FindFirstChild('0')
    	if not tagObj then
    		return
    	end

    	if not oldCaptured then
    		old = tagObj.Value
    		old2 = tagObj:GetAttribute('Text')
    		oldClanTag = lplr:GetAttribute('ClanTag')
    		oldCaptured = true
    	end

    	local color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	local R = math.floor(color.R * 255)
    	local G = math.floor(color.G * 255)
    	local B = math.floor(color.B * 255)

    	tagObj.Value = string.format("<font color='rgb(%d,%d,%d)'>[%s]</font>", R, G, B, TAG.Value)
    	tagObj:SetAttribute('Text', TAG.Value)
    	lplr:SetAttribute('ClanTag', TAG.Value)

    	if tagRenderConn then
    		tagRenderConn:Disconnect()
    		tagRenderConn = nil
    	end
    	if tagGuiConn then
    		tagGuiConn:Disconnect()
    		tagGuiConn = nil
    	end

    	local function attachGui(child)
    		if child.Name ~= 'TabListScreenGui' or not child:IsA('ScreenGui') then
    			return
    		end
    		if tagRenderConn then
    			tagRenderConn:Disconnect()
    		end
    		local elapsed = 0.25
    		tagRenderConn = runService.Heartbeat:Connect(function(dt)
    			elapsed += dt
    			if elapsed < 0.25 then return end
    			elapsed = 0
    			local nameToFind = (lplr.DisplayName == '' or lplr.DisplayName == lplr.Name) and lplr.Name
    				or lplr.DisplayName
    			for _, v in pairs(child:GetDescendants()) do
    				if v:IsA('TextLabel') and string.find(string.lower(v.Text), string.lower(nameToFind)) then
    					v.Text = string.format(
    						'<font transparency="0.3" color="%s">[%s]</font> %s',
    						Color3ToHex(R, G, B),
    						TAG.Value,
    						nameToFind
    					)
    				end
    			end
    		end)
    	end

    	tagGuiConn = lplr.PlayerGui.ChildAdded:Connect(attachGui)
    	local tabList = lplr.PlayerGui:FindFirstChild('TabListScreenGui')
    	if tabList then
    		attachGui(tabList)
    	end
    end

    local function RemoveTagEffect()
    	if tagRenderConn then
    		tagRenderConn:Disconnect()
    		tagRenderConn = nil
    	end

    	if tagGuiConn then
    		tagGuiConn:Disconnect()
    		tagGuiConn = nil
    	end

    	if lplr:FindFirstChild('Tags') then
    		local tagObj = lplr.Tags:FindFirstChild('0')
    		if tagObj then
    			tagObj.Value = old
    			tagObj:SetAttribute('Text', old2)
    		end
    	end

    	lplr:SetAttribute('ClanTag', oldClanTag)

    	old = nil
    	old2 = nil
    	oldClanTag = nil
    	oldCaptured = nil
    end

    CustomTags = vape.Categories.Render:CreateModule({
    	Name = 'Custom Tags',
    	Function = function(callback)
    		if callback then
    			CompleteTagEffect()
    		else
    			RemoveTagEffect()
    		end
    	end,
    	Tooltip = 'Client-Sided visual custom clan tag on-chat'
    })

    Color = CustomTags:CreateColorSlider({
    	Name = 'Color',
    	Function = function()
    		if CustomTags.Enabled then
    			CompleteTagEffect()
    		end
    	end,
    })
    TAG = CustomTags:CreateTextBox({
    	Name = 'Tag',
    	Default = 'gg',
    	Function = function()
    		if CustomTags.Enabled then
    			CompleteTagEffect()
    		end
    	end,
    })
end)

run(function()
    local GeneratorESP
    local Transparency
    local Scale
    local Whitelist
    local Whitelisted = { ListEnabled = {}, Object = nil }

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings, Cooldown = {}, {}, {}
    local Updates = {}

    local function getNumber(text)
    	if not text or text == '' then
    		return 0
    	end
    	local seconds = text:match('%[(%d+)%]')
    	if seconds then
    		return tonumber(seconds) or 0
    	end
    	local justNumber = text:match('(%d+)')
    	if justNumber then
    		return tonumber(justNumber) or 0
    	end
    	return 0
    end

    local function Added(ent)
    	local App = ent.RoactTree.TeamOreGeneratorApp
    	local Name = (App:FindFirstChild('GlobalOreGenerator') or App:FindFirstChild('TeamGenMain'))
    	local Countdown = (Name or App):FindFirstChild('Countdown', true)
    	if Name then
    		Name = Name:FindFirstChild('Title')
    	end

    	local TierType = ''
    	if Name then
    		Name = Name.Text
    		TierType = 'iron'
    	else
    		local Ore = ent:GetAttribute('Id')
    		Ore = Ore:sub(0, #Ore - 2)
    		TierType = (Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore)):lower()
    		Name = Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore) .. ' Generator'
    	end

    	if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, TierType) then
    		return
    	end

        Strings[ent] = Name .. " %s%s"
    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value
    	nametag.Font = Enum.Font.Arial
        local format = string.format(Strings[ent], '| T' .. tostring(ent:GetAttribute('GeneratorLevel')), '')
    	local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = Name
    	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    	nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new()
    	nametag.BackgroundTransparency = 0.5
    	nametag.BorderSizePixel = 0
    	nametag.Visible = false
    	nametag.Text = format
    	nametag.TextColor3 = Color3.new(1, 1, 1)
    	nametag.RichText = true
    	nametag.Parent = Folder
    	Reference[ent] = nametag

    	local Update = function()
    		Updates[ent] = tick() + 0.1
    	end
    	GeneratorESP:Clean(ent:GetAttributeChangedSignal('GeneratorLevel'):Connect(Update))
    	GeneratorESP:Clean(ent:GetAttributeChangedSignal('Cooldown'):Connect(Update))
    	if Countdown then
    		Cooldown[ent] = Countdown
    		GeneratorESP:Clean(Countdown:GetPropertyChangedSignal('Text'):Connect(Update))
    	end
    	Update()
    end
    local function Updated(ent)
    	if Reference[ent] then
    		Reference[ent].TextSize = 14 * Scale.Value
    		Reference[ent].BackgroundTransparency = Transparency.Value
    	end
    end
    local function Removing(ent)
    	if Reference[ent] then
    		Reference[ent]:Destroy()
    		Reference[ent] = nil
    	end
    end

    GeneratorESP = vape.Categories.Render:CreateModule({
    	Name = 'Generator ESP',
    	Function = function(call)
    		if call then
    			for _, v in collectionService:GetTagged('Generator') do
    				Added(v)
    			end
    			GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
    			GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(Removing))
    			GeneratorESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then
    						continue
    					end

    					if (Updates[ent] or 0) > tick() then
                            nametag.Text = string.format(Strings[ent], '| T' .. tostring(ent:GetAttribute('GeneratorLevel')), Cooldown[ent] and (' | ' .. getNumber(Cooldown[ent].Text) .. 's') or '')
    						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    					end

    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))
    		else
    			for i in Reference do
    				Removing(i)
    			end
    		end
    	end,
    	Tooltip = 'Renders generator locations and info'
    })

    Transparency = GeneratorESP:CreateSlider({
    	Name = 'Transparency',
    	Function = function()
    		if GeneratorESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end,
    	Default = 0.5,
    	Min = 0,
    	Max = 1,
    	Decimal = 100,
    })
    Scale = GeneratorESP:CreateSlider({
    	Name = 'Scale',
    	Default = 1,
    	Min = 0.1,
    	Max = 1.5,
    	Decimal = 10,
    	Function = function()
    		if GeneratorESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end,
    })
    Whitelist = GeneratorESP:CreateToggle({
    	Name = 'Use whitelist',
    	Default = true,
    	Function = function(call)
    		if Whitelisted.Object then
    			Whitelisted.Object.Visible = call
    		end
    	end,
    })
    Whitelisted = GeneratorESP:CreateTextList({
    	Name = 'Generators',
    	Darker = true,
    	Default = {'diamond', 'iron'},
    })
end)

run(function()
    local Health

    local function updateLabel(label)
    	local char = entitylib.isAlive and lplr.Character
    	local health = char and char:GetAttribute('Health')
    	local maxHealth = char and char:GetAttribute('MaxHealth')
    	if type(health) == 'number' and type(maxHealth) == 'number' and maxHealth > 0 then
    		label.Text = math.round(health) .. ' ❤️'
    		label.TextColor3 = Color3.fromHSV((health / maxHealth) / 2.8, 0.86, 1)
    	else
    		label.Text = ''
    		label.TextColor3 = Color3.new()
    	end
    end

    Health = vape.Categories.Render:CreateModule({
    	Name = 'Health',
    	Function = function(callback)
    		if callback then
    			local label = Instance.new('TextLabel')
    			label.Size = UDim2.fromOffset(100, 20)
    			label.Position = UDim2.new(0.5, 6, 0.5, 30)
    			label.BackgroundTransparency = 1
    			label.AnchorPoint = Vector2.new(0.5, 0)
    			updateLabel(label)
    			label.TextSize = 18
    			label.Font = Enum.Font.Arial
    			label.Parent = vape.gui
    			Health:Clean(label)
    			Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
    				updateLabel(label)
    			end))
    		end
    	end,
    	Tooltip = 'Displays your health in the center of your screen.'
    })
end)

run(function()
    local ItemESP
    local Distance
    local Transparency
    local Scale
    local WhitelistOnly
    local Whitelist = {ListEnabled = {}, Object = nil}

    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local Reference, Strings, Sizes = {}, {}, {}

    local function Added(ent)
    	local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
    	if WhitelistOnly.Enabled and not table.find(Whitelist.ListEnabled, Name:lower()) then
    		return
    	end

    	Strings[ent] = Name .. '%s'
    	if Distance.Enabled then
    		Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent]
    	end

    	local nametag = Instance.new('TextLabel')
    	nametag.TextSize = 14 * Scale.Value
    	nametag.Font = Enum.Font.Arial
    	local size = getfontsize(removeTags(ent.Name), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    	nametag.Name = ent.Name
    	nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    	nametag.AnchorPoint = Vector2.new(0.5, 1)
    	nametag.BackgroundColor3 = Color3.new()
    	nametag.BackgroundTransparency = 0.5
    	nametag.BorderSizePixel = 0
    	nametag.Visible = false
    	nametag.Text = string.format(Strings[ent], '', ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
    	nametag.TextColor3 = Color3.new(1, 1, 1)
    	nametag.RichText = true
    	nametag.Parent = Folder
    	Reference[ent] = nametag
    end
    local function Updated(ent)
    	if Reference[ent] then
    		Reference[ent].TextSize = 14 * Scale.Value
    		Reference[ent].BackgroundTransparency = Transparency.Value
    	end
    end
    local function Removing(ent)
    	if Reference[ent] then
    		Reference[ent]:Destroy()
    		Reference[ent] = nil
    	end
    end

    ItemESP = vape.Categories.Render:CreateModule({
    	Name = 'Item ESP',
    	Function = function(call)
    		if call then
    			ItemESP:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(Added))
    			ItemESP:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(Removing))
    			ItemESP:Clean(runService.PreRender:Connect(function()
    				for ent, nametag in Reference do
    					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
    					nametag.Visible = headVis
    					if not headVis then
    						continue
    					end

    					if Distance.Enabled then
    						local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or 0
    						if Sizes[ent] ~= mag then
    							nametag.Text = string.format(Strings[ent], mag, ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
    							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    							nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    							Sizes[ent] = mag
    						end
    					else
    						nametag.Text = string.format(Strings[ent], '')
    						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    					end
    					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    				end
    			end))

    			for _, v in collectionService:GetTagged('ItemDrop') do
    				Added(v)
    			end
    		else
    			for i in Reference do
    				Removing(i)
    			end
    		end
    	end,
    	Tooltip = 'Renders tags dropped items'
    })
    Distance = ItemESP:CreateToggle({
    	Name = 'Distance',
    	Tooltip = 'Shows the distance of the item',
    	Function = function(callback)
    		if ItemESP.Enabled then
    			for ent in Reference do
    				local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
    				Strings[ent] = callback and '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent] or Name.. '%s'
    			end
    		end
    	end
    })
    ItemESP:CreateToggle({
    	Name = 'Group items',
    	Tooltip = 'Group items into easier to read tags'
    })
    Transparency = ItemESP:CreateSlider({
    	Name = 'Transparency',
    	Function = function()
    		if ItemESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end,
    	Default = 0.5,
    	Min = 0,
    	Max = 1,
    	Decimal = 100
    })
    Scale = ItemESP:CreateSlider({
    	Name = 'Scale',
    	Default = 1,
    	Min = 0.1,
    	Max = 1.5,
    	Decimal = 10,
    	Function = function()
    		if ItemESP.Enabled then
    			for ent in Reference do
    				Updated(ent)
    			end
    		end
    	end
    })
    WhitelistOnly = ItemESP:CreateToggle({
    	Name = 'Whitelist Only',
    	Tooltip = 'Only renders whitelisted items',
    	Function = function(call)
    		if Whitelist.Object then
    			Whitelist.Object.Visible = call

    			if ItemESP.Enabled then
    				ItemESP:Toggle()
    				ItemESP:Toggle()
    			end
    		end
    	end
    })
    Whitelist = ItemESP:CreateTextList({
    	Name = 'Allowed items',
    	Visible = false,
    	Darker = true,
    	Function = function()
    		if ItemESP.Enabled then
    			ItemESP:Toggle()
    			ItemESP:Toggle()
    		end
    	end
    })
end)

run(function()
    local KitESP
    local Background
    local Color = {}
    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local ESPKits = {
    	alchemist = {'alchemist_ingedients', 'wild_flower'},
    	beekeeper = {'bee', 'bee'},
    	bigman = {'treeOrb', 'natures_essence_1'},
    	ghost_catcher = {'ghost', 'ghost_orb'},
    	metal_detector = {'hidden-metal', 'iron'},
    	sheep_herder = {'SheepModel', 'purple_hay_bale'},
    	sorcerer = {'alchemy_crystal', 'wild_flower'},
    	star_collector = {'stars', 'crit_star'},
    }

    local function Added(v, icon, tag)
    	if tag == 'bee' and math.abs(v.Parent:GetAttribute('BeeId') or 0) < 100 then return end
    	local billboard = Instance.new('BillboardGui')
    	billboard.Parent = Folder
    	billboard.Name = icon
    	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    	billboard.Size = UDim2.fromOffset(36, 36)
    	billboard.AlwaysOnTop = true
    	billboard.ClipsDescendants = false
    	billboard.Adornee = v
    	local blur = addBlur(billboard)
    	blur.Visible = Background.Enabled
    	local image = Instance.new('ImageLabel')
    	image.Size = UDim2.fromOffset(36, 36)
    	image.Position = UDim2.fromScale(0.5, 0.5)
    	image.AnchorPoint = Vector2.new(0.5, 0.5)
    	image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
    	image.BorderSizePixel = 0
    	image.Image = bedwars.getIcon({ itemType = icon }, true)
    	image.Parent = billboard
    	local uicorner = Instance.new('UICorner')
    	uicorner.CornerRadius = UDim.new(0, 4)
    	uicorner.Parent = image
    	Reference[v] = billboard
    end

    local function addKit(tag, icon)
    	KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
    		Added(v.PrimaryPart, icon, tag)
    	end))
    	KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
    		if Reference[v.PrimaryPart] then
    			Reference[v.PrimaryPart]:Destroy()
    			Reference[v.PrimaryPart] = nil
    		end
    	end))
    	for _, v in collectionService:GetTagged(tag) do
    		Added(v.PrimaryPart, icon, tag)
    	end
    end

    KitESP = vape.Categories.Render:CreateModule({
    	Name = 'Kit ESP',
    	Function = function(callback)
    		if callback then
    			repeat
    				task.wait()
    			until store.equippedKit ~= '' or not KitESP.Enabled
    			local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
    			if kit then
    				addKit(kit[1], kit[2])
    			end
    		else
    			Folder:ClearAllChildren()
    			table.clear(Reference)
    		end
    	end,
    	Tooltip = 'ESP for certain kit related objects'
    })
    Background = KitESP:CreateToggle({
    	Name = 'Background',
    	Function = function(callback)
    		if Color.Object then
    			Color.Object.Visible = callback
    		end
    		for _, v in Reference do
    			v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
    			v.Blur.Visible = callback
    		end
    	end,
    	Default = true,
    })
    Color = KitESP:CreateColorSlider({
    	Name = 'Background Color',
    	DefaultValue = 0,
    	DefaultOpacity = 0.5,
    	Function = function(hue, sat, val, opacity)
    		for _, v in Reference do
    			v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
    			v.ImageLabel.BackgroundTransparency = 1 - opacity
    		end
    	end,
    	Darker = true,
    })
end)

run(function()
    local NameTags
    local Targets
    local Color
    local Background
    local DisplayName
    local Health
    local Distance
    local Equipment
    local Rank
    local Enchant
    local DrawingToggle
    local Scale
    local FontOption
    local Teammates
    local DistanceCheck
    local DistanceLimit
    local Strings, Sizes, Reference = {}, {}, {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui
    local methodused

    local Added = {
    	Normal = function(ent)
    		if not Targets.Players.Enabled and ent.Player then
    			return
    		end
    		if not Targets.NPCs.Enabled and ent.NPC then
    			return
    		end
    		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
    			return
    		end

    		local nametag = Instance.new('TextLabel')
    		Strings[ent] = ent.Player
    				and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
    			or ent.Character.Name

    		if Health.Enabled then
    			local healthColor = Color3.fromHSV(math.clamp(ent.Health / math.max(ent.MaxHealth, 1), 0, 1) / 2.5, 0.89, 0.75)
    			Strings[ent] = Strings[ent]
    				.. ' <font color="rgb('
    				.. tostring(math.floor(healthColor.R * 255))
    				.. ','
    				.. tostring(math.floor(healthColor.G * 255))
    				.. ','
    				.. tostring(math.floor(healthColor.B * 255))
    				.. ')">'
    				.. math.round(ent.Health)
    				.. '</font>'
    		end

    		if Distance.Enabled then
    			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
    				.. Strings[ent]
    		end

    		if Equipment.Enabled then
    			for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
    				local Icon = Instance.new('ImageLabel')
    				Icon.Name = v
    				Icon.Size = UDim2.fromOffset(30, 30)
    				Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
    				Icon.BackgroundTransparency = 1
    				Icon.Image = ''
    				Icon.Parent = nametag
    			end
    		end

    		nametag.TextSize = 14 * Scale.Value
    		nametag.FontFace = FontOption.Value
    		local size =
    			getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
    		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    		nametag.AnchorPoint = Vector2.new(0.5, 1)
    		nametag.BackgroundColor3 = Color3.new()
    		nametag.BackgroundTransparency = Background.Value
    		nametag.BorderSizePixel = 0
    		nametag.Visible = false
    		nametag.Text = Strings[ent]
    		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		nametag.RichText = true
    		nametag.Parent = Folder
    		task.spawn(function()
    			if Rank.Enabled and ent.Player then
    				local Icon = Instance.new('ImageLabel')
    				Icon.Name = 'RankIcon'
    				Icon.Size = UDim2.fromOffset(30, 30)
    				Icon.Position = UDim2.fromOffset(size.X + 10, -4)
    				Icon.BackgroundTransparency = 1
    				Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image
    					or ''
    				Icon.Parent = nametag
    			end
    		end)
    		task.spawn(function()
    			if Enchant.Enabled and ent.Player then
    				local Icon = Instance.new('ImageLabel')
    				Icon.Name = 'EnchantIcon'
    				Icon.Size = UDim2.fromOffset(30, 30)
    				Icon.Position = UDim2.fromOffset(-30, -4)
    				Icon.BackgroundTransparency = 1
    				Icon.Image = store.enchants[ent.Player]:async() or ''
    				Icon.Parent = nametag
    			end
    		end)
    		Reference[ent] = nametag
    	end,
    	Drawing = function(ent)
    		if not Targets.Players.Enabled and ent.Player then
    			return
    		end
    		if not Targets.NPCs.Enabled and ent.NPC then
    			return
    		end
    		if Teammates.Enabled and not ent.Targetable and not ent.Friend then
    			return
    		end

    		local nametag = {}
    		nametag.BG = Drawing.new('Square')
    		nametag.BG.Filled = true
    		nametag.BG.Transparency = 1 - Background.Value
    		nametag.BG.Color = Color3.new()
    		nametag.BG.ZIndex = 1
    		nametag.Text = Drawing.new('Text')
    		nametag.Text.Size = 15 * Scale.Value
    		nametag.Text.Font = 0
    		nametag.Text.ZIndex = 2
    		Strings[ent] = ent.Player
    				and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
    			or ent.Character.Name

    		if Health.Enabled then
    			Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
    		end

    		if Distance.Enabled then
    			Strings[ent] = '[%s] ' .. Strings[ent]
    		end

    		nametag.Text.Text = Strings[ent]
    		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
    		Reference[ent] = nametag
    	end,
    }

    local Removed = {
    	Normal = function(ent)
    		local v = Reference[ent]
    		if v then
    			Reference[ent] = nil
    			Strings[ent] = nil
    			Sizes[ent] = nil
    			v:Destroy()
    		end
    	end,
    	Drawing = function(ent)
    		local v = Reference[ent]
    		if v then
    			Reference[ent] = nil
    			Strings[ent] = nil
    			Sizes[ent] = nil
    			for _, obj in v do
    				pcall(function()
    					obj.Visible = false
    					obj:Remove()
    				end)
    			end
    		end
    	end,
    }

    local Updated = {
    	Normal = function(ent)
    		local nametag = Reference[ent]
    		if nametag then
    			Sizes[ent] = nil
    			Strings[ent] = ent.Player
    					and whitelist:tag(ent.Player, true, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
    				or ent.Character.Name

    			if Health.Enabled then
    				local healthColor = Color3.fromHSV(math.clamp(ent.Health / math.max(ent.MaxHealth, 1), 0, 1) / 2.5, 0.89, 0.75)
    				Strings[ent] = Strings[ent]
    					.. ' <font color="rgb('
    					.. tostring(math.floor(healthColor.R * 255))
    					.. ','
    					.. tostring(math.floor(healthColor.G * 255))
    					.. ','
    					.. tostring(math.floor(healthColor.B * 255))
    					.. ')">'
    					.. math.round(ent.Health)
    					.. '</font>'
    			end

    			if Distance.Enabled then
    				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '
    					.. Strings[ent]
    			end

    			if Equipment.Enabled and store.inventories[ent.Player] then
    				local kit = ent.Player:GetAttribute('PlayingAsKits')
    				local inventory = store.inventories[ent.Player]
    				nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
    				nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
    				nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
    				nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
    				nametag.Kit.Image = kit and bedwars.BedwarsKitMeta[kit].renderImage or ''
    			end

    			if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
    				nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
    			end

    			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
    			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
    			nametag.Text = Strings[ent]
    		end
    	end,
    	Drawing = function(ent)
    		local nametag = Reference[ent]
    		if nametag then
    			if vape.ThreadFix then
    				setthreadidentity(8)
    			end
    			Sizes[ent] = nil
    			Strings[ent] = ent.Player
    					and whitelist:tag(ent.Player, true) .. (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name)
    				or ent.Character.Name

    			if Health.Enabled then
    				Strings[ent] = Strings[ent] .. ' ' .. math.round(ent.Health)
    			end

    			if Distance.Enabled then
    				Strings[ent] = '[%s] ' .. Strings[ent]
    				nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
    			else
    				nametag.Text.Text = Strings[ent]
    			end

    			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
    			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    		end
    	end,
    }

    local ColorFunc = {
    	Normal = function(hue, sat, val)
    		local color = Color3.fromHSV(hue, sat, val)
    		for i, v in Reference do
    			v.TextColor3 = entitylib.getEntityColor(i) or color
    		end
    	end,
    	Drawing = function(hue, sat, val)
    		local color = Color3.fromHSV(hue, sat, val)
    		for i, v in Reference do
    			v.Text.Color = entitylib.getEntityColor(i) or color
    		end
    	end,
    }

    local Loop = {
    	Normal = function()
    		local alive = entitylib.isAlive
    		local localPosition = alive and entitylib.character.RootPart.Position
    		for ent, nametag in Reference do
    			local distance
    			if alive and (DistanceCheck.Enabled or Distance.Enabled) then
    				distance = (localPosition - ent.RootPart.Position).Magnitude
    			end

    			if DistanceCheck.Enabled then
    				distance = distance or math.huge
    				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
    					nametag.Visible = false
    					continue
    				end
    			end

    			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
    			nametag.Visible = headVis
    			if not headVis then
    				continue
    			end

    			if Distance.Enabled then
    				local mag = alive and math.floor(distance) or 0
    				if Sizes[ent] ~= mag then
    					nametag.Text = string.format(Strings[ent], mag)
    					local ize = getfontsize(
    						removeTags(nametag.Text),
    						nametag.TextSize,
    						nametag.FontFace,
    						Vector2.new(100000, 100000)
    					)
    					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
    					Sizes[ent] = mag
    				end
    			end
    			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
    		end
    	end,
    	Drawing = function()
    		local alive = entitylib.isAlive
    		local localPosition = alive and entitylib.character.RootPart.Position
    		for ent, nametag in Reference do
    			local distance
    			if alive and (DistanceCheck.Enabled or Distance.Enabled) then
    				distance = (localPosition - ent.RootPart.Position).Magnitude
    			end

    			if DistanceCheck.Enabled then
    				distance = distance or math.huge
    				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
    					nametag.Text.Visible = false
    					nametag.BG.Visible = false
    					continue
    				end
    			end

    			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
    			nametag.Text.Visible = headVis
    			nametag.BG.Visible = headVis
    			if not headVis then
    				continue
    			end

    			if Distance.Enabled then
    				local mag = alive and math.floor(distance) or 0
    				if Sizes[ent] ~= mag then
    					nametag.Text.Text = string.format(Strings[ent], mag)
    					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
    					Sizes[ent] = mag
    				end
    			end
    			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
    			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
    		end
    	end,
    }

    NameTags = vape.Categories.Render:CreateModule({
    	Name = 'Name Tags',
    	Function = function(callback)
    		if callback then
    			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
    			if Removed[methodused] then
    				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
    			end
    			if Added[methodused] then
    				for _, v in entitylib.List do
    					if Reference[v] then
    						Removed[methodused](v)
    					end
    					Added[methodused](v)
    				end
    				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
    					if Reference[ent] then
    						Removed[methodused](ent)
    					end
    					Added[methodused](ent)
    				end))
    			end
    			if Updated[methodused] then
    				NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
    				for _, v in entitylib.List do
    					Updated[methodused](v)
    				end
    			end
    			if ColorFunc[methodused] then
    				NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
    					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
    				end))
    			end
    			if Loop[methodused] then
    				NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
    			end
    		else
    			if Removed[methodused] then
    				for i in Reference do
    					Removed[methodused](i)
    				end
    			end
    		end
    	end,
    	Tooltip = 'Renders nametags on entities through walls.'
    })
    Targets = NameTags:CreateTargets({
    	Players = true,
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    FontOption = NameTags:CreateFont({
    	Name = 'Font',
    	Blacklist = 'Arial',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    Color = NameTags:CreateColorSlider({
    	Name = 'Player Color',
    	Function = function(hue, sat, val)
    		if NameTags.Enabled and ColorFunc[methodused] then
    			ColorFunc[methodused](hue, sat, val)
    		end
    	end,
    })
    Scale = NameTags:CreateSlider({
    	Name = 'Scale',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    	Default = 1,
    	Min = 0.1,
    	Max = 1.5,
    	Decimal = 10,
    })
    Background = NameTags:CreateSlider({
    	Name = 'Transparency',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    	Default = 0.5,
    	Min = 0,
    	Max = 1,
    	Decimal = 10,
    })
    Health = NameTags:CreateToggle({
    	Name = 'Health',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    Distance = NameTags:CreateToggle({
    	Name = 'Distance',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    Rank = NameTags:CreateToggle({
    	Name = 'Rank',
    	Tooltip = "Displays player's rank",
    })
    Enchant = NameTags:CreateToggle({
    	Name = 'Enchant',
    	Tooltip = "Displays player's enchant",
    	Default = true,
    })
    Equipment = NameTags:CreateToggle({
    	Name = 'Equipment',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    DisplayName = NameTags:CreateToggle({
    	Name = 'Use Displayname',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    	Default = true,
    })
    Teammates = NameTags:CreateToggle({
    	Name = 'Priority Only',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    	Default = true,
    })
    DrawingToggle = NameTags:CreateToggle({
    	Name = 'Drawing',
    	Function = function()
    		if NameTags.Enabled then
    			NameTags:Toggle()
    			NameTags:Toggle()
    		end
    	end,
    })
    DistanceCheck = NameTags:CreateToggle({
    	Name = 'Distance Check',
    	Function = function(callback)
    		DistanceLimit.Object.Visible = callback
    	end,
    })
    DistanceLimit = NameTags:CreateTwoSlider({
    	Name = 'Player Distance',
    	Min = 0,
    	Max = 256,
    	DefaultMin = 0,
    	DefaultMax = 64,
    	Darker = true,
    	Visible = false,
    })
end)

run(function()
    local BulletTracers
    local Material
    local Lifetime
    local Curve
    local Opacity
    local Thickness
    local Color
    local Fade

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    BulletTracers = vape.Categories.Render:CreateModule({
    	Name = 'Projectile Tracers',
    	Function = function(callback)
    		if callback then
    			BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
    				task.delay(0, function()
    					if not BulletTracers.Enabled or not projectile.Parent or projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then
    						return
    					end
    					local filter = {projectile}
    					if lplr.Character then table.insert(filter, lplr.Character) end
    					rayCheck.FilterDescendantsInstances = filter
    					local root = projectile:IsA('BasePart') and projectile or projectile:IsA('Model') and projectile.PrimaryPart
    					local meta = bedwars.ProjectileMeta[projectile.Name]
    					if not root or not meta then return end
    					local origin = root.Position
    					local velocity = root.AssemblyLinearVelocity
    					local velocityMagnitude = velocity.Magnitude
    					if velocityMagnitude <= 0 then
    						return
    					end
    					local velocityUnit = velocity / velocityMagnitude
    					local gravity = meta.gravitationalAcceleration or workspace.Gravity
    					local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
    					local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
    					local travelTime = (endpoint - origin).Magnitude / velocityMagnitude

    					prediction.SpawnArcTracer(
    						origin,
    						velocityUnit,
    						velocityMagnitude,
    						gravity,
    						travelTime,
    						Curve.Value,
    						{
    							Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
    							Transparency = Opacity.Value,
    							Thick = Thickness.Value,
    							Material = Enum.Material[Material.Value],
    							Lifetime = Lifetime.Value,
    							Fade = Fade.Enabled,
    						}
    					)
    				end)
    			end))
    		end
    	end,
    	Tooltip = 'Replacement tracers for projectiles'
    })

    local materials = {'SmoothPlastic'}
    for _, v in Enum.Material:GetEnumItems() do
    	if v.Name ~= 'SmoothPlastic' then
    		table.insert(materials, v.Name)
    	end
    end
    Material = BulletTracers:CreateDropdown({
    	Name = 'Material',
    	List = materials
    })
    Color = BulletTracers:CreateColorSlider({
    	Name = 'Tracer Color',
    	DefaultOpacity = 0.5
    })
    Thickness = BulletTracers:CreateSlider({
    	Name = 'Thickness',
    	Min = 0.01,
    	Max = 1,
    	Default = 0.1,
    	Decimal = 100
    })
    Curve = BulletTracers:CreateSlider({
    	Name = 'Curveness',
    	Min = 1,
    	Max = 100,
    	Default = 40,
    	Tooltip = 'How curve the projectile is gonna be\n(More curve = more lag)'
    })
    Opacity = BulletTracers:CreateSlider({
    	Name = 'Opacity',
    	Min = 0,
    	Max = 1,
    	Default = 0,
    	Decimal = 100
    })
    Lifetime = BulletTracers:CreateSlider({
    	Name = 'Lifetime',
    	Min = 0,
    	Max = 5,
    	Decimal = 100,
    	Default = 2,
    	Suffix = 'secs'
    })
    Fade = BulletTracers:CreateToggle({
    	Name = 'Fade',
    	Default = true
    })
end)

run(function()
    local Shader
    local changed = false
    local lightingSettings = {}
    local Objects = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    Shader = vape.Categories.Render:CreateModule({
    	Name = 'Shader',
    	Function = function(callback)
    		if callback then
    			if vape.ThreadFix then
    				setthreadidentity(8)
    			end

    			for _, v in lightingService:GetChildren() do
    				v.Parent = Folder
    			end

    			for _, v in {'Ambient', 'Brightness', 'ColorShift_Top', 'ColorShift_Bottom', 'ExposureCompensation', 'EnvironmentDiffuseScale', 'OutdoorAmbient'} do
    				lightingSettings[v] = lightingService[v]
    			end

    			Shader:Clean(lightingService.Changed:Connect(function(v)
    				if lightingSettings[v] and not changed then
    					changed = true
    					lightingSettings[v] = lightingService[v]
    					lightingService.Ambient = Color3.fromRGB(20, 20, 20)
    					lightingService.Brightness = 2.5
    					lightingService.ColorShift_Top = Color3.fromRGB(206, 206, 206)
    					lightingService.ColorShift_Bottom = Color3.fromRGB(231, 231, 231)
    					lightingService.ExposureCompensation = -0.5
    					lightingService.EnvironmentDiffuseScale = 0.15
    					lightingService.EnvironmentSpecularScale = 0.25
    					lightingService.OutdoorAmbient = Color3.fromRGB(30, 30, 30)
    					changed = false
    				end
    			end))

    			lightingService.Ambient = Color3.fromRGB(20, 20, 20)
    			lightingService.Brightness = 2.5
    			lightingService.ColorShift_Top = Color3.fromRGB(206, 206, 206)
    			lightingService.ColorShift_Bottom = Color3.fromRGB(231, 231, 231)
    			lightingService.ExposureCompensation = -0.5
    			lightingService.EnvironmentDiffuseScale = 0.15
    			lightingService.EnvironmentSpecularScale = 0.25
    			lightingService.OutdoorAmbient = Color3.fromRGB(30, 30, 30)

    			Objects.Atmosphere = Instance.new('Atmosphere')
    			Objects.Atmosphere.Color = Color3.fromRGB(103, 103, 103)
    			Objects.Atmosphere.Decay = Color3.fromRGB(80, 80, 80)
    			Objects.Atmosphere.Density = 0.3
    			Objects.Atmosphere.Glare = 0.8
    			Objects.Atmosphere.Haze = 0
    			Objects.Atmosphere.Offset = 0

    			Objects.Sky = Instance.new('Sky')
    			Objects.Sky.CelestialBodiesShown = true
    			Objects.Sky.SkyboxBk = 'http://www.roblox.com/asset/?id=245710263'
    			Objects.Sky.SkyboxDn = 'http://www.roblox.com/asset/?id=245710630'
    			Objects.Sky.SkyboxFt = 'http://www.roblox.com/asset/?id=245710380'
    			Objects.Sky.SkyboxLf = 'http://www.roblox.com/asset/?id=245710319'
    			Objects.Sky.SkyboxRt = 'http://www.roblox.com/asset/?id=245710230'
    			Objects.Sky.SkyboxUp = 'http://www.roblox.com/asset/?id=245710496'

    			Objects.Bloom = Instance.new('BloomEffect')
    			Objects.Bloom.Intensity = 1
    			Objects.Bloom.Size = 56
    			Objects.Bloom.Threshold = 0.5

    			Objects.Bloom2 = Instance.new('BloomEffect')
    			Objects.Bloom2.Intensity = 0
    			Objects.Bloom2.Size = 120
    			Objects.Bloom2.Threshold = 1

    			Objects.ColorCorrection = Instance.new('ColorCorrectionEffect')
    			Objects.ColorCorrection.Brightness = 0.15
    			Objects.ColorCorrection.Contrast = 0.5
    			Objects.ColorCorrection.Saturation = 0.2
    			Objects.ColorCorrection.TintColor = Color3.fromRGB(255, 245, 231)
    			Objects.ColorCorrection.Enabled = false

    			Objects.ColorCorrection2 = Instance.new('ColorCorrectionEffect')
    			Objects.ColorCorrection2.Brightness = 0.1
    			Objects.ColorCorrection2.Contrast = 0.3
    			Objects.ColorCorrection2.Saturation = -0.2

    			Objects.ColorCorrection3 = Instance.new('ColorCorrectionEffect')
    			Objects.ColorCorrection3.Brightness = 0
    			Objects.ColorCorrection3.Contrast = 0.05
    			Objects.ColorCorrection3.Saturation = 0
    			Objects.ColorCorrection3.TintColor = Color3.fromRGB(255,255,255)

    			Objects.DepthOfField = Instance.new('DepthOfFieldEffect')
    			Objects.DepthOfField.FarIntensity = 0.1
    			Objects.DepthOfField.InFocusRadius = 30

    			Objects.SunRays = Instance.new('SunRaysEffect')

    			Objects.SunRays2 = Instance.new('SunRaysEffect')
    			Objects.SunRays2.Intensity = 0.2
    			Objects.SunRays2.Spread = 0.2

    			Objects.SunRays3 = Instance.new('SunRaysEffect')
    			Objects.SunRays3.Intensity = 0.04
    			Objects.SunRays3.Spread = 1

    			for _, v in Objects do
    				v.Parent = lightingService
    			end
    		else
    			for _, v in Objects do
    				v:Destroy()
    			end

    			for _, v in Folder:GetChildren() do
    				v.Parent = lightingService
    			end

    			for i, v in lightingSettings do
    				lightingService[i] = v
    			end

    			table.clear(Objects)
    		end
    	end
    })
end)

run(function()
    local StorageESP
    local List
    local Background
    local Color
    local Reference = {}
    local Connections = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function nearStorageItem(item)
    	for _, v in List.ListEnabled do
    		if item:find(v) then
    			return v
    		end
    	end
    	return nil
    end

    local function refreshAdornee(v)
    	local chest = v.Adornee:FindFirstChild('ChestFolderValue')
    	chest = chest and chest.Value or nil
    	if not chest then
    		v.Enabled = false
    		return
    	end

    	local chestitems = chest and chest:GetChildren() or {}
    	for _, obj in v.Frame:GetChildren() do
    		if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
    			obj:Destroy()
    		end
    	end

    	v.Enabled = false
    	local alreadygot = {}
    	for _, item in chestitems do
    		if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
    			alreadygot[item.Name] = true
    			v.Enabled = true
    			local blockimage = Instance.new('ImageLabel')
    			blockimage.Size = UDim2.fromOffset(32, 32)
    			blockimage.BackgroundTransparency = 1
    			blockimage.Image = bedwars.getIcon({ itemType = item.Name }, true)
    			blockimage.Parent = v.Frame
    		end
    	end
    	table.clear(chestitems)
    end

    local function Removing(v)
    	local billboard = Reference[v]
    	if billboard then
    		billboard:Destroy()
    		Reference[v] = nil
    	end

    	local connections = Connections[v]
    	if connections then
    		for _, connection in connections do
    			connection:Disconnect()
    		end
    		table.clear(connections)
    		Connections[v] = nil
    	end
    end

    local function Clear()
    	local references = table.clone(Reference)
    	for v in references do
    		Removing(v)
    	end
    	table.clear(references)
    	Folder:ClearAllChildren()
    end

    local function Added(v)
    	local chest = v:WaitForChild('ChestFolderValue', 3)
    	if not (chest and StorageESP.Enabled and v:HasTag('chest')) then
    		return
    	end
    	if Reference[v] then
    		Removing(v)
    	end
    	chest = chest.Value
    	if not chest then
    		return
    	end
    	local billboard = Instance.new('BillboardGui')
    	billboard.Parent = Folder
    	billboard.Name = 'chest'
    	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    	billboard.Size = UDim2.fromOffset(36, 36)
    	billboard.AlwaysOnTop = true
    	billboard.ClipsDescendants = false
    	billboard.Adornee = v
    	local blur = addBlur(billboard)
    	blur.Visible = Background.Enabled
    	local frame = Instance.new('Frame')
    	frame.Size = UDim2.fromScale(1, 1)
    	frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
    	frame.Parent = billboard
    	local layout = Instance.new('UIListLayout')
    	layout.FillDirection = Enum.FillDirection.Horizontal
    	layout.Padding = UDim.new(0, 4)
    	layout.VerticalAlignment = Enum.VerticalAlignment.Center
    	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	local layoutConnection = layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
    		billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
    	end)
    	layout.Parent = frame
    	local corner = Instance.new('UICorner')
    	corner.CornerRadius = UDim.new(0, 4)
    	corner.Parent = frame
    	Reference[v] = billboard
    	Connections[v] = {
    		layoutConnection,
    		chest.ChildAdded:Connect(function(item)
    			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
    				refreshAdornee(billboard)
    			end
    		end),
    		chest.ChildRemoved:Connect(function(item)
    			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
    				refreshAdornee(billboard)
    			end
    		end),
    	}
    	task.spawn(refreshAdornee, billboard)
    end

    StorageESP = vape.Categories.Render:CreateModule({
    	Name = 'Storage ESP',
    	Function = function(callback)
    		if callback then
    			StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
    			StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removing))
    			StorageESP:Clean(Clear)
    			for _, v in collectionService:GetTagged('chest') do
    				task.spawn(Added, v)
    			end
    		else
    			Clear()
    		end
    	end,
    	Tooltip = 'Displays items in chests'
    })
    List = StorageESP:CreateTextList({
    	Name = 'Item',
    	Function = function()
    		for _, v in Reference do
    			task.spawn(refreshAdornee, v)
    		end
    	end,
    })
    Background = StorageESP:CreateToggle({
    	Name = 'Background',
    	Function = function(callback)
    		if Color and Color.Object then
    			Color.Object.Visible = callback
    		end
    		for _, v in Reference do
    			v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
    			v.Blur.Visible = callback
    		end
    	end,
    	Default = true,
    })
    Color = StorageESP:CreateColorSlider({
    	Name = 'Background Color',
    	DefaultValue = 0,
    	DefaultOpacity = 0.5,
    	Function = function(hue, sat, val, opacity)
    		for _, v in Reference do
    			v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
    			v.Frame.BackgroundTransparency = 1 - opacity
    		end
    	end,
    	Darker = true,
    })
end)

run(function()
    local StreamRemover
    local old, new

    StreamRemover = vape.Categories.Render:CreateModule({
    	Name = 'Stream Remover',
    	Function = function(call)
    		if call then
    			old = bedwars.GamePlayer.canSeeThroughDisguise
    			if typeof(old) ~= 'function' then
    				old = nil
    				return
    			end
    			new = function(...)
    				return StreamRemover.Enabled or old(...)
    			end
    			bedwars.GamePlayer.canSeeThroughDisguise = new
    		else
    			if old and bedwars.GamePlayer.canSeeThroughDisguise == new then
    				bedwars.GamePlayer.canSeeThroughDisguise = old
    			end
    			old, new = nil, nil
    		end
    	end,
    	Tooltip = 'Disables player\'s streamer mode clientsidedly.'
    })
end)

run(function()
    local TrapESP
    local Background
    local Color

    local Reference = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local function Added(v)
    	local billboard = Instance.new('BillboardGui')
    	billboard.Parent = Folder
    	billboard.Name = 'bed'
    	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    	billboard.Size = UDim2.fromOffset(36, 36)
    	billboard.AlwaysOnTop = true
    	billboard.ClipsDescendants = false
    	billboard.Adornee = v
    	local blur = addBlur(billboard)
    	blur.Visible = Background.Enabled
    	local frame = Instance.new('Frame')
    	frame.Size = UDim2.fromScale(1, 1)
    	frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    	frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
    	frame.Parent = billboard
    	local image = Instance.new('ImageLabel')
    	image.Size = UDim2.fromOffset(32, 32)
    	image.BackgroundTransparency = 1
    	image.Image = bedwars.getIcon({ itemType = 'snap_trap' }, true)
    	image.Parent = frame
    	local layout = Instance.new('UIListLayout')
    	layout.FillDirection = Enum.FillDirection.Horizontal
    	layout.Padding = UDim.new(0, 4)
    	layout.VerticalAlignment = Enum.VerticalAlignment.Center
    	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    	layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
    		billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
    	end)
    	layout.Parent = frame
    	local corner = Instance.new('UICorner')
    	corner.CornerRadius = UDim.new(0, 4)
    	corner.Parent = frame
    	Reference[v] = billboard
    end

    TrapESP = vape.Categories.Render:CreateModule({
    	Name = 'Trap ESP',
    	Function = function(callback)
    		if callback then
    			repeat
    				task.wait()
    			until store.matchState ~= 0 or not TrapESP.Enabled
    			if not TrapESP.Enabled then
    				return
    			end

    			TrapESP:Clean(collectionService:GetInstanceAddedSignal('snap_trap'):Connect(Added))
    			TrapESP:Clean(collectionService:GetInstanceRemovedSignal('snap_trap'):Connect(function(v)
    				if Reference[v] then
    					Reference[v]:Destroy()
    					Reference[v] = nil
    				end
    			end))
    		else
    			table.clear(Reference)
    			Folder:ClearAllChildren()
    		end
    	end,
    	Tooltip = 'Render traps placed by other teams'
    })

    Background = TrapESP:CreateToggle({
    	Name = 'Background',
    	Function = function(callback)
    		if Color and Color.Object then
    			Color.Object.Visible = callback
    		end
    		for _, v in Reference do
    			v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
    			v.Blur.Visible = callback
    		end
    	end,
    	Default = true
    })
    Color = TrapESP:CreateColorSlider({
    	Name = 'Background Color',
    	DefaultValue = 0,
    	DefaultOpacity = 0.5,
    	Function = function(hue, sat, val, opacity)
    		for _, v in Reference do
    			v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
    			v.Frame.BackgroundTransparency = 1 - opacity
    		end
    	end,
    	Darker = true
    })
end)

run(function()
    local ViewmodelVisuals
    local StrokeColor
    local Color

    local Instances = {}

    local function pruneDead()
        for i = #Instances, 1, -1 do
            if not Instances[i].Parent then
                table.remove(Instances, i)
            end
        end
    end

    local function createHighlight(visual)
        local handle = visual:FindFirstChild('Handle')
        if not handle then return end
        local highlight = Instance.new('Highlight')
        highlight.Name = 'ViewmodelVisuals'
        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        highlight.FillTransparency = Color.Opacity
        highlight.OutlineTransparency = StrokeColor.Opacity
        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)
        highlight.Parent = handle
        ViewmodelVisuals:Clean(highlight)
        table.insert(Instances, highlight)
    end

    ViewmodelVisuals = vape.Categories.Render:CreateModule({
        Name = 'Viewmodel Visuals',
        Function = function(call)
            if call then
                local camera, viewmodel
                repeat
                    camera = workspace.CurrentCamera
                    viewmodel = camera and camera:FindFirstChild('Viewmodel')
                    if not viewmodel then task.wait(0.1) end
                until viewmodel or not ViewmodelVisuals.Enabled
                if not ViewmodelVisuals.Enabled then return end

                for i,v in viewmodel:GetChildren() do
                    if v:IsA('Accessory') then
                        createHighlight(v)
                        break
                    end
                end

                ViewmodelVisuals:Clean(viewmodel.ChildAdded:Connect(function(visual)
                    pruneDead()
                    if visual:IsA('Accessory') then
                        createHighlight(visual)
                    end
                end))

                ViewmodelVisuals:Clean(camera.ChildAdded:Connect(function(visual)
                    if visual.Name == 'Viewmodel' then
                        ViewmodelVisuals:Toggle()
                        ViewmodelVisuals:Toggle()
                    end
                end))
            else
                table.clear(Instances)
            end
        end
    })

    Color = ViewmodelVisuals:CreateColorSlider({
        Name = 'Color',
        Default = Color3.new(1, 1, 1),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.FillColor = Color3.fromHSV(hue, sat, val)
                v.FillTransparency = opacity
            end
        end
    })
    StrokeColor = ViewmodelVisuals:CreateColorSlider({
        Name = 'Stroke Color',
        Default = Color3.new(),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.OutlineColor = Color3.fromHSV(hue, sat, val)
                v.OutlineTransparency = opacity
            end
        end
    })
end)

--[[
    Utility
]]

run(function()
    local AntiLasso
    local Chance
    local Check
    local currentConnections = {}
    local currentCharacter
    local activeLasso
    local ignoredLasso
    local lassoVersion = 0
    local returnFilter = RaycastParams.new()
    local returnOverlap = OverlapParams.new()

    returnFilter.FilterType = Enum.RaycastFilterType.Exclude
    returnFilter.RespectCanCollide = true
    returnFilter.IgnoreWater = true
    returnOverlap.FilterType = Enum.RaycastFilterType.Exclude
    returnOverlap.RespectCanCollide = true

    local function disconnectCharacter()
        for _, connection in currentConnections do
            connection:Disconnect()
        end
        table.clear(currentConnections)
        currentCharacter = nil
    end

    local function isFinite(value)
        return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
    end

    local function isFiniteCFrame(value)
        if typeof(value) ~= 'CFrame' then return false end
        for _, component in {value:GetComponents()} do
            if not isFinite(component) then return false end
        end
        return true
    end

    local function getLassoObject(character)
        for _, child in character:GetChildren() do
            if child:FindFirstChild('Rope', true) then
                return child
            end
        end
    end

    local function hasClearance(character, root, position)
        returnOverlap.FilterDescendantsInstances = {character, gameCamera}
        for _, part in workspace:GetPartBoundsInBox(CFrame.new(position), root.Size * Vector3.new(0.9, 1, 0.9), returnOverlap) do
            local queryIgnored = bedwars.QueryUtil.isQueryIgnored
            if part.CanCollide and not (type(queryIgnored) == 'function' and queryIgnored(bedwars.QueryUtil, part)) then
                return false
            end
        end
        return true
    end

    local function getSafeReturnCFrame(event)
        local character, root, saved = event.character, event.root, event.cframe
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not isFiniteCFrame(saved) or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
        local position = saved.Position
        if position.Y <= workspace.FallenPartsDestroyHeight + 12 then return end

        returnFilter.FilterDescendantsInstances = {character, gameCamera}
        local ground = workspace:Raycast(position + Vector3.yAxis * 3, -Vector3.yAxis * 99, returnFilter)
        if ground and position.Y - ground.Position.Y >= 1 and hasClearance(character, root, position) then
            return saved
        end

        local offsets = {Vector3.zero}
        for radius = 3, 12, 3 do
            for _, direction in {
                Vector3.xAxis,
                -Vector3.xAxis,
                Vector3.zAxis,
                -Vector3.zAxis,
                Vector3.new(1, 0, 1).Unit,
                Vector3.new(1, 0, -1).Unit,
                Vector3.new(-1, 0, 1).Unit,
                Vector3.new(-1, 0, -1).Unit
            } do
                table.insert(offsets, direction * radius)
            end
        end

        local best, bestDistance
        for _, offset in offsets do
            local origin = position + offset + Vector3.yAxis * 12
            local result = workspace:Raycast(origin, -Vector3.yAxis * 72, returnFilter)
            if result and result.Instance.CanCollide then
                local candidate = Vector3.new(origin.X, result.Position.Y + humanoid.HipHeight + root.Size.Y / 2, origin.Z)
                local distance = (candidate - position).Magnitude
                if candidate.Y > workspace.FallenPartsDestroyHeight + 12 and hasClearance(character, root, candidate)
                    and (not bestDistance or distance < bestDistance)
                then
                    best, bestDistance = candidate, distance
                end
            end
        end
        return best and CFrame.new(best) * saved.Rotation or nil
    end

    local function clearLasso(event)
        if activeLasso ~= event then return end
        activeLasso = nil
        if event.root.Parent then
            event.root.Anchored = false
        end
    end

    local function returnPlayer(event, visualReleased)
        if activeLasso ~= event or event.returned or not AntiLasso.Enabled then return false end
        if collectionService:HasTag(event.character, 'LassoHooked') then return false end
        if not visualReleased and getLassoObject(event.character) then return false end
        local root = event.root
        local returnCFrame = getSafeReturnCFrame(event)
        if not returnCFrame or lplr.Character ~= event.character or not entitylib.isAlive or entitylib.character.RootPart ~= root then
            clearLasso(event)
            return true
        end
        event.returned = true
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = returnCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        if activeLasso == event then
            activeLasso = nil
        end
        return true
    end

    local function waitForRelease(event)
        task.spawn(function()
            local visualReleasedAt
            while activeLasso == event and AntiLasso.Enabled and lplr.Character == event.character and event.root.Parent do
                local tagged = collectionService:HasTag(event.character, 'LassoHooked')
                local visual = getLassoObject(event.character)
                if not tagged and not visual then
                    returnPlayer(event)
                    return
                end
                if not tagged then
                    visualReleasedAt = visualReleasedAt or tick()
                    if tick() - visualReleasedAt >= 1 then
                        returnPlayer(event, true)
                        return
                    end
                else
                    visualReleasedAt = nil
                end
                task.wait(0.05)
            end
        end)
    end

    local function startLasso(character, nativeEvent)
        if not AntiLasso.Enabled or character ~= lplr.Character or ignoredLasso == character then return end
        if activeLasso and activeLasso.character == character then
            if not nativeEvent or not activeLasso.releaseSeen then return end
            clearLasso(activeLasso)
        end
        if Random.new(os.clock()):NextNumber(1, 100) > Chance.Value or Check.Enabled and not entitylib.EntityPosition({
            Range = 50,
            Part = 'RootPart',
            Players = true
        }) then
            if nativeEvent then ignoredLasso = character end
            return
        end
        local root = character:FindFirstChild('HumanoidRootPart') or character.PrimaryPart
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if not root or not humanoid or humanoid.Health <= 0 or not isFiniteCFrame(root.CFrame) then return end
        if activeLasso then clearLasso(activeLasso) end
        lassoVersion += 1
        local event = {
            cframe = root.CFrame,
            character = character,
            root = root,
            token = lassoVersion
        }
        activeLasso = event
        root.Anchored = true
        waitForRelease(event)
    end

    local function releaseLasso(character)
        if ignoredLasso == character then
            ignoredLasso = nil
            return
        end
        local event = activeLasso
        if not event or event.character ~= character then return end
        event.releaseSeen = true
        task.defer(function()
            local deadline = tick() + 1
            repeat
                if activeLasso ~= event or returnPlayer(event) then return end
                task.wait()
            until tick() >= deadline
            returnPlayer(event, true)
        end)
    end

    local function Added(character)
        local previousCharacter = currentCharacter
        disconnectCharacter()
        if previousCharacter ~= character then ignoredLasso = nil end
        if not AntiLasso.Enabled or not character or not character.Parent then return end
        if activeLasso then clearLasso(activeLasso) end
        currentCharacter = character
        table.insert(currentConnections, character.ChildAdded:Connect(function(child)
            if child:FindFirstChild('Rope', true) then
                startLasso(character)
            end
        end))
        table.insert(currentConnections, character.Destroying:Connect(function()
            if currentCharacter == character then
                disconnectCharacter()
            end
            if activeLasso and activeLasso.character == character then
                clearLasso(activeLasso)
            end
        end))
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if humanoid then
            table.insert(currentConnections, humanoid.Died:Connect(function()
                if activeLasso and activeLasso.character == character then
                    clearLasso(activeLasso)
                end
            end))
        end
        if collectionService:HasTag(character, 'LassoHooked') or getLassoObject(character) then
            startLasso(character, collectionService:HasTag(character, 'LassoHooked'))
        end
    end

    AntiLasso = vape.Categories.Utility:CreateModule({
        Name = 'Anti Lasso',
        Function = function(callback)
            if callback then
                AntiLasso:Clean(collectionService:GetInstanceAddedSignal('LassoHooked'):Connect(function(character)
                    if character == lplr.Character then
                        startLasso(character, true)
                    end
                end))
                AntiLasso:Clean(collectionService:GetInstanceRemovedSignal('LassoHooked'):Connect(function(character)
                    if character == lplr.Character then
                        releaseLasso(character)
                    end
                end))
                AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
                    task.defer(function()
                        if AntiLasso.Enabled and ent and ent.Character then
                            Added(ent.Character)
                        end
                    end)
                end))
                AntiLasso:Clean(lplr.OnTeleport:Connect(function()
                    if activeLasso then clearLasso(activeLasso) end
                    ignoredLasso = nil
                    disconnectCharacter()
                end))
                if entitylib.isAlive then
                    Added(lplr.Character)
                end
            else
                lassoVersion += 1
                ignoredLasso = nil
                disconnectCharacter()
                if activeLasso then clearLasso(activeLasso) end
            end
        end,
        Tooltip = 'Prevents you from getting pulled by lasso projectile.'
    })

    Chance = AntiLasso:CreateSlider({
        Name = 'Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%'
    })
    Check = AntiLasso:CreateToggle({Name = 'Only when targeting'})
end)

run(function()
    local AntiSuffocate

    AntiSuffocate = vape.Categories.Utility:CreateModule({
    	Name = 'Anti Suffocate',
    	Function = function(call)
    		if call then
    			repeat
    				if entitylib.isAlive then
    					if
    						getPlacedBlock(entitylib.character.RootPart.Position)
    						and (
    							getPlacedBlock(entitylib.character.RootPart.Position + Vector3.new(0, 2, 0))
    							and getPlacedBlock(entitylib.character.RootPart.Position - Vector3.new(0, 2, 0))
    						)
    					then
    						entitylib.character.RootPart.CFrame += Vector3.new(0, 0.5, 0)
    						if entitylib.character.RootPart.AssemblyLinearVelocity.Y < -1 then
    							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
    						end
    					end
    				end
    				task.wait()
    			until not AntiSuffocate.Enabled
    		end
    	end,
    	Tooltip = 'Prevents you from suffocating in blocks',
    })
end)

run(function()
    local AutoBalloon

    AutoBalloon = vape.Categories.Utility:CreateModule({
        Name = 'Auto Balloon',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
                if not AutoBalloon.Enabled then return end

                local lowestpoint = math.huge
                for _, v in store.blocks do
                    local point = (v.Position.Y - (v.Size.Y / 2)) - 50
                    if point < lowestpoint then 
                        lowestpoint = point 
                    end
                end

                repeat
                    if entitylib.isAlive then
                        if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
                            local balloon = getItem('balloon')
                            if balloon then
                                for _ = 1, 3 do 
                                    bedwars.BalloonController:inflateBalloon() 
                                end
                            end
                            task.wait(0.1)
                        end
                    end
                    task.wait(0.1)
                until not AutoBalloon.Enabled
            end
        end,
        Tooltip = 'Inflates when you fall into the void'
    })
end)

run(function()
    local AutoCounter
    local Mode
    local Range
    local Limit
    local AutoSwitch

    local function getAttackData()
        if Limit.Enabled then
            local tool = store.hand.tool
            return tool and tool.Name == 'tnt' and tool or nil
        end
        local item = getItem('tnt')
        return item and item.tool or nil
    end

    AutoCounter = vape.Categories.Utility:CreateModule({
        Name = 'Auto Counter TNT',
        Function = function(callback)
            if callback then
                local tnts, placed = {}, {}
                AutoCounter:Clean(workspace.ChildAdded:Connect(function(v)
                    if v.Name == 'tnt' then
                        table.insert(tnts, v)
                        v.Destroying:Once(function()
                            local index = table.find(tnts, v)
                            if index then
                                table.remove(tnts, index)
                            end
                        end)
                    end
                end))
                repeat
                    for pos, expiry in placed do
                        if expiry <= tick() then
                            placed[pos] = nil
                        end
                    end
                    if entitylib.isAlive then
                        local item = getAttackData()
                        if item then
                            local localPosition = entitylib.character.RootPart.Position
                            for _, v in tnts do
                                local roundedPos = Vector3.new(math.round(v.Position.X), math.round(v.Position.Y), math.round(v.Position.Z))
                                if v.Velocity.Y >= 0 and not placed[roundedPos] and (localPosition - v.Position).Magnitude <= Range.Value then
                                    if not Limit.Enabled and AutoSwitch.Enabled then
                                        local hotbar = getHotbar(item)
                                        switchItem(item)
                                        if hotbar then
                                            hotbarSwitch(hotbar)
                                        end
                                    end
                                    placed[roundedPos] = tick() + 3
                                    task.spawn(bedwars.placeBlock, v.Position, item.Name)
                                    task.wait(0.12)
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not AutoCounter.Enabled
            end
        end,
        Tooltip = 'Automatically places tnt on opponent\'s tnt'
    })

    Mode = AutoCounter:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On key'},
        Default = 'Toggle'
    })
    Range = AutoCounter:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 60,
        Default = 30
    })
    Limit = AutoCounter:CreateToggle({
        Name = 'Limit to item',
        Function = function(callback)
            pcall(function()
                AutoSwitch.Object.Visible = not callback
            end)
        end
    })
    AutoSwitch = AutoCounter:CreateToggle({
        Name = 'Auto Switch',
        Function = function(callback)
            Limit.Object.Visible = not callback
        end,
        Default = true
    })
end)

run(function()
    local AutoLasso
    local Targets
    local Range
    local Angle

    local projectileRemote, lastshot = {InvokeServer = function() end}, tick()
    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

    AutoLasso = vape.Categories.Utility:CreateModule({
        Name = 'Auto Lasso',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive and tick() > lastshot then
                        local lasso = getItem('lasso')
                        if lasso then
                            local ent = entitylib.EntityPosition({
                                Range = Range.Value,
                                Part = 'RootPart',
                                Wallcheck = Targets.Walls.Enabled,
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Sort = sortmethods.Distance
                            })

                            if ent then
                                local selfpos = entitylib.character.RootPart.Position
                                local localfacing = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
                                local delta = (ent.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
                                if delta.Magnitude > 0.001 and math.acos(math.clamp(localfacing:Dot(delta.Unit), -1, 1)) <= (math.rad(Angle.Value) / 2) then
                                    local meta = bedwars.ProjectileMeta.lasso
                                    local speed = meta and meta.launchVelocity or 200
                                    local gravity = meta and meta.gravitationalAcceleration or 135
                                    local targetVelocity = ent.RootPart.AssemblyLinearVelocity
                                    local targetAirborne = ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
                                    local calc, _, travelTime = prediction.SolveTrajectory(selfpos, speed, gravity, ent.RootPart.Position, targetVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, targetAirborne, ent.RootPart.Position, ent.RootPart, nil, true)
                                    if calc and travelTime and travelTime <= (meta and meta.lifetimeSec or 3) then
                                        local old = store.inventory.hotbarSlot
                                        local new = getHotbar(lasso.tool)
                                        if new then
                                            switchItem(lasso.tool)
                                            hotbarSwitch(new)
                                        end
                                        
                                        local res = projectileRemote:InvokeServer(
                                            lasso.tool,
                                            'lasso',
                                            'lasso',
                                            selfpos, 
                                            selfpos, 
                                            CFrame.lookAt(selfpos, calc).LookVector * speed,
                                            httpService:GenerateGUID(true),
                                            {
                                                drawDurationSeconds = 1, 
                                                shotId = httpService:GenerateGUID(false)
                                            },
                                            workspace:GetServerTimeNow() - 0.045
                                        )
                                        if res then
                                            lastshot = tick() + 10.5 
                                        end
                                        hotbarSwitch(old)
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.05)
                until not AutoLasso.Enabled
            end
        end
    })

    Targets = AutoLasso:CreateTargets({Players = true})
    Range = AutoLasso:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 60,
        Default = 60,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
    Angle = AutoLasso:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 120
    })
end)

run(function()
    local AutoPearl
    local Legit
    local Back
    local Check
    local LandCheck
    local BackDelay
    local Limit

    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function()
    	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function firePearl(pos, spot, item)
    	if Check.Enabled then
    		for _, v in store.selfProjectiles do
    			if v.Name == 'telepearl' then
    				return
    			end
    		end
    	end
    	local hotbar, old = getHotbar(item.tool), store.hand

    	switchItem(item.tool)
    	if Legit.Enabled and hotbar then
    		hotbarSwitch(hotbar)
    	end

    	local meta = bedwars.ProjectileMeta.telepearl
    	local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
    	local landed = false

    	if calc then
    		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
    		local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
    		local res = projectileRemote:InvokeServer(
    			item.tool,
    			'telepearl',
    			'telepearl',
    			pos,
    			pos,
    			dir,
    			httpService:GenerateGUID(true),
    			{ 
                    drawDurationSeconds = 1, 
                    shotId = httpService:GenerateGUID(false) 
                },
    			workspace:GetServerTimeNow() - 0.045
    		)
    		task.spawn(function()
    			local timeout = tick() + 10
    			repeat
    				task.wait()
    			until not AutoPearl.Enabled or not projectile or not projectile.Parent or tick() >= timeout
    			landed = true
    		end)
    		if res then
    			pcall(function()
    				res.Parent = replicatedStorage
    			end)
    		end
    	else
    		landed = true
    	end

    	if Back.Enabled and LandCheck.Enabled then
    		repeat
    			task.wait()
    		until landed or not AutoPearl.Enabled
    	end
    	if Back.Enabled and old and old.tool then
    		task.wait(BackDelay:GetRandomValue())
    		switchItem(old.tool)
    		if Legit.Enabled and getHotbar(old.tool) then
    			hotbarSwitch(getHotbar(old.tool))
    		end
    	end
    end

    local function findNearGround(origin)
    	for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
    		for i = 1, 24 do
    			local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
    			if ray then
    				return ray.Position
    			end
    		end
    	end
    	return nil
    end

    AutoPearl = vape.Categories.Utility:CreateModule({
    	Name = 'Auto Pearl',
    	Function = function(callback)
    		if callback then
    			local check, lasty
    			repeat
    				if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'telepearl') then
    					local root = entitylib.character.RootPart
    					local pearl = getItem('telepearl')
    					rayCheck.FilterDescendantsInstances = {store.map}
    					rayCheck.CollisionGroup = root.CollisionGroup

    					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
    						lasty = root.CFrame
    					end

    					if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
    						if not check then
    							check = true
    							local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
    							if ground then
    								firePearl(root.Position, ground, pearl)
    							end
    						end
    					else
    						check = false
    					end
    				end
    				task.wait(0.1)
    			until not AutoPearl.Enabled
    		end
    	end,
    	Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
    })

    Legit = AutoPearl:CreateToggle({
    	Name = 'Legit Switch',
    	Tooltip = 'Visualizes the switching clientside',
    	Default = true
    })
    Back = AutoPearl:CreateToggle({
    	Name = 'Switch back',
    	Default = true,
    	Function = function(callback)
    		if BackDelay then
    			BackDelay.Object.Visible = callback
    		end
    		if LandCheck then
    			LandCheck.Object.Visible = callback
    		end
    	end,
    	Tooltip = 'Switches back to the last slot before pearl'
    })
    LandCheck = AutoPearl:CreateToggle({
    	Name = 'Only after landed',
    	Tooltip = 'Only switches back after your pearl landed',
    	Darker = true
    })
    Check = AutoPearl:CreateToggle({
    	Name = 'Pearl check',
    	Tooltip = 'Doesn\'t throw a pearl if ur already pearling',
    	Default = true
    })
    BackDelay = AutoPearl:CreateTwoSlider({
    	Name = 'Switch Back Delay',
    	Min = 0,
    	Max = 2,
    	DefaultMin = 0.1,
    	DefaultMax = 0.2,
    	Darker = true
    })
    Limit = AutoPearl:CreateToggle({
    	Name = 'Limit to item',
    	Tooltip = 'Only throws pearl when holding a pearl'
    })
end)

run(function()
    local AutoPlay
    local Random

    local function isEveryoneDead()
        return #bedwars.Store:getState().Party.members <= 0
    end

    local function joinQueue()
        if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
            if Random.Enabled then
                local listofmodes = {}
                for i, v in bedwars.QueueMeta do
                    if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
                        table.insert(listofmodes, i) 
                    end
                end
                bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
            else
                bedwars.QueueController:joinQueue(store.queueType)
            end
        end
    end

    AutoPlay = vape.Categories.Utility:CreateModule({
        Name = 'Auto Play',
        Function = function(callback)
            if callback then
                AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
                        joinQueue()
                    end
                end))
                AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
            end
        end,
        Tooltip = 'Automatically queues after the match ends.'
    })
    Random = AutoPlay:CreateToggle({
        Name = 'Random',
        Tooltip = 'Chooses a random mode'
    })
end)

run(function()
    local AutoRelease
    local Percentage
    local Delay

    local launchHook, last = nil, 0
    local charge = 0

    AutoRelease = vape.Categories.Utility:CreateModule({
    	Name = 'Auto Release',
    	Function = function(call)
    		if call then
    			launchHook = bedwars.ProjectileLaunchHook:Add('AutoRelease', 20, function(nextLaunch, ...)
    				local projmeta = select(2, ...)
    				if projmeta and typeof(projmeta) == 'table' then
    					charge = (projmeta.velocityMultiplier / 1) * 100
    					last = os.clock() + 0.1
    				end

    				return nextLaunch(...)
    			end)

    			repeat
    				if not bedwars.ProjectileCharge:IsOwned() and last > os.clock() and charge >= Percentage.Value then
    					task.wait(Delay.Value)
    					mouse1click()
    					task.wait(0.2)
    				end
    				task.wait()
    			until not AutoRelease.Enabled
    		else
    			if launchHook then
    				launchHook()
    				launchHook = nil
    			end
    		end
    	end,
        Tooltip = 'Automatically releases ur projectile source when\nat certain charging percentage'
    })

    Percentage = AutoRelease:CreateSlider({
    	Name = 'Percentage',
    	Min = 0,
    	Max = 100,
    	Suffix = '%',
    	Default = 100,
    })
    Delay = AutoRelease:CreateSlider({
    	Name = 'Release delay',
    	Min = 0,
    	Max = 5,
    	Default = 0.5,
    	Decimal = 10,
    	Suffix = function(val)
    		return val <= 1 and 'sec' or 'secs'
    	end,
    })
end)

run(function()
    local AutoShoot
    local Targets
    local Check
    local Range
    local Projectiles
    local Delay
    local Next
    local Rate

    local function getAmmo(check)
    	for _, item in store.inventory.inventory.items do
    		if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
    			return item.itemType
    		end
    	end
    	return
    end

    local function getProjectiles()
    	local items = {}
    	for _, item in store.inventory.inventory.items do
    		local proj = bedwars.ItemMeta[item.itemType].projectileSource
    		local ammo = proj and getAmmo(proj)
    		if ammo and (table.find(Projectiles.ListEnabled, ammo) or table.find(Projectiles.ListEnabled, item.itemType)) then
    			table.insert(items, {
    				item,
    				ammo,
    				proj.projectileType(ammo),
    				proj,
    			})
    		end
    	end
    	return items
    end

    local FireRate = {}

    local function getAttackData()
    	local hand = store.hand
    	if not hand or not hand.tool then
    		return
    	end

    	local meta = bedwars.ItemMeta[hand.tool.Name]
    	if not meta or not meta.projectileSource then
    		return
    	end

    	if (FireRate[hand.tool.Name] or 0) > tick() then
    		return
    	end

    	local ammo = getAmmo(meta.projectileSource)
    	local frosty = hand.tool.Name:find('frost_staff')
    	if not ammo and not frosty then
    		return
    	end

    	if frosty then
    		ammo = hand.tool.Name:gsub('frost_staff', 'frosty_snowball')
    	end

    	local callback = canDebug and meta.projectileType or function(res)
    		return 'arrow'
    	end

    	return hand, meta, ammo, callback(ammo)
    end

    local function shootFunc(ignore)
    	if not inputService.MouseEnabled or ignore then
    		local proj, meta, ammo, projectile = getAttackData()

    		if proj then
    			local projmeta = bedwars.ProjectileMeta[projectile]
    			if not projmeta then return end
    			local projSpeed = projmeta.launchVelocity

    			local selfpos = entitylib.character.RootPart.Position
    			local calc = selfpos + gameCamera.CFrame.LookVector * 50
    			local ent = ignore and entitylib.EntityPosition({
                    Part = 'RootPart',
                    Range = 1000,
                    Players = true,
                    NPCs = true,
                    Wallcheck = true,
                }) or nil
    			local shootPosition = (CFrame.new(selfpos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    			if ent then
    				local targetPosition = ent.RootPart.Position
    				local targetVelocity = ent.RootPart.AssemblyLinearVelocity
    				local targetAirborne = ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
    				shootPosition = (CFrame.new(selfpos, targetPosition) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
    				local travelTime
    				calc, _, travelTime = prediction.SolveTrajectory(
    					shootPosition,
    					projSpeed,
    					projmeta.gravitationalAcceleration or 196.2,
    					targetPosition,
    					targetVelocity,
    					workspace.Gravity,
    					ent.HipHeight,
    					ent.Jumping and 42.6 or nil,
    					store.airRay,
    					targetAirborne,
    					ent.RootPart.Position,
    					ent.RootPart,
    					nil,
    					true
    				)
    				if not calc or not travelTime or travelTime > (projmeta.lifetimeSec or 3) then return end
    			end

    			local dir = CFrame.lookAt(shootPosition, calc).LookVector
    			local id = httpService:GenerateGUID(true)

    			--bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
    			bedwars.Client:Get(remotes.FireProjectile):CallServerAsync(proj.tool, ammo, projectile, shootPosition, selfpos, dir * projSpeed, id, {
                    drawDurationSeconds = 1,
                    shotId = httpService:GenerateGUID(false),
                }, workspace:GetServerTimeNow() - 0.045):andThen(function(res)
                    if res then
                        res.Parent = replicatedStorage
                    end
                end)
    			local shoot = meta.projectileSource.launchSound
    			shoot = shoot and shoot[math.random(1, #shoot)] or nil
    			if shoot then
    				bedwars.SoundManager:playSound(shoot)
    			end
    		end
    	else
    		mouse1click()
    	end
    end

    AutoShoot = vape.Categories.Utility:CreateModule({
    	Name = 'Auto Shoot',
    	Function = function(call)
    		if call then
    			local start = tick()
    			repeat
    				if store.hand.toolType == 'sword' then
    					if (tick() - bedwars.SwordController.lastSwing) < 0.29 and (not Check.Enabled or entitylib.EntityPosition({
    						Range = Range.Value,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled
    					})) then
    					if tick() > start then
    							for _, data in getProjectiles() do
    								if (FireRate[data[1].itemType] or 0) < tick() then
    									local hotbar, old = getHotbar(data[1].tool), store.hand.tool and getHotbar(store.hand.tool) or 0
    									if hotbar and old and hotbarSwitch(hotbar) then
    										local silentAura = vape.Modules['Silent Aura']
    										local autoClicker = vape.Modules['Auto Clicker']
    										local ignore = silentAura and silentAura.Enabled or not inputService.MouseEnabled
    										task.wait(Delay.Value)
    										if not AutoShoot.Enabled then
    											hotbarSwitch(old)
    											break
    										end
    										shootFunc()
    										if autoClicker and autoClicker.Enabled and not ignore then
    											runService.PostSimulation:Wait()
    											if AutoShoot.Enabled then mouse1press() end
    										end
    										task.wait(Delay.Value)
    										FireRate[data[1].itemType] = tick() + (data[4].fireDelaySec + Rate:GetRandomValue())
    										hotbarSwitch(old)
    										task.wait(Next.Value)
    										if (tick() - bedwars.SwordController.lastSwing) > 0.29 then
    											break
    										end
    									end
    								end
    							end
    						end
    					else
    						start = tick() + 0.75
    					end
    				end
    				task.wait(0.1)
    			until not AutoShoot.Enabled
    		end
    	end,
        Tooltip = 'Automatically swaps to another projectile source while swinging ur sword'
    })

    Targets = AutoShoot:CreateTargets({Walls = true, Darker = true})
    Check = AutoShoot:CreateToggle({
    	Name = 'Target Check',
    	Default = true,
    	Function = function(callback)
    		Targets.Object.Visible = callback
    		pcall(function()
    			Range.Object.Visible = callback
    		end)
    	end
    })
    Range = AutoShoot:CreateSlider({
    	Name = 'Range',
    	Min = 1,
    	Max = 80,
    	Default = 65,
    	Darker = true,
    	Suffix = function(val)
    		return val <= 1 and 'stud' or 'studs'
    	end
    })
    Projectiles = AutoShoot:CreateTextList({
    	Name = 'Projectiles',
    	Default = {'arrow'},
    	Placeholder = 'projectile'
    })
    Rate = AutoShoot:CreateTwoSlider({
    	Name = 'Fire Rate',
    	Min = 0,
    	Max = 1,
    	DefaultMin = 0.05,
    	DefaultMax = 0.12,
    	Decimal = 100
    })
    Next = AutoShoot:CreateSlider({
    	Name = 'Change Delay',
    	Min = 0,
    	Max = 1,
    	Decimal = 100,
    	Suffix = 'seconds',
    	Default = 0.75
    })
    Delay = AutoShoot:CreateSlider({
    	Name = 'Delay',
    	Min = 0,
    	Max = 1,
    	Decimal = 100,
    	Suffix = 'seconds',
    	Default = 0.05
    })
end)

run(function()
    local AutoToxic
    local GG
    local Toggles, Lists, said, dead = {}, {}, {}

    local function sendMessage(name, obj, default)
        local tab = Lists[name].ListEnabled
        local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
        if not custommsg then return end
        if #tab > 1 and custommsg == said[name] then
            repeat 
                task.wait() 
                custommsg = tab[math.random(1, #tab)] 
            until custommsg ~= said[name]
        end
        said[name] = custommsg

        custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
        else
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
        end
    end

    AutoToxic = vape.Categories.Utility:CreateModule({
        Name = 'Auto Toxic',
        Function = function(callback)
            if callback then
                AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
                    if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
                        sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
                    elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
                        local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
                        sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
                    end
                end))
                AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                    if deathTable.finalKill then
                        local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
                        local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
                        if not killed or not killer then return end
                        if killed == lplr then
                            if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
                                dead = true
                                sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
                            end
                        elseif killer == lplr and Toggles.Kill.Enabled then
                            sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
                        end
                    end
                end))
                AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
                    if GG.Enabled then
                        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                            textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
                        else
                            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
                        end
                    end
                    
                    local myTeam = bedwars.Store:getState().Game.myTeam
                    if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
                        if Toggles.Win.Enabled then 
                            sendMessage('Win', nil, 'yall garbage') 
                        end
                    end
                end))
            end
        end,
        Tooltip = 'Says a message after a certain action'
    })
    GG = AutoToxic:CreateToggle({
        Name = 'AutoGG',
        Default = true
    })
    for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
        Toggles[v] = AutoToxic:CreateToggle({
            Name = v..' ',
            Function = function(callback)
                if Lists[v] then
                    Lists[v].Object.Visible = callback
                end
            end
        })
        Lists[v] = AutoToxic:CreateTextList({
            Name = v,
            Darker = true,
            Visible = false
        })
    end
end)

run(function()
    local AutoVoidDrop
    local OwlCheck

    AutoVoidDrop = vape.Categories.Utility:CreateModule({
        Name = 'Auto Void Drop',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
                if not AutoVoidDrop.Enabled then return end

                local lowestpoint = math.huge
                for _, v in store.blocks do
                    local point = (v.Position.Y - (v.Size.Y / 2)) - 50
                    if point < lowestpoint then
                        lowestpoint = point
                    end
                end

                repeat
                    if entitylib.isAlive then
                        local root = entitylib.character.RootPart
                        if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
                            if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
                                for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
                                    item = getItem(item)
                                    if item then
                                        item = bedwars.Client:Get(remotes.DropItem):CallServer({
                                            item = item.tool,
                                            amount = item.amount
                                        })

                                        if item then
                                            item:SetAttribute('ClientDropTime', tick() + 100)
                                        end
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoVoidDrop.Enabled
            end
        end,
        Tooltip = 'Drops resources when you fall into the void'
    })
    OwlCheck = AutoVoidDrop:CreateToggle({
        Name = 'Owl check',
        Default = true,
        Tooltip = 'Refuses to drop items if being picked up by an owl'
    })
end)

run(function()
    local BackTrack
    local Mode
    local Latency
    local Tick

    BackTrack = vape.Categories.Utility:CreateModule({
        Name = 'Back Track',
        Function = function(callback)
            if callback then
                repeat
                    local ent = entitylib.EntityPosition({
                        Part = 'RootPart',
                        Range = 22,
                        Players = true,
                        Wallcheck = true,
                    })

                    if ent then
                        if Mode.Value == 'Manual' then
                            setfflag('TargetTimeDelayFacctorTenths', '50000')
                            task.wait(0.05 * Tick.Value)
                            setfflag('TargetTimeDelayFacctorTenths', '20')
                            task.wait(0.05 * Tick.Value)
                        else
                            setfflag('TargetTimeDelayFacctorTenths', tostring(math.floor(20 + (Latency:GetRandomValue() / 20))))
                            task.wait(1)
                        end
                    else
                        setfflag('TargetTimeDelayFacctorTenths', '20')
                    end
                    task.wait()
                until not BackTrack.Enabled
            end
        end,
        Tooltip = 'Lags targets at certain times to increase attack distance'
    })
    getgenv().Backtrack = BackTrack
    Latency = BackTrack:CreateTwoSlider({
        Name = 'Latency',
        Min = 1,
        Max = 500,
        DefaultMin = 50,
        DefaultMax = 120,
        Darker = true,
    })
    Tick = BackTrack:CreateSlider({
        Name = 'Ticks',
        Min = 1,
        Max = 20,
        Default = 5,
        Darker = true,
        Visible = false,
    })
    Mode = BackTrack:CreateDropdown({
        Name = 'Mode',
        List = { 'Manual', 'Lag Based' },
        Default = 'Manual',
        Function = function(val)
            if Latency and Tick then
                Latency.Object.Visible = val == 'Manual'
                Tick.Object.Visible = val == 'Lag Based'
            end
        end,
    })
end)

run(function()
    local CheatDetector

    local function Added(player, reason)
        if not CheatersFlagged[player] then
            CheatersFlagged[player] = true
            whitelist.customtags[player.Name] = {{ text = 'CHEATER', color = Color3.new(1, 0, 0)}}
            notif('CheatDetector', player.Name .. ' flagged for ' .. reason:lower() .. 'ing', 10, 'info')
        end
    end
    local function checkPoint(pos, params)
        for _, v in workspace:GetPartBoundsInRadius(pos, 0, params) do
            if v.CanCollide and (v:GetClosestPointOnSurface(pos) - pos).Magnitude <= 0 then
                return false
            end
        end

        return true
    end

    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include

    local Checks = {
        Killaura = function()
            local AttackData = {}
            local Strikes = {}

            CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                if damageTable.damageType == 0 and damageTable.fromEntity then
                    local from = playersService:GetPlayerFromCharacter(damageTable.fromEntity)

                    if from and from ~= lplr then
                        local lastHit = (os.clock() - (AttackData[from] or 0))
                        if lastHit <= 0.28 then
                            Strikes[from] = (Strikes[from] or 0) + 1

                            task.delay(60, function()
                                if CheatDetector.Enabled and Strikes[from] then
                                    Strikes[from] = math.max(Strikes[from] - 1, 0)
                                end
                            end)

                            if Strikes[from] > 2 then
                                Added(from, 'Killaura')
                            end
                        end

                        AttackData[from] = os.clock()
                    end
                end
            end))
        end,
        Reach = function() -- this is so disgusting, but whatever
            CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                if damageTable.damageType == 0 and damageTable.fromEntity then
                    local player = playersService:GetPlayerFromCharacter(damageTable.fromEntity) 
                    if player and player ~= lplr then
                        local magnitude = (damageTable.fromEntity.PrimaryPart.Position - damageTable.entityInstance.PrimaryPart.Position).Magnitude
                        local held = (store.inventories[player] or {}).hand
                        local meta = held and bedwars.ItemMeta[held.tool.Name].sword or nil
                        local reach = (meta and meta.attackRange or 14.4) + 4
                        
                        if magnitude > (reach * (0.99 + lplr:GetNetworkPing())) then
                            Added(player, 'Reach')
                        end
                    end
                end
            end))
        end,
        Invisible = function() end
    }

    CheatDetector = vape.Categories.Utility:CreateModule({
        Name = 'Cheat Detector',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.map or not CheatDetector.Enabled
                if not CheatDetector.Enabled then
                    return
                end

                overlap.FilterDescendantsInstances = {store.map}
                for i, v in Checks do
                    if CheatDetector.Options and CheatDetector.Options[i].Enabled then
                        task.spawn(v)
                    end
                end

                repeat
                    for _, v in entitylib.List do
                        if v.Player and v.Player ~= lplr and v.Health > 0 and not CheatersFlagged[v.Player] then
                            if CheatDetector.Options.Invisible.Enabled and (v.RootPart.Position - v.Head.Position).Magnitude > 5 then -- how do people false flag this?
                                Added(v.Player, 'Invisibl')
                            end
                        end
                    end
                    task.wait(0.1)
                until not CheatDetector.Enabled
            end
        end,
        Tooltip = 'Alerts for any possible cheaters.'
    })

    for i in Checks do
        CheatDetector:CreateToggle({
            Name = i,
            Default = true
        })
    end
end)

run(function()
    local FakeLag
    local TransmissionOffset
    local Mode
    local Delay

    local rng, num

    FakeLag = vape.Categories.Utility:CreateModule({
        Name = 'Fake Lag',
        Function = function(callback)
            if callback then
                rng = Random.new()

                local clock, restore, after = os.clock(), os.clock(), 0
                repeat
                    local ms = Delay.Value / 1000

                    if Mode.Value == 'Dynamic' then
                        if (os.clock() - clock) >= ms or restore > os.clock() then
                            if clock ~= 9e9 then
                                restore = os.clock() + TransmissionOffset.Value
                                clock = 9e9
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        else
                            if clock == 9e9 then
                                clock = os.clock()
                                restore = 0
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        end
                    elseif Mode.Value == 'Repel' then
                        if store.update > tick() then
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                            setfflag('S2PhysicsSenderRate', '0')
                            setfflag('DataSenderRate', '-1')
                            task.wait(rng:NextNumber(70, 150) / 1000)
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                            setfflag('DataSenderRate', '60')
                            setfflag('S2PhysicsSenderRate', '15')
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                            store.update = 0
                            num = rng:NextNumber()
                        end
                        if os.clock() > after then
                            num = rng:NextNumber()
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                        end
                    elseif Mode.Value == 'Latency' then
                        setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        task.wait(Delay.Value / 1500)
                        setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        task.wait(ms)
                    end
                    runService.PreRender:Wait()
                until not FakeLag.Enabled
            else
                setfflag('DataSenderRate', '60')
                setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                setfflag('S2PhysicsSenderRate', '15')
            end
        end,
        Tooltip = 'Delays packets, simulating lag',
        ExtraText = function()
            return Mode and Mode.Value or 'Dynamic'
        end
    })
    getgenv().FakeLag = FakeLag

    TransmissionOffset = FakeLag:CreateSlider({
        Name = 'Transmission Offset',
        Min = 1,
        Max = 10,
        Default = 3,
        Decimal = 5,
        Darker = true,
    })
    Mode = FakeLag:CreateDropdown({
        Name = 'Mode',
        List = { 'Dynamic', 'Repel', 'Latency' },
        Default = 'Dynamic',
        Function = function(val)
            TransmissionOffset.Object.Visible = val == 'Dynamic'
            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
        end,
    })
    Delay = FakeLag:CreateSlider({
        Name = 'Delay',
        Suffix = function()
            return 'ms'
        end,
        Min = 1,
        Max = 500,
        Default = 100,
    })
end)

run(function()
    local KnockbackDelay
    local Chance
    local AirDelay
    local GroundDelay
    local TargetCheck

    local old, rand
    local function apply(type, env, ...)
    	local root, mass, dir, knockback = ...
    	knockback = knockback and table.clone(knockback) or {}
    	knockback[type] = env[type] and knockback[type] or 0
    	return old(root, mass, dir, knockback, select(5, ...))
    end

    KnockbackDelay = vape.Categories.Utility:CreateModule({
    	Name = 'Knockback Delay',
    	Function = function(callback)
    		if callback then
    			old, rand = bedwars.KnockbackUtil.applyKnockback, Random.new()
    			bedwars.KnockbackUtil.applyKnockback = function(...)
    				if rand:NextNumber(0, 100) > Chance.Value then
    					return old(...)
    				end

    				local root, mass, dir, knockback = ...
    				if not TargetCheck.Enabled or entitylib.EntityPosition({
    					Range = 50,
    					Part = 'RootPart',
    					Players = true,
    				}) then
    					local env = {}
    					task.delay(AirDelay:GetRandomValue() / 1000, apply, 'horizontal', env, root, mass, dir, knockback, select(5, ...))
    					task.delay(GroundDelay:GetRandomValue() / 1000, apply, 'vertical', env, root, mass, dir, knockback, select(5, ...))
    					return
    				end
    				return old(...)
    			end
    		else
    			bedwars.KnockbackUtil.applyKnockback = old or bedwars.KnockbackUtil.applyKnockback
    		end
    	end,
    	Tooltip = 'Delays incoming knockback packets'
    })

    Chance = KnockbackDelay:CreateSlider({
    	Name = 'Chance',
    	Min = 1,
    	Max = 100,
    	Default = 40,
    	Suffix = '%',
    })
    AirDelay = KnockbackDelay:CreateTwoSlider({
    	Name = 'Air delay',
    	Min = 0,
    	Max = 500,
    	DefaultMin = 50,
    	DefaultMax = 200,
    })
    GroundDelay = KnockbackDelay:CreateTwoSlider({
    	Name = 'Ground delay',
    	Min = 0,
    	Max = 500,
    	DefaultMin = 50,
    	DefaultMax = 200,
    })
    TargetCheck = KnockbackDelay:CreateToggle({ Name = 'Target check' })
end)

run(function()
    local MissileTP

    MissileTP = vape.Categories.Utility:CreateModule({
        Name = 'Missile TP',
        Function = function(callback)
            if callback then
                MissileTP:Toggle()
                local plr = entitylib.EntityMouse({
                    Range = 1000,
                    Players = true,
                    Part = 'RootPart'
                })

                if getItem('guided_missile') and plr then
                    local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
                    if projectile and projectile.model and projectile.model.Parent then
                        local projectilemodel = projectile.model
                        if not projectilemodel.PrimaryPart then
                            waitForSignal(projectilemodel:GetPropertyChangedSignal('PrimaryPart'), 5)
                        end
    					if not projectilemodel.PrimaryPart then return end

                        local bodyforce = Instance.new('BodyForce')
                        bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
                        bodyforce.Name = 'AntiGravity'
                        bodyforce.Parent = projectilemodel.PrimaryPart

                        local timeout = tick() + 30
                        repeat
                            if not projectilemodel.Parent or not plr.RootPart or not plr.RootPart.Parent then break end
                            projectilemodel:PivotTo(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
                            task.wait(0.1)
                        until not projectilemodel.Parent or not plr.RootPart or not plr.RootPart.Parent or tick() >= timeout
                        bodyforce:Destroy()
                    else
                        notif('MissileTP', 'Missile on cooldown.', 3)
                    end
                end
            end
        end,
        Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
    })
end)

run(function()
    local PickupRange
    local Range
    local Network
    local Lower

    PickupRange = vape.Categories.Utility:CreateModule({
        Name = 'Pickup Range',
        Function = function(callback)
            if callback then
                local items = collection('ItemDrop', PickupRange)
                repeat
                    if entitylib.isAlive then
                        local localPosition = entitylib.character.RootPart.Position
                        for _, v in items do
                            if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
                            if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
                                v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
                            end
                            
                            if (localPosition - v.Position).Magnitude <= Range.Value then
                                if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
                                task.spawn(function()
                                    bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
                                        itemDrop = v
                                    }):andThen(function(suc)
                                        if suc and bedwars.SoundList then
                                            bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
                                            local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
                                            if sound then
                                                bedwars.SoundManager:playSound(sound, {
                                                    position = v.Position,
                                                    volumeMultiplier = 0.9
                                                })
                                            end
                                        end
										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end
								local actualRoot = v.Character.PrimaryPart
								if actualRoot and (tick() - swingCooldown) >= (((Sync.Enabled and SwingTime.Value) or (tinker and 0.11 or 0.292)) - (store.ping.incoming / 100)) then
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									swingCooldown = tick()
									store.attackReachUpdate = tick() + 1

									AttackRemote:Fire('FireServer', {
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = getPosition(v.Character, actualRoot)},
											selfPosition = {value = pos}
										}
									})
									if FastHits.Enabled and not fastHitPending and tick() > lastShot and not entitylib.Wallcheck(entitylib.character.RootPart.Position, actualRoot.Position, {gameCamera, lplr.Character, v.Character}) then
										local projectiles = getProjectiles()
										if #projectiles > 0 then
											projectileIndex += 1
											if not projectiles[projectileIndex] then
												projectileIndex = 1
											end
											
											local item, ammo, projectile, itemMeta = unpack(projectiles[projectileIndex])
											if (tick() - store.total.ping) > (FireRates[item.itemType] or 0) then
											local projmeta = bedwars.ProjectileMeta[projectile]
											if not projmeta or type(projmeta.launchVelocity) ~= 'number' then continue end
												local projSpeed, gravity = projmeta.launchVelocity, projmeta.gravitationalAcceleration or 196.2
												local oldhotbar, oldtool = store.inventory.hotbarSlot, store.hand.tool
												local hotbar = getHotbar(item.tool)
												if hotbar then
													switchItem(item.tool)
													if Legit.Enabled then
														hotbarSwitch(hotbar)
													end
												end
												
												local targetPosition = v.RootPart.Position
												local shootPosition = (CFrame.new(selfpos, targetPosition) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
												local calc = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, targetPosition, v.RootPart.AssemblyLinearVelocity, workspace.Gravity, v.HipHeight, v.Jumping and 42.6 or nil, nil, v.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(v.RootPart.AssemblyLinearVelocity.Y) > 0.01, v.RootPart.Position, v.RootPart, nil, true)
												if calc then
													local sdir, id = CFrame.lookAt(shootPosition, calc).LookVector, httpService:GenerateGUID(true)

													bedwars.ProjectileController:createLocalProjectile(itemMeta, ammo, projectile, shootPosition, id, sdir * projSpeed, {drawDurationSeconds = 1})
													fastHitPending = true
													FireRates[item.itemType] = tick() + (itemMeta.fireDelaySec or 0.1)
													lastShot = tick() + FireRate.Value
													task.spawn(function()
														local res = projectileRemote:Fire('CallServer',
															item.tool,
															ammo,
															projectile,
															shootPosition,
															pos,
															sdir * projSpeed,
															id,
															{
																drawDurationSeconds = 1, 
																shotId = httpService:GenerateGUID(false)
															},
															workspace:GetServerTimeNow() - (store.ping.total / 10)
														)
														fastHitPending = false
														if res and typeof(res) == 'Instance' and res.Parent then
															res.Parent = replicatedStorage
															local shoot = itemMeta.launchSound
															shoot = shoot and shoot[math.random(1, #shoot)] or nil
															if shoot then
																bedwars.SoundManager:playSound(shoot)
															end
														end
													end)
												end
												if oldtool then
													switchItem(oldtool)
												end
												task.spawn(function()
													if Legit.Enabled then
														hotbarSwitch(oldhotbar)
													end
												end)
											end
										end
									end
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait()
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, bedwars.Knit)
				debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 20,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	ChanceSlider = Killaura:CreateSlider({
		Name = 'Air hit chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	SwingTime = Killaura:CreateSlider({
		Name = 'Swing time',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Default = 0.11,
		Suffix = 'seconds'
	})
	--[[Sync = Killaura:CreateToggle({
		Name = 'Sync with hitreg',
		Darker = true,
		Tooltip = 'Syncs ur hitreg with the swing time'
	})]]
		
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	FastHits = Killaura:CreateToggle({
		Name = 'Fast Hits',
		Default = false,
		Function = function(callback)
			pcall(function()
				Legit.Object.Visible = callback
				FireRate.Object.Visible = callback
				Whitelist.Object.Visible = callback
			end)
		end,
		Tooltip = 'Deals more damage quicker using projectiles'
	})
	Whitelist = Killaura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'},
		Darker = true,
		Visible = false,
		Tooltip = 'Projectiles to use for fasthits'
	})
	Legit = Killaura:CreateToggle({
		Name = 'Legit Switch',
		Darker = true,
		Visible = false
	})
	FireRate = Killaura:CreateSlider({
		Name = 'Fire rate',
		Suffix = 'seconds',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Default = 0.05
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Attackable = Killaura:CreateToggle({Name = 'Attackable check'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)

run(function()
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)
	
	local function launchProjectile(item, pos, proj, speed, dir)
		if not pos then return end
	
		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
		switchItem(item.tool, 0)
		task.wait(0.1)
		bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
		if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Handler:Get(AimCannon):Fire('SendToServer', {
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Handler:Get('LaunchSelfFromCannon'):Fire('CallServer', {cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			launchProjectile(item, pos, 'fireball', 60, dir)
		end,
		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,
		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))
	
				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
	
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)

run(function()
	local NoFall
	
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local velo = root.Velocity
	
						if root.Velocity.Y < -45 then
							root.Velocity = Vector3.new(0, 2.5 + dt, 0)
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
							runService.PreRender:Wait()
							root.Velocity = velo
						end
					end
				end))
	
				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					local animator = ent.Humanoid:WaitForChild('Animator', 5)
					if animator and NoFall.Enabled then
						task.wait(.5)
						NoFall:Toggle()
						NoFall:Toggle()
					end
				end))
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
end)

run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlow',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)

run(function()
	local OwlAura
	local Targets
	local Mode
	local Range
	
	OwlAura = vape.Categories.Blatant:CreateModule({
	    Name = 'OwlAura',
	    Function = function(callback)
	        if callback then
	            local owls = collection('Owl', OwlAura, function(self, obj)
	                task.delay(1, function()
	                    if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then
	                        table.insert(self, obj)
	                    end
	                end)
	            end)
	            repeat
	                if store.equippedKit ~= 'owl' then
	                    task.wait(1)
	                    continue
	                end
	
	                if entitylib.isAlive then
	                    local owl = owls[1]
	                    if owl then
	                        local origin = owl.Part.Position
	                        local plr = entitylib.EntityPosition({
	                            Origin = origin,
	                            Range = Range.Value,
	                            Part = 'RootPart',
	                            Players = Targets.Players.Enabled,
	                            NPCs = Targets.NPCs.Enabled,
	                            Wallcheck = Targets.Walls.Enabled,
	                            Sort = sortmethods[Mode.Value]
	                        })
	
	                        if plr then
	                            local meta = bedwars.ProjectileMeta.owl_projectile
	                            local targetVelocity = plr.RootPart.AssemblyLinearVelocity
	                            local targetAirborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
	                            local calc, _, travelTime = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, targetVelocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
	                            if calc and travelTime and travelTime <= (meta.lifetimeSec or 3) then
	                                local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
	                                bedwars.Handler:Get('OwlAiming'):Fire('SendToServer', {
	                                    owl = owl.Part,
	                                    starting = true
	                                })
	                                bedwars.Handler:Get('OwlFireProjectile'):Fire('SendToServer', {
	                                    ProjectileRefId = httpService:GenerateGUID(true),
	                                    direction = dir,
	                                    fromPosition = origin,
	                                    initialVelocity = dir
	                                })
	                                bedwars.Handler:Get('TridentUnanchor'):Fire('CallServer')
	                            end
	                        end
	                    end
	                end
	                task.wait(0.1)
	            until not OwlAura.Enabled
	        else
	            bedwars.Handler:Get('OwlAiming'):Fire('SendToServer', {starting = false})
	        end
	    end,
	    Tooltip = 'Automatically shoots projectiles with whisper kit'
	})
	
	Targets = OwlAura:CreateTargets({
	    Players = true,
	    Wallcheck = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
	    if not table.find(methods, i) then
	        table.insert(methods, i)
	    end
	end
	Mode = OwlAura:CreateDropdown({
	    Name = 'Target mode',
	    List = methods,
	    Default = 'Distance'
	})
	Range = OwlAura:CreateSlider({
	    Name = 'Range',
	    Min = 1,
	    Max = 50,
	    Default = 50,
	    Suffix = function(val)
	        return val <= 0 and 'stud' or 'studs'
	    end
	})
end)

run(function()
	local TargetPart
	local Targets
	local FOV
	local AutoCharge
	local Aim = {}
	local OtherProjectiles
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	local old
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					})
					if plr then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							return old(...)
						end
	
						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
							return old(...)
						end
	
						if table.find(Blacklist.ListEnabled or {}, ((projmeta.projectile == 'glue_trap' or projmeta.projectile == 'glue_projectile') and 'gloop' or projmeta.projectile)) then
							return old(...)
						end
	
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
						end
	
						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end
	
						if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
								end
							end
						end
	
						local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(plr.RootPart.Velocity.Y) > 0.01, plr.RootPart.Position, plr.RootPart, nil, true)
						if calc then
							targetinfo.Targets[plr] = tick() + 1
							return {
								initialVelocity = (CFrame.new(newlook.Position, calc).LookVector * projSpeed) * ((AutoCharge.Enabled or not Aim.Enabled) and 1 or projmeta.velocityMultiplier),
								positionFrom = offsetpos,
								deltaT = lifetime,
								gravitationalAcceleration = gravity,
								drawDurationSeconds = AutoCharge.Enabled and 5 or projmeta.drawDurationSeconds
							}
						end
					end
	
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = 'Auto Charge',
		Function = function(callback)
			if Aim.Object then
				Aim.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Fully charges your bow, Allowing your projectile to deal more damage'
	})
	Aim = ProjectileAimbot:CreateToggle({
		Name = 'Aim change',
		Default = true,
		Darker = true,
		Tooltip = 'Changes your trajectory to match charge percentage.'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Default = {'telepearl'}
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local AttackDelay
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > AttackDelay.Value then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local switched = switchItem(item.tool)
									local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.Velocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
	
										task.spawn(function()
											local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												pcall(function() res.Parent = replicatedStorage end)
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + itemMeta.fireDelaySec
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.03)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackDelay = ProjectileAura:CreateSlider({
		Name = 'Attack delay',
		Suffix = 'seconds',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.1,
		Tooltip = 'How long to wait after swinging your sword before shooting'
	})
end)

run(function()
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
					if entitylib.isAlive and not Fly.Enabled and not InfiniteFly.Enabled and not LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local root, velo = entitylib.character.RootPart, getSpeed()
						local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
	
						if WallCheck.Enabled then
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end
	
						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)

run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)

run(function()
	local HiveESP
	local Color
	local Transparency
	local Scale
	
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local Reference, Strings = {}, {}
	local function Added(ent)
		local Name = playersService:GetNameFromUserIdAsync(ent:GetAttribute('PlacedByUserId')) or 'Unknown'
	
		Strings[ent] = `{Name}'s beehive | %s Bee%s`
		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local format = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
		local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = 0.5
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = format
		nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	local function Updated(ent)
		if Reference[ent] then
			Reference[ent].TextSize = 14 * Scale.Value
			Reference[ent].TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			Reference[ent].BackgroundTransparency = Transparency.Value
		end
	end
	local function Removing(ent)
		if Reference[ent] then
			Reference[ent]:Destroy()
			Reference[ent] = nil
		end
	end
	
	HiveESP = vape.Categories.Render:CreateModule({
		Name = 'BeehiveESP',
		Function = function(call)
			if call then
				for _, v in collectionService:GetTagged('beehive') do
					Added(v)
				end
				HiveESP:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(Added))
				HiveESP:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(Removing))
				HiveESP:Clean(runService.PreRender:Connect(function()
					for ent, nametag in Reference do
						local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
						nametag.Visible = headVis
						if not headVis then
							continue
						end
	
	                    nametag.Text = string.format(Strings[ent], tostring(ent:GetAttribute('Level') or 0), (ent:GetAttribute('Level') or 0) >= 2 and 's' or '')
	                    local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
	                    nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
					end
				end))
			else
				for i in Reference do
					Removing(i)
				end
			end
		end,
		Tooltip = 'Renders hives locations and info'
	})
	
	Color = HiveESP:CreateColorSlider({
		Name = 'Text Color',
		Function = function(hue, sat, val)
			if HiveESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end
	})
	Transparency = HiveESP:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if HiveESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	Scale = HiveESP:CreateSlider({
		Name = 'Scale',
	    Function = function()
			if HiveESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
	    Default = 1
	})
end)

run(function()
	local GeneratorESP
	local Transparency
	local Scale
	local Whitelist
	local Whitelisted = {}
	
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local Reference, Strings, Cooldown = {}, {}, {}
	
	local function getNumber(text)
		if not text or text == '' then
			return 0
		end
		local seconds = text:match('%[(%d+)%]')
		if seconds then
			return tonumber(seconds) or 0
		end
		local justNumber = text:match('(%d+)')
		if justNumber then
			return tonumber(justNumber) or 0
		end
		return 0
	end
	
	local function Added(ent)
		local App = ent.RoactTree.TeamOreGeneratorApp
		local Name = (App:FindFirstChild('GlobalOreGenerator') or App:FindFirstChild('TeamGenMain'))
		if Name then
			Name = Name:FindFirstChild('Title')
		end
	
		local TierType = ''
		if Name then
			Name = Name.Text
			TierType = 'iron'
		else
			local Ore = ent:GetAttribute('Id')
			Ore = Ore:sub(0, #Ore - 2)
			TierType = (Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore)):lower()
			Name = Ore:sub(0, 1):upper() .. Ore:sub(2, #Ore) .. ' Generator'
		end
	
		if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, TierType) then
			return
		end
	
		Strings[ent] = `{Name} %s%s`
		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local format = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, '')
		local size = getfontsize(format, nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = 0.5
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = format
		nametag.TextColor3 = Color3.new(1, 1, 1)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	local function Updated(ent)
		if Reference[ent] then
			Reference[ent].TextSize = 14 * Scale.Value
			Reference[ent].BackgroundTransparency = Transparency.Value
		end
	end
	local function Removing(ent)
		if Reference[ent] then
			Reference[ent]:Destroy()
			Reference[ent] = nil
		end
	end
	
	GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('Generator') do
					Added(v)
				end
				GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
				GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(Removing))
				GeneratorESP:Clean(runService.PreRender:Connect(function()
					for ent, nametag in Reference do
						local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
						nametag.Visible = headVis
						if not headVis then
							continue
						end
						
						nametag.Text = string.format(Strings[ent], `| T{ent:GetAttribute('GeneratorLevel')}`, Cooldown[ent] and ` | {getNumber(Cooldown[ent].Text)}s` or '')
						local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
						nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
					end
				end))
			else
				for i in Reference do
					Removing(i)
				end
			end
		end,
		Tooltip = 'Renders generator locations and info'
	})
	
	Transparency = GeneratorESP:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if GeneratorESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 100
	})
	Scale = GeneratorESP:CreateSlider({
		Name = 'Scale',
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function()
			if GeneratorESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end
	})
	Whitelist = GeneratorESP:CreateToggle({
		Name = 'Use whitelist',
		Default = true,
		Function = function(call)
			if Whitelisted.Object then
				Whitelisted.Object.Visible = call
			end
		end
	})
	Whitelisted = GeneratorESP:CreateTextList({
		Name = 'Generators',
		Darker = true,
		Default = {'diamond', 'iron'}
	})
end)

run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)

run(function()
	local ItemESP
	local Distance
	local Transparency
	local Scale
	local WhitelistOnly
	local Whitelist = {}
	
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local Reference, Strings, Sizes = {}, {}, {}
	local function Added(ent)
		local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
		if WhitelistOnly.Enabled and not table.find(Whitelist.ListEnabled, Name:lower()) then
			return
		end
	
		Strings[ent] = Name .. '%s'
		if Distance.Enabled then
			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent]
		end
	
		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local size = getfontsize(removeTags(ent.Name), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = ent.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = 0.5
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = string.format(Strings[ent], '', ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
		nametag.TextColor3 = Color3.new(1, 1, 1)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	local function Updated(ent)
		if Reference[ent] then
			Reference[ent].TextSize = 14 * Scale.Value
			Reference[ent].BackgroundTransparency = Transparency.Value
		end
	end
	local function Removing(ent)
		if Reference[ent] then
			Reference[ent]:Destroy()
			Reference[ent] = nil
		end
	end
	
	ItemESP = vape.Categories.Render:CreateModule({
		Name = 'ItemESP',
		Function = function(call)
			if call then
				ItemESP:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(Added))
				ItemESP:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(Removing))
				ItemESP:Clean(runService.PreRender:Connect(function()
					for ent, nametag in Reference do
						local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
						nametag.Visible = headVis
						if not headVis then
							continue
						end
	
						if ent.Position.Y > -200 then
							if Distance.Enabled then
								local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or 0
								if Sizes[ent] ~= mag then
									nametag.Text = string.format(Strings[ent], mag, ent:GetAttribute('Amount') >= 2 and ' x' .. tostring(ent:GetAttribute('Amount')) or '')
									local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
									nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
									Sizes[ent] = mag
								end
							else
								nametag.Text = string.format(Strings[ent], '')
								local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
								nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
							end
							nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
						else
							nametag.Visible = false
						end
					end
				end))
	
				for _, v in collectionService:GetTagged('ItemDrop') do
					Added(v)
				end
			else
				for i in Reference do
					Removing(i)
				end
			end
		end,
		Tooltip = 'Renders tags dropped items'
	})
	Distance = ItemESP:CreateToggle({
		Name = 'Distance',
		Function = function(callback)
			if ItemESP.Enabled then
				for ent in Reference do
					local Name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
					Strings[ent] = callback and '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '.. Strings[ent] or Name.. '%s'
				end
			end
		end,
	    Tooltip = 'Shows the distance of the item'
	})
	Transparency = ItemESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
	    Function = function()
			if ItemESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end,
	    Default = 0.5
	})
	Scale = ItemESP:CreateSlider({
		Name = 'Scale',
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function()
			if ItemESP.Enabled then
				for ent in Reference do
					Updated(ent)
				end
			end
		end
	})
	WhitelistOnly = ItemESP:CreateToggle({
		Name = 'Whitelist Only',
		Function = function(callback)
			if Whitelist.Object then
				Whitelist.Object.Visible = callback
			end
	        if ItemESP.Enabled then
	            ItemESP:Toggle()
	            ItemESP:Toggle()
	        end
		end,
	    Tooltip = 'Only renders whitelisted items'
	})
	Whitelist = ItemESP:CreateTextList({
		Name = 'Allowed items',
		Function = function()
			if ItemESP.Enabled then
				ItemESP:Toggle()
				ItemESP:Toggle()
			end
		end,
		Darker = true,
	    Visible = false
	})
end)

run(function()
	local ItemPlates
	local Whitelist
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, side in sides do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self then break end
				if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
					table.insert(tab, block.Name)
				end
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local alreadygot = {}
		scanSide(v.Adornee, start, alreadygot)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
		end)
		v.Enabled = #alreadygot > 0
	
		for _, block in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
		if not table.find(Whitelist.ListEnabled, v.Name) then return end
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	ItemPlates = vape.Categories.Render:CreateModule({
		Name = 'ItemPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('block') do
					task.spawn(Added, v)
				end
				ItemPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				ItemPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				ItemPlates:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(Added))
				ItemPlates:Clean(collectionService:GetInstanceRemovedSignal('block'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays surrounding blocks around the item.'
	})
	Whitelist = ItemPlates:CreateTextList({
		Name = 'Whitelist',
		Default = {'beehive'}
	})
	Background = ItemPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then 
				Color.Object.Visible = callback 
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = ItemPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local KitDisplay
	
	local function waitForChild(start, ...)
	    local parent = start
	    for _, v in {...} do
	        local deadline = tick() + 10
	        local child
	        repeat
	            child = parent and parent:FindFirstChild(v)
	            if not child then task.wait(0.1) end
	        until child or not KitDisplay.Enabled or tick() >= deadline
	        parent = child
	        if not parent then
	            break
	        end
	    end
	    return parent
	end
	
	local function getPlayerDraft(name) 
	    for _, v in playersService:GetPlayers() do
	        if name and (v.Name == name or v.DisplayName == name or v:GetAttribute('DisguiseDisplayName') == name) then
	            return v
	        end
	
	        local displayName = bedwars.StreamerModeController and bedwars.StreamerModeController:getDisplayName(v)
	        if name and displayName == name then
	            return v
	        end
	    end
	    return nil
	end
	
	local function tweenKit(roact, image)
	    roact.Image = image
	    roact.Position = UDim2.fromScale(1.05, 0)
	    tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
	        Position = UDim2.fromScale(1.05, 0.5)
	    }):Play()
	end
	
	local function renderKit(v)
	    task.wait(0.3)
		if not KitDisplay.Enabled or not v.Parent then return end
	    local name = v:FindFirstChild('PlayerName', true)
	    if name then
	        local player = getPlayerDraft(name.Text)
	        if player then
	            local frame = v:FindFirstChild('1')
	            local card = frame and frame:FindFirstChild('MatchDraftPlayerCard')
	            if not card then return end
	            local roact, image = card:FindFirstChild('KitImage'), bedwars.BedwarsKitMeta[player:GetAttribute('PlayingAsKits')] or bedwars.BedwarsKitMeta.none
	            if not roact then
	                roact = Instance.new('ImageLabel')
	                roact.BackgroundTransparency = 1
	                roact.AnchorPoint = Vector2.new(1, 0.5)
	                roact.Position = UDim2.fromScale(1.05, 0)
	                roact.Name = 'KitImage'
	                roact.Size = UDim2.fromScale(1.5, 1.5)
	                roact.ZIndex = 1
	                roact.ImageTransparency = 0.4
	                roact.SliceCenter = Rect.new(0, 0, 0, 0)
	                roact.SliceScale = 1
	                roact.ScaleType = Enum.ScaleType.Crop
	                roact.Parent = card
	
	                KitDisplay:Clean(roact)
	
	                local ratio = Instance.new('UIAspectRatioConstraint', roact)
	                ratio.Name = '1'
	                ratio.AspectRatio = 1
	                ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	                ratio.DominantAxis = Enum.DominantAxis.Width
	            end
	
	            tweenKit(roact, image.renderImage)
	
	            local connection = player:GetAttributeChangedSignal('PlayingAsKits'):Connect(function()
	                if not KitDisplay.Enabled or not roact.Parent then return end
	                image = bedwars.BedwarsKitMeta[player:GetAttribute('PlayingAsKits')] or bedwars.BedwarsKitMeta.none
	                tweenKit(roact, image.renderImage)
	            end)
	            KitDisplay:Clean(name:GetPropertyChangedSignal('Text'):Once(function()
	                if connection then
	                    connection:Disconnect()
	                    connection = nil
	                end
	                renderKit(v)
	            end))
	            KitDisplay:Clean(connection)
	        end
	    end
	end
	
	KitDisplay = vape.Categories.Render:CreateModule({
	    Name = 'KitDisplay',
	    Function = function(callback)
	        if callback then
	            local bodyContainer
	            repeat
	                local app = lplr.PlayerGui:FindFirstChild('MatchDraftApp')
	                local background = app and app:FindFirstChild('DraftAppBackground')
	                local frame = background and background:FindFirstChild('1')
	                bodyContainer = frame and frame:FindFirstChild('BodyContainer')
	                if not bodyContainer then task.wait(0.1) end
	            until bodyContainer or not KitDisplay.Enabled
	            if not KitDisplay.Enabled then return end
	            if bodyContainer then
	                for i = 1, 2 do
	                    local column = waitForChild(bodyContainer, 'Team' .. i .. 'Column')
	                    if column then
	                        KitDisplay:Clean(column.ChildAdded:Connect(renderKit))
	                        for _, v in column:GetChildren() do
	                            task.spawn(renderKit, v)
	                        end
	                    end
	                end
	            end
	        end
	    end,
	    Tooltip = 'Allows you to view opponent\'s kit in match draft.'
	})
	
end)

run(function()
	local KitESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'wild_flower'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'}
	}
	
	local function Added(v, icon)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	
	local function addKit(tag, icon)
		KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			Added(v.PrimaryPart, icon)
		end))
		KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if Reference[v.PrimaryPart] then
				Reference[v.PrimaryPart]:Destroy()
				Reference[v.PrimaryPart] = nil
			end
		end))
		for _, v in collectionService:GetTagged(tag) do
			Added(v.PrimaryPart, icon)
		end
	end
	
	KitESP = vape.Categories.Render:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
				local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
				if kit then
					addKit(kit[1], kit[2])
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = KitESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
    local AutoHotbar
    local Mode
    local Clear
    local List
    local Active

    local function CreateWindow(self)
        local selectedslot = 1
        local window = Instance.new('Frame')
        window.Name = 'HotbarGUI'
        window.Size = UDim2.fromOffset(660, 465)
        window.Position = UDim2.fromScale(0.5, 0.5)
        window.BackgroundColor3 = uipallet.Main
        window.AnchorPoint = Vector2.new(0.5, 0.5)
        window.Visible = false
        window.Parent = vape.gui.ScaledGui
        local title = Instance.new('TextLabel')
        title.Name = 'Title'
        title.Size = UDim2.new(1, -10, 0, 20)
        title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
        title.BackgroundTransparency = 1
        title.Text = 'AutoHotbar'
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = uipallet.Text
        title.TextSize = 13
        title.FontFace = uipallet.Font
        title.Parent = window
        local divider = Instance.new('Frame')
        divider.Name = 'Divider'
        divider.Size = UDim2.new(1, 0, 0, 1)
        divider.Position = UDim2.fromOffset(0, 40)
        divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
        divider.BorderSizePixel = 0
        divider.Parent = window
        addBlur(window)
        local modal = Instance.new('TextButton')
        modal.Text = ''
        modal.BackgroundTransparency = 1
        modal.Modal = true
        modal.Parent = window
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = window
        local close = Instance.new('ImageButton')
        close.Name = 'Close'
        close.Size = UDim2.fromOffset(24, 24)
        close.Position = UDim2.new(1, -35, 0, 9)
        close.BackgroundColor3 = Color3.new(1, 1, 1)
        close.BackgroundTransparency = 1
        close.Image = getcustomasset('catnext/assets/new/close.png')
        close.ImageColor3 = color.Light(uipallet.Text, 0.2)
        close.ImageTransparency = 0.5
        close.AutoButtonColor = false
        close.Parent = window
        close.MouseEnter:Connect(function()
            close.ImageTransparency = 0.3
            tween:Tween(close, TweenInfo.new(0.2), {
                BackgroundTransparency = 0.6
            })
        end)
        close.MouseLeave:Connect(function()
            close.ImageTransparency = 0.5
            tween:Tween(close, TweenInfo.new(0.2), {
                BackgroundTransparency = 1
            })
        end)
        close.MouseButton1Click:Connect(function()
            window.Visible = false
            vape.gui.ScaledGui.ClickGui.Visible = true
        end)
        local closecorner = Instance.new('UICorner')
        closecorner.CornerRadius = UDim.new(1, 0)
        closecorner.Parent = close
        local bigslot = Instance.new('Frame')
        bigslot.Size = UDim2.fromOffset(110, 111)
        bigslot.Position = UDim2.fromOffset(11, 71)
        bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
        bigslot.Parent = window
        local bigslotcorner = Instance.new('UICorner')
        bigslotcorner.CornerRadius = UDim.new(0, 4)
        bigslotcorner.Parent = bigslot
        local bigslotstroke = Instance.new('UIStroke')
        bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
        bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        bigslotstroke.Parent = bigslot
        local slotnum = Instance.new('TextLabel')
        slotnum.Size = UDim2.fromOffset(80, 20)
        slotnum.Position = UDim2.fromOffset(25, 200)
        slotnum.BackgroundTransparency = 1
        slotnum.Text = 'SLOT 1'
        slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
        slotnum.TextSize = 12
        slotnum.FontFace = uipallet.Font
        slotnum.Parent = window
        for i = 1, 9 do
            local slotbkg = Instance.new('TextButton')
            slotbkg.Name = 'Slot'..i
            slotbkg.Size = UDim2.fromOffset(51, 52)
            slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
            slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
            slotbkg.Text = ''
            slotbkg.AutoButtonColor = false
            slotbkg.Parent = window
            local slotimage = Instance.new('ImageLabel')
            slotimage.Size = UDim2.fromOffset(32, 32)
            slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
            slotimage.BackgroundTransparency = 1
            slotimage.Image = ''
            slotimage.Parent = slotbkg
            local slotcorner = Instance.new('UICorner')
            slotcorner.CornerRadius = UDim.new(0, 4)
            slotcorner.Parent = slotbkg
            local slotstroke = Instance.new('UIStroke')
            slotstroke.Color = color.Light(uipallet.Main, 0.04)
            slotstroke.Thickness = 2
            slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            slotstroke.Enabled = i == selectedslot
            slotstroke.Parent = slotbkg
            slotbkg.MouseEnter:Connect(function()
                slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
            end)
            slotbkg.MouseLeave:Connect(function()
                slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
            end)
            slotbkg.MouseButton1Click:Connect(function()
                window['Slot'..selectedslot].UIStroke.Enabled = false
                selectedslot = i
                slotstroke.Enabled = true
                slotnum.Text = 'SLOT '..selectedslot
            end)
            slotbkg.MouseButton2Click:Connect(function()
                local obj = self.Hotbars[self.Selected]
                if obj then
                    window['Slot'..i].ImageLabel.Image = ''
                    obj.Hotbar[tostring(i)] = nil
                    obj.Object['Slot'..i].Image = '	'
                end
            end)
        end
        local searchbkg = Instance.new('Frame')
        searchbkg.Size = UDim2.fromOffset(496, 31)
        searchbkg.Position = UDim2.fromOffset(142, 80)
        searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
        searchbkg.Parent = window
        local search = Instance.new('TextBox')
        search.Size = UDim2.new(1, -10, 0, 31)
        search.Position = UDim2.fromOffset(10, 0)
        search.BackgroundTransparency = 1
        search.Text = ''
        search.PlaceholderText = ''
        search.TextXAlignment = Enum.TextXAlignment.Left
        search.TextColor3 = uipallet.Text
        search.TextSize = 12
        search.FontFace = uipallet.Font
        search.ClearTextOnFocus = false
        search.Parent = searchbkg
        local searchcorner = Instance.new('UICorner')
        searchcorner.CornerRadius = UDim.new(0, 4)
        searchcorner.Parent = searchbkg
        local searchicon = Instance.new('ImageLabel')
        searchicon.Size = UDim2.fromOffset(14, 14)
        searchicon.Position = UDim2.new(1, -26, 0, 8)
        searchicon.BackgroundTransparency = 1
        searchicon.Image = getcustomasset('catnext/assets/new/search.png')
        searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
        searchicon.Parent = searchbkg
        local children = Instance.new('ScrollingFrame')
        children.Name = 'Children'
        children.Size = UDim2.fromOffset(500, 240)
        children.Position = UDim2.fromOffset(144, 122)
        children.BackgroundTransparency = 1
        children.BorderSizePixel = 0
        children.ScrollBarThickness = 2
        children.ScrollBarImageTransparency = 0.75
        children.CanvasSize = UDim2.new()
        children.Parent = window
        local windowlist = Instance.new('UIGridLayout')
        windowlist.SortOrder = Enum.SortOrder.LayoutOrder
        windowlist.FillDirectionMaxCells = 9
        windowlist.CellSize = UDim2.fromOffset(51, 52)
        windowlist.CellPadding = UDim2.fromOffset(4, 3)
        windowlist.Parent = children
        windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            if vape.ThreadFix then
                setthreadidentity(8)
            end
            children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
        end)
        table.insert(vape.Windows, window)

        local function createitem(id, image)
            local slotbkg = Instance.new('TextButton')
            slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
            slotbkg.Text = ''
            slotbkg.AutoButtonColor = false
            slotbkg.Parent = children
            local slotimage = Instance.new('ImageLabel')
            slotimage.Size = UDim2.fromOffset(32, 32)
            slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
            slotimage.BackgroundTransparency = 1
            slotimage.Image = image
            slotimage.Parent = slotbkg
            local slotcorner = Instance.new('UICorner')
            slotcorner.CornerRadius = UDim.new(0, 4)
            slotcorner.Parent = slotbkg
            slotbkg.MouseEnter:Connect(function()
                slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
            end)
            slotbkg.MouseLeave:Connect(function()
                slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
            end)
            slotbkg.MouseButton1Click:Connect(function()
                local obj = self.Hotbars[self.Selected]
                if obj then
                    window['Slot'..selectedslot].ImageLabel.Image = image
                    obj.Hotbar[tostring(selectedslot)] = id
                    obj.Object['Slot'..selectedslot].Image = image
                end
            end)
        end

        local function indexSearch(text)
            for _, v in children:GetChildren() do
                if v:IsA('TextButton') then
                    v:ClearAllChildren()
                    v:Destroy()
                end
            end

            if text == '' then
                for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
                    createitem(v, bedwars.ItemMeta[v].image)
                end
                return
            end

            for i, v in bedwars.ItemMeta do
                if text:lower() == i:lower():sub(1, text:len()) then
                    if not v.image then continue end
                    createitem(i, v.image)
                end
            end
        end

        search:GetPropertyChangedSignal('Text'):Connect(function()
            indexSearch(search.Text)
        end)
        indexSearch('')

        return window
    end

    vape.Components.HotbarList = function(optionsettings, children, api)
        if vape.ThreadFix then
            setthreadidentity(8)
        end
        local optionapi = {
            Type = 'HotbarList',
            Hotbars = {},
            Selected = 1
        }
        local hotbarlist = Instance.new('TextButton')
        hotbarlist.Name = 'HotbarList'
        hotbarlist.Size = UDim2.fromOffset(220, 40)
        hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
        hotbarlist.Text = ''
        hotbarlist.BorderSizePixel = 0
        hotbarlist.AutoButtonColor = false
        hotbarlist.Parent = children
        local textbkg = Instance.new('Frame')
        textbkg.Name = 'BKG'
        textbkg.Size = UDim2.new(1, -20, 0, 31)
        textbkg.Position = UDim2.fromOffset(10, 4)
        textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
        textbkg.Parent = hotbarlist
        local textbkgcorner = Instance.new('UICorner')
        textbkgcorner.CornerRadius = UDim.new(0, 4)
        textbkgcorner.Parent = textbkg
        local textbutton = Instance.new('TextButton')
        textbutton.Name = 'HotbarList'
        textbutton.Size = UDim2.new(1, -2, 1, -2)
        textbutton.Position = UDim2.fromOffset(1, 1)
        textbutton.BackgroundColor3 = uipallet.Main
        textbutton.Text = ''
        textbutton.AutoButtonColor = false
        textbutton.Parent = textbkg
        textbutton.MouseEnter:Connect(function()
            tween:Tween(textbkg, TweenInfo.new(0.2), {
                BackgroundColor3 = color.Light(uipallet.Main, 0.14)
            })
        end)
        textbutton.MouseLeave:Connect(function()
            tween:Tween(textbkg, TweenInfo.new(0.2), {
                BackgroundColor3 = color.Light(uipallet.Main, 0.034)
            })
        end)
        local textbuttoncorner = Instance.new('UICorner')
        textbuttoncorner.CornerRadius = UDim.new(0, 4)
        textbuttoncorner.Parent = textbutton
        local textbuttonicon = Instance.new('ImageLabel')
        textbuttonicon.Size = UDim2.fromOffset(12, 12)
        textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
        textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
        textbuttonicon.BackgroundTransparency = 1
        textbuttonicon.Image = getcustomasset('catnext/assets/new/add.png')
        textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
        textbuttonicon.Parent = textbutton
        local childrenlist = Instance.new('Frame')
        childrenlist.Size = UDim2.new(1, 0, 1, -40)
        childrenlist.Position = UDim2.fromOffset(0, 40)
        childrenlist.BackgroundTransparency = 1
        childrenlist.Parent = hotbarlist
        local windowlist = Instance.new('UIListLayout')
        windowlist.SortOrder = Enum.SortOrder.LayoutOrder
        windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
        windowlist.Padding = UDim.new(0, 3)
        windowlist.Parent = childrenlist
        windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            if vape.ThreadFix then
                setthreadidentity(8)
            end
            hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
        end)
        textbutton.MouseButton1Click:Connect(function()
            optionapi:AddHotbar()
        end)
        optionapi.Window = CreateWindow(optionapi)

        function optionapi:Save(savetab)
            local hotbars = {}
            for _, v in self.Hotbars do
                table.insert(hotbars, v.Hotbar)
            end
            savetab.HotbarList = {
                Selected = self.Selected,
                Hotbars = hotbars
            }
        end

        function optionapi:Load(savetab)
            for _, v in self.Hotbars do
                v.Object:ClearAllChildren()
                v.Object:Destroy()
                table.clear(v.Hotbar)
            end
            table.clear(self.Hotbars)
            for _, v in savetab.Hotbars do
                self:AddHotbar(v)
            end
            self.Selected = savetab.Selected or 1
        end

        function optionapi:AddHotbar(data)
            local hotbardata = {Hotbar = data or {}}
            table.insert(self.Hotbars, hotbardata)
            local hotbar = Instance.new('TextButton')
            hotbar.Size = UDim2.fromOffset(200, 27)
            hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
            hotbar.Text = ''
            hotbar.AutoButtonColor = false
            hotbar.Parent = childrenlist
            hotbardata.Object = hotbar
            local hotbarcorner = Instance.new('UICorner')
            hotbarcorner.CornerRadius = UDim.new(0, 4)
            hotbarcorner.Parent = hotbar
            for i = 1, 9 do
                local slot = Instance.new('ImageLabel')
                slot.Name = 'Slot'..i
                slot.Size = UDim2.fromOffset(17, 18)
                slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
                slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
                slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
                slot.BorderSizePixel = 0
                slot.Parent = hotbar
            end
            hotbar.MouseButton1Click:Connect(function()
                local ind = table.find(optionapi.Hotbars, hotbardata)
                if ind == optionapi.Selected then
                    vape.gui.ScaledGui.ClickGui.Visible = false
                    optionapi.Window.Visible = true
                    for i = 1, 9 do
                        optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
                    end
                else
                    if optionapi.Hotbars[optionapi.Selected] then
                        optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
                    end
                    hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
                    optionapi.Selected = ind
                end
            end)
            local close = Instance.new('ImageButton')
            close.Name = 'Close'
            close.Size = UDim2.fromOffset(16, 16)
            close.Position = UDim2.new(1, -23, 0, 6)
            close.BackgroundColor3 = Color3.new(1, 1, 1)
            close.BackgroundTransparency = 1
            close.Image = getcustomasset('catnext/assets/new/closemini.png')
            close.ImageColor3 = color.Light(uipallet.Text, 0.2)
            close.ImageTransparency = 0.5
            close.AutoButtonColor = false
            close.Parent = hotbar
            local closecorner = Instance.new('UICorner')
            closecorner.CornerRadius = UDim.new(1, 0)
            closecorner.Parent = close
            close.MouseEnter:Connect(function()
                close.ImageTransparency = 0.3
                tween:Tween(close, TweenInfo.new(0.2), {
                    BackgroundTransparency = 0.6
                })
            end)
            close.MouseLeave:Connect(function()
                close.ImageTransparency = 0.5
                tween:Tween(close, TweenInfo.new(0.2), {
                    BackgroundTransparency = 1
                })
            end)
            close.MouseButton1Click:Connect(function()
                local ind = table.find(self.Hotbars, hotbardata)
                local obj = self.Hotbars[self.Selected]
                local obj2 = self.Hotbars[ind]
                if obj and obj2 then
                    obj2.Object:ClearAllChildren()
                    obj2.Object:Destroy()
                    table.remove(self.Hotbars, ind)
                    ind = table.find(self.Hotbars, obj)
                    self.Selected = table.find(self.Hotbars, obj) or 1
                end
            end)
        end

        api.Options.HotbarList = optionapi

        return optionapi
    end

    local function getBlock()
        local clone = table.clone(store.inventory.inventory.items)
        table.sort(clone, function(a, b)
            return a.amount < b.amount
        end)

        for _, item in clone do
            local block = bedwars.ItemMeta[item.itemType].block
            if block and not block.seeThrough then
                return item
            end
        end
    end

    local function getCustomItem(v)
        if v == 'diamond_sword' then
            local sword = store.tools.sword
            v = sword and sword.itemType or 'wood_sword'
        elseif v == 'diamond_pickaxe' then
            local pickaxe = store.tools.stone
            v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
        elseif v == 'diamond_axe' then
            local axe = store.tools.wood
            v = axe and axe.itemType or 'wood_axe'
        elseif v == 'wood_bow' then
            local bow = getBow()
            v = bow and bow.itemType or 'wood_bow'
        elseif v == 'wool_white' then
            local block = getBlock()
            v = block and block.itemType or 'wool_white'
        end

        return v
    end

    local function findItemInTable(tab, item)
        for slot, v in tab do
            if item.itemType == getCustomItem(v) then
                return tonumber(slot)
            end
        end
    end

    local function findInHotbar(item)
        for i, v in store.inventory.hotbar do
            if v.item and v.item.itemType == item.itemType then
                return i - 1, v.item
            end
        end
    end

    local function findInInventory(item)
        for _, v in store.inventory.inventory.items do
            if v.itemType == item.itemType then
                return v
            end
        end
    end

    local function dispatch(...)
        bedwars.Store:dispatch(...)
        waitForSignal(vapeEvents.InventoryChanged.Event, 1, function()
            return not AutoHotbar.Enabled
        end)
    end

    local function sortCallback()
        if Active then return end
        Active = true
        local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})

        for _, v in store.inventory.inventory.items do
            local slot = findItemInTable(items, v)
            if slot then
                local olditem = store.inventory.hotbar[slot]
                if olditem.item and olditem.item.itemType == v.itemType then continue end
                if olditem.item then
                    dispatch({
                        type = 'InventoryRemoveFromHotbar',
                        slot = slot - 1
                    })
                end

                local newslot = findInHotbar(v)
                if newslot then
                    dispatch({
                        type = 'InventoryRemoveFromHotbar',
                        slot = newslot
                    })
                    if olditem.item then
                        dispatch({
                            type = 'InventoryAddToHotbar',
                            item = findInInventory(olditem.item),
                            slot = newslot
                        })
                    end
                end

                dispatch({
                    type = 'InventoryAddToHotbar',
                    item = findInInventory(v),
                    slot = slot - 1
                })
            elseif Clear.Enabled then
                local newslot = findInHotbar(v)
                if newslot then
                    dispatch({
                        type = 'InventoryRemoveFromHotbar',
                        slot = newslot
                    })
                end
            end
        end

        Active = false
    end

    AutoHotbar = vape.Categories.Inventory:CreateModule({
        Name = 'Auto Hotbar',
        Function = function(callback)
            if callback then
                task.spawn(sortCallback)
                if Mode.Value == 'On Key' then
                    AutoHotbar:Toggle()
                    return
                end

                AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
            end
        end,
        Tooltip = 'Automatically arranges hotbar to your liking.'
    })
    Mode = AutoHotbar:CreateDropdown({
        Name = 'Activation',
        List = {'Toggle', 'On Key'},
        Function = function()
            if AutoHotbar.Enabled then
                AutoHotbar:Toggle()
                AutoHotbar:Toggle()
            end
        end
    })
    Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
    List = AutoHotbar:CreateHotbarList({})
end)

run(function()
	local NoTextures
	local Materials = {}
	local Decals = {}
	local Meshes = {}
	local reference = {}
	
	local function remember(obj, property)
		local props = reference[obj]
		if not props then
			props = {}
			reference[obj] = props
		end
	
		if props[property] == nil then
			props[property] = obj[property]
		end
	end
	
	local function stripObject(obj)
		if Decals.Enabled and obj:IsA('Decal') then
			remember(obj, 'Transparency')
			obj.Transparency = 1
			return
		end
	
		if Decals.Enabled and obj:IsA('SurfaceAppearance') then
			remember(obj, 'Parent')
			obj.Parent = nil
			return
		end
	
		if Meshes.Enabled and obj:IsA('SpecialMesh') then
			remember(obj, 'TextureId')
			obj.TextureId = ''
			return
		end
	
		if obj:IsA('BasePart') then
			if Meshes.Enabled and obj:IsA('MeshPart') then
				remember(obj, 'TextureID')
				obj.TextureID = ''
			end
	
			if Materials.Enabled then
				remember(obj, 'Material')
				obj.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	
	local function restore()
		for i, v in reference do
			pcall(function()
				for property, value in v do
					i[property] = value
				end
			end)
		end
		table.clear(reference)
	end
	
	local function scan()
		local descendants = store.map:GetDescendants()
	
		for i, v in descendants do
			if not NoTextures.Enabled then return end
			stripObject(v)
	
			if i % 500 == 0 then
				task.wait()
			end
		end
	end
	
	local function refresh()
		if not NoTextures.Enabled then return end
		restore()
		scan()
	end
	
	NoTextures = vape.Categories.Render:CreateModule({
		Name = 'NoTextures',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.map or not NoTextures.Enabled
				if not NoTextures.Enabled then return end
	
				NoTextures:Clean(store.map.DescendantAdded:Connect(function(obj)
					task.defer(stripObject, obj)
				end))
				scan()
			else
				restore()
			end
		end,
		Tooltip = 'Removes textures and materials from the map'
	})
	Materials = NoTextures:CreateToggle({
		Name = 'Materials',
		Default = true,
		Function = refresh,
		Tooltip = 'Flattens every part to smooth plastic'
	})
	Decals = NoTextures:CreateToggle({
		Name = 'Decals',
		Default = true,
		Function = refresh,
		Tooltip = 'Hides decals, textures and PBR surfaces'
	})
	Meshes = NoTextures:CreateToggle({
		Name = 'Meshes',
		Default = true,
		Function = refresh,
		Tooltip = 'Clears textures off meshes'
	})
	
end)

run(function()
	local BulletTracers
	local Material
	local Lifetime
	local Curve
	local Opacity
	local Thickness
	local Color
	local Fade
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	BulletTracers = vape.Categories.Render:CreateModule({
		Name = 'ProjectileTracers',
		Function = function(callback)
			if callback then
				BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
					task.delay(0, function()
						if not BulletTracers.Enabled or not projectile.Parent or projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then
							return
						end
						local filter = {projectile}
						if lplr.Character then table.insert(filter, lplr.Character) end
						rayCheck.FilterDescendantsInstances = filter
						local root = projectile:IsA('BasePart') and projectile or projectile:IsA('Model') and projectile.PrimaryPart
						local meta = bedwars.ProjectileMeta[projectile.Name]
						if not root or not meta then return end
						local origin = root.Position
						local velocity = root.AssemblyLinearVelocity
						local velocityMagnitude = velocity.Magnitude
						if velocityMagnitude <= 0 then
							return
						end
						local velocityUnit = velocity / velocityMagnitude
						local gravity = meta.gravitationalAcceleration or workspace.Gravity
						local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
						local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
						local travelTime = (endpoint - origin).Magnitude / velocityMagnitude
	
						prediction.SpawnArcTracer(origin, velocityUnit, velocityMagnitude, gravity, travelTime, Curve.Value, {
	                        Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
	                        Transparency = Opacity.Value,
	                        Thick = Thickness.Value,
	                        Material = Enum.Material[Material.Value],
	                        Lifetime = Lifetime.Value,
	                        Fade = Fade.Enabled
	                    })
					end)
				end))
			end
		end,
		Tooltip = 'Replacement tracers for projectiles'
	})
	
	local materials = {'SmoothPlastic'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'SmoothPlastic' then
			table.insert(materials, v.Name)
		end
	end
	Material = BulletTracers:CreateDropdown({
		Name = 'Material',
		List = materials
	})
	Color = BulletTracers:CreateColorSlider({
		Name = 'Tracer Color',
		DefaultOpacity = 0.5
	})
	Thickness = BulletTracers:CreateSlider({
		Name = 'Thickness',
		Min = 0.01,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Curve = BulletTracers:CreateSlider({
		Name = 'Curveness',
		Min = 1,
		Max = 100,
		Default = 40,
		Tooltip = 'How curve the projectile is gonna be\n(More curve = more lag)'
	})
	Opacity = BulletTracers:CreateSlider({
		Name = 'Opacity',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100
	})
	Lifetime = BulletTracers:CreateSlider({
		Name = 'Lifetime',
		Min = 0,
		Max = 5,
		Decimal = 100,
		Default = 2,
		Suffix = 'secs'
	})
	Fade = BulletTracers:CreateToggle({
		Name = 'Fade',
		Default = true
	})
end)

run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function nearStorageItem(item)
		for _, v in List.ListEnabled do
			if item:find(v) then return v end
		end
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then
			v.Enabled = false
			return
		end
	
		local chestitems = chest and chest:GetChildren() or {}
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		v.Enabled = false
		local alreadygot = {}
		for _, item in chestitems do
			if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
				alreadygot[item.Name] = true
				v.Enabled = true
				local blockimage = Instance.new('ImageLabel')
				blockimage.Size = UDim2.fromOffset(32, 32)
				blockimage.BackgroundTransparency = 1
				blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:WaitForChild('ChestFolderValue', 3)
		if not (chest and StorageESP.Enabled) then return end
		chest = chest.Value
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		StorageESP:Clean(chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		task.spawn(refreshAdornee, billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				for _, v in collectionService:GetTagged('chest') do
					task.spawn(Added, v)
				end
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local AntiLasso
	local Chance
	local Check
	
	local function Added(ent)
	    AntiLasso:Clean(ent.ChildAdded:Connect(function(v)
	        if v:IsA('Accessory') and v:FindFirstChild('Rope') and Random.new(os.clock()):NextNumber(1, 100) < Chance.Value and (not Check.Enabled or entitylib.EntityPosition({
	            Range = 50,
	            Part = 'RootPart',
	            Players = true
	        })) then
	            ent.PrimaryPart.Anchored = true
	            v.Destroying:Once(function()
	                task.wait(0.5)
	                ent.PrimaryPart.Anchored = false
	            end)
	        end
	    end))
	end
	
	AntiLasso = vape.Categories.Utility:CreateModule({
	    Name = 'AntiLasso',
	    Function = function(callback)
	        if callback then
	            AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
	                task.delay(1, function()
	                    Added(ent.Character)
	                end)
	            end))
	            if entitylib.isAlive then
	                Added(lplr.Character)
	            end
	        end
	    end,
	    Tooltip = 'Prevents you from getting pulled by lasso projectile.'
	})
	
	Chance = AntiLasso:CreateSlider({
	    Name = 'Chance',
	    Min = 0,
	    Max = 100,
	    Default = 100,
	    Suffix = '%'
	})
	Check = AntiLasso:CreateToggle({Name = 'Only when targeting'})
end)

run(function()
    local Breaker
    local BreakType
    local Range
    local BreakSpeed
    local UpdateRate
    local Custom
    local Bed
    local Tesla
    local Hive
    local LuckyBlock
    local IronOre
    local Effect
    local CustomHealth = {}
    local Animation
    local SelfBreak
    local InstantBreak
    local LimitItem
    local activeRoute = {requestVersion = 0, state = 'Idle'}
    local loopVersion = 0
    local customlist, parts = {}, {}

    local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
        xpcall(function()
            if block:GetAttribute('NoHealthbar') then return end
            if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
                if self.healthbarPart then
                    bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)
                end
                self.maid:DoCleaning()
                self.healthbarBlockRef = blockRef
                local create = bedwars.Roact.createElement
                local percent = math.clamp(health / maxHealth, 0, 1)
                local cleanCheck = true
                local part = Instance.new('Part')
                part.Size = Vector3.one
                part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
                part.Transparency = 1
                part.Anchored = true
                part.CanCollide = false
                part.Parent = workspace
                bedwars.QueryUtil:setQueryIgnored(part, true)
                self.healthbarPart = part

                local mounted = bedwars.Roact.mount(create('BillboardGui', {
                    Size = UDim2.fromOffset(249, 102),
                    StudsOffset = Vector3.new(0, 2.5, 0),
                    Adornee = part,
                    MaxDistance = 40,
                    AlwaysOnTop = true
                }, {
                    create('Frame', {
                        Size = UDim2.fromOffset(160, 50),
                        Position = UDim2.fromOffset(44, 32),
                        BackgroundColor3 = Color3.new(),
                        BackgroundTransparency = 0.5
                    }, {
                        create('UICorner', {CornerRadius = UDim.new(0, 5)}),
                        create('ImageLabel', {
                            Size = UDim2.new(1, 89, 1, 52),
                            Position = UDim2.fromOffset(-48, -31),
                            BackgroundTransparency = 1,
                            Image = getcustomasset('catnext/assets/new/blur.png'),
                            ScaleType = Enum.ScaleType.Slice,
                            SliceCenter = Rect.new(52, 31, 261, 502)
                        }),
                        create('TextLabel', {
                            Size = UDim2.fromOffset(145, 14),
                            Position = UDim2.fromOffset(13, 12),
                            BackgroundTransparency = 1,
                            Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            TextColor3 = Color3.new(),
                            TextScaled = true,
                            Font = Enum.Font.Arial
                        }),
                        create('TextLabel', {
                            Size = UDim2.fromOffset(145, 14),
                            Position = UDim2.fromOffset(12, 11),
                            BackgroundTransparency = 1,
                            Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            TextColor3 = color.Dark(uipallet.Text, 0.16),
                            TextScaled = true,
                            Font = Enum.Font.Arial
                        }),
                        create('Frame', {
                            Size = UDim2.fromOffset(138, 4),
                            Position = UDim2.fromOffset(12, 32),
                            BackgroundColor3 = uipallet.Main
                        }, {
                            create('UICorner', {CornerRadius = UDim.new(1, 0)}),
                            create('Frame', {
                                [bedwars.Roact.Ref] = self.blockHealthbar.healthbarProgressRef,
                                Size = UDim2.fromScale(percent, 1),
                                BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
                            }, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
                        })
                    })
                }), part)

                self.maid:GiveTask(function()
                    cleanCheck = false
                    self.healthbarBlockRef = nil
                    bedwars.Roact.unmount(mounted)
                    if self.healthbarPart then
                        self.healthbarPart:Destroy()
                    end
                    self.healthbarPart = nil
                end)

                bedwars.RuntimeLib.Promise.delay(5):andThen(function()
                    if cleanCheck then
                        self.maid:DoCleaning()
                    end
                end)
            end

            local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
            tweenService:Create(self.blockHealthbar.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
                Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
            }):Play()
        end, function(...)
            if shared.VapeDeveloper then
                warn(...)
            end
        end)
    end

    local function canBreakBlock(block, blockpos)
        if typeof(block) ~= 'Instance' or not block:IsA('BasePart') or not block.Parent or typeof(blockpos) ~= 'Vector3' then return false end
        if bedwars.BlockController:getStore():getBlockAt(blockpos) ~= block then return false end
        if not bedwars.BlockController:isBlockBreakable({blockPosition = blockpos}, lplr) then return false end
        if SelfBreak and not SelfBreak.Enabled and block:GetAttribute('PlacedByUserId') == lplr.UserId then return false end
        if (block:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then return false end
        local handmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
        if LimitItem and LimitItem.Enabled and not (handmeta and handmeta.breakBlock) then return false end
        return true
    end

    local function isBreakTargetValid(block, localPosition)
        if typeof(block) ~= 'Instance' or not block.Parent or (block.Position - localPosition).Magnitude >= Range.Value then return false end
        return canBreakBlock(block, bedwars.BlockController:getBlockPosition(block.Position))
    end

    local function renderPath(target, path, endpos)
        if not path then return end
        local currentnode = target
        for _, part in parts do
            part.Position = currentnode or Vector3.zero
            if currentnode then
                part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
            end
            currentnode = path[currentnode]
        end
    end

    local function breakTarget(block)
        local target, path, endpos, result = bedwars.breakBlock(block, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, {
            canBreak = canBreakBlock,
            mode = BreakType and BreakType.Value or 'Blatant',
            routeState = activeRoute
        })
        if result == 'Sent' then
            renderPath(target, path, endpos)
            task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)
            return true
        end
        return result ~= 'Complete' and result ~= 'NoRoute' and result ~= 'RouteInvalid'
    end

    local function attemptBreak(lists, localPosition)
        local previous = activeRoute.block
        if previous then
            local found
            for _, list in lists do
                if list and table.find(list, previous) then
                    found = true
                    break
                end
            end
            if found and isBreakTargetValid(previous, localPosition) then
                if breakTarget(previous) then return true end
            end
            bedwars.cancelBreakRoute(activeRoute, 'TargetInvalid')
        end

        for _, list in lists do
            if not list then continue end
            for _, block in list do
                if block ~= previous and isBreakTargetValid(block, localPosition) then
                    if breakTarget(block) then return true end
                end
            end
        end
        return false
    end

    local function invalidateRoute(value)
        if not activeRoute.block or not entitylib.isAlive then return end
        local position = typeof(value) == 'Instance' and value:IsA('BasePart') and value.Position
            or type(value) == 'table' and value.blockRef and typeof(value.blockRef.blockPosition) == 'Vector3' and value.blockRef.blockPosition * 3
        if not position then return end
        local rootPosition = entitylib.character.RootPart.Position
        local target = activeRoute.currentTarget or activeRoute.target
        if (rootPosition - position).Magnitude <= 36 or target and (target - position).Magnitude <= 21 then
            bedwars.invalidateBreakRoute(activeRoute, position, 'DefenseChanged')
        end
    end

    Breaker = vape.Categories.Minigames:CreateModule({
        Name = 'Breaker',
        Function = function(callback)
            loopVersion += 1
            local version = loopVersion
            if callback then
                bedwars.cancelBreakRoute(activeRoute, 'Enabled')
                for _ = 1, 30 do
                    local part = Instance.new('Part')
                    part.Anchored = true
                    part.CanQuery = false
                    part.CanCollide = false
                    part.Transparency = 1
                    part.Parent = gameCamera
                    local highlight = Instance.new('BoxHandleAdornment')
                    highlight.Size = Vector3.one
                    highlight.AlwaysOnTop = true
                    highlight.ZIndex = 1
                    highlight.Transparency = 0.5
                    highlight.Adornee = part
                    highlight.Parent = part
                    table.insert(parts, part)
                end

                local beds = collection('bed', Breaker)
                local luckyblock = collection('LuckyBlock', Breaker)
                local ironores = collection('iron_ore_mesh_block', Breaker)
                local teslas = collection('tesla-trap', Breaker, function(tab, obj)
                    task.delay(0.1, function()
                        if not Breaker.Enabled or not obj.Parent then return end
                        local player = playersService:GetPlayerByUserId(obj:GetAttribute('PlacedByUserId'))
                        if player and player:GetAttribute('Team') ~= lplr:GetAttribute('Team') then
                            table.insert(tab, obj)
                        end
                    end)
                end)
                local hives = collection('beehive', Breaker, function(tab, obj)
                    task.delay(0.1, function()
                        if not Breaker.Enabled or not obj.Parent then return end
                        local player = playersService:GetPlayerByUserId(obj:GetAttribute('PlacedByUserId'))
                        if player and player:GetAttribute('Team') ~= lplr:GetAttribute('Team') then
                            table.insert(tab, obj)
                        end
                    end)
                end)
                customlist = collection('block', Breaker, function(tab, obj)
                    if table.find(Custom.ListEnabled, obj.Name) then
                        table.insert(tab, obj)
                    end
                end)

                Breaker:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(invalidateRoute))
                Breaker:Clean(collectionService:GetInstanceRemovedSignal('block'):Connect(invalidateRoute))
                Breaker:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(invalidateRoute))
                Breaker:Clean(vapeEvents.BreakBlockEvent.Event:Connect(invalidateRoute))
                Breaker:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    bedwars.cancelBreakRoute(activeRoute, 'MatchEnded')
                end))
                Breaker:Clean(lplr.CharacterAdded:Connect(function()
                    bedwars.cancelBreakRoute(activeRoute, 'CharacterChanged')
                end))
                Breaker:Clean(function()
                    bedwars.cancelBreakRoute(activeRoute, 'Cleaned')
                end)

                repeat
                    task.wait(1 / UpdateRate.Value)
                    if not Breaker.Enabled or version ~= loopVersion then break end
                    if store.matchState == 2 then
                        if activeRoute.block then
                            bedwars.cancelBreakRoute(activeRoute, 'MatchEnded')
                        end
                    elseif entitylib.isAlive then
                        local localPosition = entitylib.character.RootPart.Position
                        if not attemptBreak({
                            Bed.Enabled and beds or false,
                            Tesla.Enabled and teslas or false,
                            Hive.Enabled and hives or false,
                            customlist,
                            LuckyBlock.Enabled and luckyblock or false,
                            IronOre.Enabled and ironores or false
                        }, localPosition) then
                            for _, v in parts do
                                v.Position = Vector3.zero
                            end
                        end
                    elseif activeRoute.block then
                        bedwars.cancelBreakRoute(activeRoute, 'CharacterMissing')
                    end
                until not Breaker.Enabled or version ~= loopVersion
            else
                bedwars.cancelBreakRoute(activeRoute, 'Disabled')
                for _, v in parts do
                    v:ClearAllChildren()
                    v:Destroy()
                end
                table.clear(parts)
            end
        end,
        Tooltip = 'Break blocks around you automatically'
    })
    BreakType = Breaker:CreateDropdown({
        Name = 'Break Type',
        List = {'Blatant', 'Legit'},
        Default = 'Blatant',
        Function = function()
            if Breaker.Enabled then
                bedwars.cancelBreakRoute(activeRoute, 'ModeChanged', true)
            end
        end
    })
    Range = Breaker:CreateSlider({
        Name = 'Break range',
        Min = 1,
        Max = 30,
        Default = 30,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    BreakSpeed = Breaker:CreateSlider({
        Name = 'Break speed',
        Min = 0,
        Max = 0.3,
        Default = 0.25,
        Decimal = 100,
        Suffix = 'seconds'
    })
    UpdateRate = Breaker:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
    Custom = Breaker:CreateTextList({
        Name = 'Custom',
        Function = function()
            if not customlist then return end
            table.clear(customlist)
            for _, obj in store.blocks do
                if table.find(Custom.ListEnabled, obj.Name) then
                    table.insert(customlist, obj)
                end
            end
        end
    })
    Bed = Breaker:CreateToggle({
        Name = 'Break Bed',
        Default = true
    })
    Tesla = Breaker:CreateToggle({
        Name = 'Break Tesla',
        Default = true
    })
    Hive = Breaker:CreateToggle({
        Name = 'Break Hive',
        Default = true
    })
    LuckyBlock = Breaker:CreateToggle({
        Name = 'Break Lucky Block',
        Default = true
    })
    IronOre = Breaker:CreateToggle({
        Name = 'Break Iron Ore',
        Default = true
    })
    Effect = Breaker:CreateToggle({
        Name = 'Show Healthbar & Effects',
        Function = function(callback)
            if CustomHealth.Object then
                CustomHealth.Object.Visible = callback
            end
        end,
        Default = true
    })
    CustomHealth = Breaker:CreateToggle({
        Name = 'Custom Healthbar',
        Default = true,
        Darker = true
    })
    Animation = Breaker:CreateToggle({Name = 'Animation'})
    SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
    InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
    LimitItem = Breaker:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only breaks when tools are held'
    })
end)

--[[
    Kits
]]

run(function()
    local AutoCobalt -- made by ba0
    local HitboxSize
    local RestoreOnDisable

    local originalProperties = setmetatable({}, {__mode = 'k'})
    local workspaceConnection

    local function pruneDead()
        for part in pairs(originalProperties) do
            if not part.Parent then
                originalProperties[part] = nil
            end
        end
    end

    -- Helper function to expand the hitbox of a specific battery model
    local function expandBattery(obj, size)
        if obj.Name == "Open" and obj:IsA("Model") then
            -- Verify it is a Cobalt battery
            if obj:FindFirstChild("Invertedneon") or obj:FindFirstChild("Top") then
                pruneDead()
                task.wait(0.1)
                -- Stop execution if the module was toggled off during wait
                if not AutoCobalt.Enabled then return end

                for _, part in pairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") then
                        -- Store original properties before modifying them
                        if not originalProperties[part] then
                            originalProperties[part] = {
                                Size = part.Size,
                                CanCollide = part.CanCollide,
                                CanTouch = part.CanTouch
                            }
                        end

                        part.CanCollide = false
                        part.CanTouch = true
                        part.Size = Vector3.new(size, size, size)
                    end
                end
            end
        end
    end

    -- Restores all modified parts to their original state
    local function restoreAllProperties()
        for part, props in pairs(originalProperties) do
            if part and part.Parent then
                part.Size = props.Size
                part.CanCollide = props.CanCollide
                part.CanTouch = props.CanTouch
            end
        end
        table.clear(originalProperties)
    end

    AutoCobalt = vape.Categories.Kits:CreateModule({
        Name = 'Auto Cobalt',
        Function = function(callback)
            if callback then
                -- Scan existing parts in the workspace
                for index, descendant in pairs(workspace:GetDescendants()) do
                    if descendant:IsA('Model') and descendant.Name == 'Open' then
                        expandBattery(descendant, HitboxSize.Value)
                    end
                    if index % 250 == 0 then
                        task.wait()
                        if not AutoCobalt.Enabled then break end
                    end
                end

                -- Monitor for new battery spawns
                workspaceConnection = workspace.DescendantAdded:Connect(function(descendant)
                    if descendant:IsA('Model') and descendant.Name == 'Open' then
                        task.spawn(expandBattery, descendant, HitboxSize.Value)
                    end
                end)
                AutoCobalt:Clean(workspaceConnection)
            else
                -- Disconnect listener on toggle off
                if workspaceConnection then
                    workspaceConnection:Disconnect()
                    workspaceConnection = nil
                end

                -- Restore properties if the option is active
                if RestoreOnDisable.Enabled then
                    restoreAllProperties()
                else
                    table.clear(originalProperties)
                end
            end
        end,
        Tooltip = 'Expands the touch detection area of Cobalt batteries to collect them instantly'
    })

    HitboxSize = AutoCobalt:CreateSlider({
        Name = 'Hitbox Size',
        Min = 1,
        Max = 100,
        Default = 50,
        Suffix = ' studs',
        Tooltip = 'The dimension size applied to the battery components'
    })

    RestoreOnDisable = AutoCobalt:CreateToggle({
        Name = 'Restore on disable',
        Default = true,
        Tooltip = 'Reverts the size of active batteries when this feature is turned off'
    })
end)

run(function()
	local AutoBlockUp
	local LimitItem
	local lastPlace = 0
	
	local function getBlockUpItem()
		if store.hand.toolType == 'block' then
			return store.hand.tool and store.hand.tool.Name
		elseif not LimitItem.Enabled then
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block then
					return item.itemType
				end
			end
		end
		return nil
	end
	
	AutoBlockUp = vape.Categories.Utility:CreateModule({
		Name = 'AutoBlockUp',
		Function = function(callback)
			if callback then
				AutoBlockUp:Clean(runService.Heartbeat:Connect(function()
	                if entitylib.isAlive and up then
	                    local item = getBlockUpItem()
	                    if item then
	                        local pos = roundPos(entitylib.character.RootPart.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
	                        if tick() >= lastPlace and not getPlacedBlock(pos) then
	                            lastPlace = tick() + 0.15
	                            bedwars.placeBlock(pos, item, false)
	                        end
	
	                        entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 35, entitylib.character.RootPart.Velocity.Z)
	                    end
	                end
				end))
	            AutoBlockUp:Clean(inputService.InputBegan:Connect(function(input)
	                if not inputService:GetFocusedTextBox() then
	                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
	                        up = true
	                    end
	                end
	            end))
	            AutoBlockUp:Clean(inputService.InputEnded:Connect(function(input)
	                if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
	                    up = false
	                    entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 0, entitylib.character.RootPart.Velocity.Z)
	                end
	            end))
	            if inputService.TouchEnabled then
	                pcall(function()
	                    local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
	                    AutoBlockUp:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
	                        up = jumpButton.ImageRectOffset.X == 146 and true or false
	                    end))
	                end)
	            end
			end
		end,
		Tooltip = 'Places a block beneath you while holding jump so you can tower up instantly'
	})
	
	LimitItem = AutoBlockUp:CreateToggle({Name = 'Limit to items'})
end)

run(function()
	local AutoCounter
	local Mode
	local Range
	local Limit
	local AutoSwitch = {}
	
	local function getAttackData()
	    if Limit.Enabled then
	        local tool = store.hand.tool
	        return tool and tool.Name == 'tnt' and tool or nil
	    end
	    local item = getItem('tnt')
	    return item and item.tool or nil
	end
	
	AutoCounter = vape.Categories.Utility:CreateModule({
	    Name = 'AutoCounterTNT',
	    Function = function(callback)
	        if callback then
	            local tnts, placed = {}, {}
	            AutoCounter:Clean(workspace.ChildAdded:Connect(function(v)
	                if v.Name == 'tnt' then
	                    table.insert(tnts, v)
	                    v.Destroying:Once(function()
	                        local index = table.find(tnts, v)
	                        if index then
	                            table.remove(tnts, index)
	                        end
	                    end)
	                end
	            end))
	            repeat
	                for pos, expiry in placed do
	                    if expiry <= tick() then
	                        placed[pos] = nil
	                    end
	                end
	                if entitylib.isAlive then
	                    local item = getAttackData()
	                    if item then
	                        local localPosition = entitylib.character.RootPart.Position
	                        for _, v in tnts do
	                            local roundedPos = Vector3.new(math.round(v.Position.X), math.round(v.Position.Y), math.round(v.Position.Z))
	                            if v.Velocity.Y >= 0 and not placed[roundedPos] and (localPosition - v.Position).Magnitude <= Range.Value then
	                                if not Limit.Enabled and AutoSwitch.Enabled then
	                                    local hotbar = getHotbar(item)
	                                    switchItem(item)
	                                    if hotbar then
	                                        hotbarSwitch(hotbar)
	                                    end
	                                end
	                                placed[roundedPos] = tick() + 3
	                                task.spawn(bedwars.placeBlock, v.Position, item.Name)
	                                task.wait(0.12)
	                            end
	                        end
	                    end
	                end
	                task.wait(0.1)
	            until not AutoCounter.Enabled
	        end
	    end,
	    Tooltip = 'Automatically places tnt on opponent\'s tnt'
	})
	
	Mode = AutoCounter:CreateDropdown({
	    Name = 'Mode',
	    List = {'Toggle', 'On key'},
	    Default = 'Toggle'
	})
	Range = AutoCounter:CreateSlider({
	    Name = 'Range',
	    Min = 1,
	    Max = 60,
	    Default = 30
	})
	Limit = AutoCounter:CreateToggle({
	    Name = 'Limit to item',
	    Function = function(callback)
	        if AutoSwitch.Object then
	            AutoSwitch.Object.Visible = not callback
	        end
	    end
	})
	AutoSwitch = AutoCounter:CreateToggle({
	    Name = 'Auto Switch',
	    Function = function(callback)
	        Limit.Object.Visible = not callback
	    end,
	    Default = true
	})
end)

run(function()
	local AutoHonor
	local Delay
	
	local Honored = {}
	local function honor()
	    if #Honored > 1 then return end
	    local list, team = table.clone(entitylib.List), lplr:GetAttribute('Team')
	    table.sort(list, function(a, b)
	        return a.Player:GetAttribute('Team') == team and b.Player:GetAttribute('Team') ~= team
	    end)
	    for _, v in list do
	        if #Honored > 1 then break end
	        if not table.find(Honored, v.Player) then
	            bedwars.HonorController:honorPlayer(v.Player.UserId)
	            table.insert(Honored, v.Player)
	            task.wait(Delay.Value)
	        end
	    end
	end
	
	AutoHonor = vape.Categories.Utility:CreateModule({
	    Name = 'AutoHonor',
	    Function = function(callback)
	        if callback then
	            AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
	                if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
	                    honor()
	                end
	            end))
	            AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(honor))
	        end
	    end,
	    Tooltip = 'Automatically honor your teammates'
	})
	
	Delay = AutoHonor:CreateSlider({
	    Name = 'Delay',
	    Min = 0,
	    Max = 2,
	    Decimal = 100,
	    Suffix = 'seconds',
	    Default = 0.1
	})
end)

run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Handler:Get('ConsumeBattery'):Fire('SendToServer', {batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})
	
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
	
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
	
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Handler:Get('RequestDragonPunch'):Fire('SendToServer', {
					target = v
				})
			end, 18, true)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Handler:Get('HarvestCrop'):Fire('CallServer', {position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end
	
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
	
				if ent and getItem('guitar') then
					bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
						healTarget = ent.Character
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			kitCollection('hidden-metal', function(v)
				bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
					id = v:GetAttribute('Id')
				})
			end, 20, false)
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Handler:Get('DestroyPetrifiedPlayer'):Fire('SendToServer', {
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Handler:Get('DepositCoins'):Fire('CallServer', v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})
	
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
	
					bedwars.Handler:Get('SummonerClawAttackRequest'):Fire('SendToServer', {
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Handler:Get('DragonFlap'):Fire('CallServer') then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Handler:Get('DragonBreath'):Fire('SendToServer', {
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Handler:Get('WarlockLinkTarget'):Fire('CallServer', {
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability) then
					local plr = entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
	
					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}
	
	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)

run(function()
	local AutoPearl
	local Legit
	local Back
	local Check
	local LandCheck
	local BackDelay
	local Limit
	
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	
	local function firePearl(pos, spot, item)
		if Check.Enabled then
			--[[for _, v in store.selfProjectiles do -- later maybe
				if v.Name == 'telepearl' then
					return
				end
			end]]
		end
		local hotbar, old = getHotbar(item.tool), store.hand
	
		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end
	
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
		local landed = false
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
			local res = bedwars.Handler:Get('ProjectileFire'):Fire('CallServer',
				item.tool,
				'telepearl',
				'telepearl',
				pos,
				pos,
				dir,
				httpService:GenerateGUID(true),
				{ 
	                drawDurationSeconds = 1, 
	                shotId = httpService:GenerateGUID(false) 
	            },
				workspace:GetServerTimeNow() - 0.045
			)
			task.spawn(function()
				local timeout = tick() + 10
				repeat
					task.wait()
				until not AutoPearl.Enabled or not projectile or not projectile.Parent or tick() >= timeout
				landed = true
			end)
			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			end
		else
			landed = true
		end
	
		if Back.Enabled and LandCheck.Enabled then
			repeat
				task.wait()
			until landed or not AutoPearl.Enabled
		end
		if Back.Enabled and old and old.tool then
			task.wait(BackDelay:GetRandomValue())
			switchItem(old.tool)
			if Legit.Enabled and getHotbar(old.tool) then
				hotbarSwitch(getHotbar(old.tool))
			end
		end
	end
	
	local function findNearGround(origin)
		for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
			for i = 1, 24 do
				local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
		return nil
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local check, lasty
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'telepearl') then
						local root = entitylib.character.RootPart
						local pearl = getItem('telepearl')
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lasty = root.CFrame
						end
	
						if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoPearl.Enabled
			end
		end,
		Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
	})
	
	Legit = AutoPearl:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Visualizes the switching clientside',
		Default = true
	})
	Back = AutoPearl:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
			if LandCheck then
				LandCheck.Object.Visible = callback
			end
		end,
		Tooltip = 'Switches back to the last slot before pearl'
	})
	LandCheck = AutoPearl:CreateToggle({
		Name = 'Only after landed',
		Tooltip = 'Only switches back after your pearl landed',
		Darker = true
	})
	Check = AutoPearl:CreateToggle({
		Name = 'Pearl check',
		Tooltip = 'Doesn\'t throw a pearl if ur already pearling',
		Default = true
	})
	BackDelay = AutoPearl:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = AutoPearl:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws pearl when holding a pearl'
	})
end)

run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)

run(function()
	local AutoShoot
	local Targets
	local Check
	local Projectiles
	local FireRate
	local SwitchDelay
	
	local FireDelays = {}
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
		return
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			local proj = meta.projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and (table.find(Projectiles.ListEnabled, ammo) or table.find(Projectiles.ListEnabled, item.itemType) or table.find(Projectiles.ListEnabled, meta.displayName)) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	local function getEntity()
		local selfpos = entitylib.character.RootPart.Position
		local plrs = entitylib.AllPosition({
			Origin = selfpos,
			Part = 'RootPart',
			Range = 22,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		})
		if #plrs > 0 then
			for _, ent in plrs do
				local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				local delta = (ent.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
				local angle = localfacing.Magnitude > 0 and delta.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(delta.Unit), -1, 1)) or 0
				if angle > (math.rad(120) / 2) then continue end
				return ent
			end
		end
		return nil
	end
	
	AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 then
						local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
						for _, data in getProjectiles() do
							local item, ammo, projectile, itemMeta = unpack(data)
							if (FireDelays[item.itemType] or 0) < tick() then
								local ent = getEntity()
								if (not Check.Enabled or ent) and hotbarSwitch(getHotbar(item.tool)) then
									bedwars.Handler:Get('TridentUnanchor'):Fire('CallServer')
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local calc = ent and prediction.SolveTrajectory(entitylib.character.RootPart.Position, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.Velocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true) or nil
									if calc then
										local shootPosition = (CFrame.new(entitylib.character.RootPart.Position, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
										local dir, id = CFrame.lookAt(shootPosition, calc).LookVector, httpService:GenerateGUID(true)
										bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
										bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync', 
											item.tool, 
											ammo, 
											projectile, 
											shootPosition, 
											entitylib.character.RootPart.Position, 
											dir * projSpeed, 
											id, 
											{
												drawDurationSeconds = 1,
												shotId = httpService:GenerateGUID(false),
											}, 
											workspace:GetServerTimeNow() - 0.045
										):andThen(function(res)
											if res then
												res.Parent = replicatedStorage
											end
										end)
										FireDelays[item.itemType] = tick() + (itemMeta.fireDelaySec + FireRate:GetRandomValue())
										task.wait(SwitchDelay.Value)
									end
								end
							end
						end
						hotbarSwitch(hotbar)
					end
					task.wait(0.1)
				until not AutoShoot.Enabled
			else
				bedwars.ProjectileController.createLocalProjectile = old
			end
		end,
		Tooltip = 'Automatically crossbow macro\'s'
	})
	
	Targets = AutoShoot:CreateTargets({Players = true})
	Check = AutoShoot:CreateToggle({
		Name = 'Target check',
		Default = true,
		Function = function(callback)
			if Targets.Object then
				Targets.Object.Visible = callback
			end
		end
	})
	Projectiles = AutoShoot:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	FireRate = AutoShoot:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)

run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Handler:Get('DropItem'):Fire('CallServer', {
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)

run(function()
	local EquipKit
	local Kit
	
	local old = {}
	
	EquipKit = vape.Categories.Utility:CreateModule({
	    Name = 'EquipKit',
	    Function = function(callback)
	        if callback then
	            EquipKit:Toggle()
	            notif('EquipKit', `{bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = old[Kit.Value]}) and 'Successfully equipped' or 'Failed to equip'} {Kit.Value}.`, 10, 'info')
	        end
	    end
	})
	
	local list = {}
	for i, v in bedwars.BedwarsKitMeta do
	    table.insert(list, v.name)
	    old[v.name] = i
	end
	table.sort(list)
	Kit = EquipKit:CreateDropdown({
	    Name = 'Equip kit',
	    List = list,
	    Default = store.equippedKit or 'Ragnar'
	})
end)

run(function()
	local KnockbackDelay
	local Chance
	local AirDelay
	local GroundDelay
	local TargetCheck
	
	local old, rand
	local function apply(type, env, ...)
		local root, mass, dir, knockback = ...
		knockback = knockback and table.clone(knockback) or {}
		knockback[type] = env[type] and knockback[type] or 0
		return old(root, mass, dir, knockback, select(5, ...))
	end
	
	KnockbackDelay = vape.Categories.Utility:CreateModule({
		Name = 'KnockbackDelay',
		Function = function(callback)
			if callback then
				old, rand = bedwars.KnockbackUtil.applyKnockback, Random.new()
				bedwars.KnockbackUtil.applyKnockback = function(...)
					if rand:NextNumber(0, 100) > Chance.Value then
						return old(...)
					end
	
					local root, mass, dir, knockback = ...
					if not TargetCheck.Enabled or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
					}) then
						local env = {}
						task.delay(AirDelay:GetRandomValue() / 1000, apply, 'horizontal', env, root, mass, dir, knockback, select(5, ...))
						task.delay(GroundDelay:GetRandomValue() / 1000, apply, 'vertical', env, root, mass, dir, knockback, select(5, ...))
						return
					end
					return old(...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old or bedwars.KnockbackUtil.applyKnockback
			end
		end,
		Tooltip = 'Delays incoming knockback packets'
	})
	
	Chance = KnockbackDelay:CreateSlider({
		Name = 'Chance',
		Min = 1,
		Max = 100,
		Suffix = '%',
	    Default = 40
	})
	AirDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Air delay',
		Min = 0,
		Max = 500,
		DefaultMin = 50,
		DefaultMax = 200
	})
	GroundDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Ground delay',
		Min = 0,
		Max = 500,
		DefaultMin = 50,
		DefaultMax = 200
	})
	TargetCheck = KnockbackDelay:CreateToggle({Name = 'Target check'})
end)

run(function()
	local LeaveParty; LeaveParty = vape.Categories.Utility:CreateModule({
	    Name = 'LeaveParty',
	    Function = function(callback)
	        if callback then
	            bedwars.PartyController:leaveParty()
	            LeaveParty:Toggle()
	        end
	    end
	})
end)

run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)

run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	local Picked = {}
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 or table.find(Picked, v) then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
							end
							
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								local InsertPosition = #Picked + 1
								table.insert(Picked, InsertPosition, v)
								task.spawn(function()
									bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {
										itemDrop = v
									}):andThen(function(suc)
										table.remove(Picked, InsertPosition)
										if suc and bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.SoundManager:playSound(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)

run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Utility:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Handler:Get('SpawnRaven'):Fire('CallServerAsync'):andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)

run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local Visual
	local FillColor
	local OutlineColor
	local adjacent, lastpos, label, visualBlock = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local wool, amount = getWool()
			if wool then
				return wool, amount
			else
				for _, item in store.inventory.inventory.items do
					if bedwars.ItemMeta[item.itemType].block then
						return item.itemType, item.amount
					end
				end
			end
		end
	
		return nil, 0
	end
	
	local function updateVisual(pos)
		if visualBlock then
			visualBlock.CFrame = pos and CFrame.new(bedwars.BlockController:getBlockPosition(pos) * 3) or visualBlock.CFrame
			visualBlock.Parent = pos and gameCamera or nil
		end
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					local preview
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()
	
						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end
	
						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end
	
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										preview = blockpos
										task.spawn(bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end
	
					updateVisual(preview)
					task.wait(0.03)
				until not Scaffold.Enabled
			else
				updateVisual()
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Visual = Scaffold:CreateToggle({
		Name = 'Visual',
		Tooltip = 'Renders an overlay on the block about to be placed',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if callback then
				visualBlock = Instance.new('Part')
				visualBlock.Size = Vector3.new(3, 3, 3)
				visualBlock.Anchored = true
				visualBlock.CanCollide = false
				visualBlock.CanQuery = false
				visualBlock.CanTouch = false
				visualBlock.CastShadow = false
				visualBlock.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = visualBlock
				selection.LineThickness = 0.04
				selection.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				selection.Transparency = 1 - OutlineColor.Opacity
				selection.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				selection.SurfaceTransparency = 1 - FillColor.Opacity
				selection.Parent = visualBlock
				bedwars.QueryUtil:setQueryIgnored(visualBlock, true)
			else
				visualBlock:Destroy()
				visualBlock = nil
			end
		end
	})
	FillColor = Scaffold:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.4,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = Scaffold:CreateColorSlider({
		Name = 'Outline Color',
		DefaultValue = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.Color3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.Transparency = 1 - opacity
			end
		end
	})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

run(function()
	local SetEmote
	local Emote
	local track
	
	local list, old = {}, {}
	for i, v in bedwars.EmoteMeta do
	    if i ~= bedwars.EmoteType.NONE and v.name and not old[v.name] then
	        old[v.name] = i
	        table.insert(list, v.name)
	    end
	end
	table.sort(list)
	
	local function cancelEmote()
	    if entitylib.isAlive then
	        if track then
	            track:Stop()
	            track:Destroy()
	            track = nil
	        end
	        if lplr.Character:GetAttribute('PlayingEmote') then
	            lplr.Character:SetAttribute('PlayingEmote', nil)
	        end
	    end
	end
	
	SetEmote = vape.Categories.Utility:CreateModule({
	    Name = 'SetEmote',
	    Function = function(callback)
	        if callback then
	            SetEmote:Toggle()
	            if entitylib.isAlive then
	                local emoteType = old[Emote.Value]
	                local meta = bedwars.EmoteMeta[emoteType]
	                if meta then
	                    lplr.Character:SetAttribute('PlayingEmote', emoteType)
	                    bedwars.EmoteController:playEmoteBeginSounds(emoteType, lplr)
	                    local animation = meta.animation
	                    if not animation and animation.emoteDisplayType then
	                        local display = bedwars.EmoteDisplayMeta[meta.emoteDisplayType]
	                        animation = display and display.animation
	                    end
	                    if animation and not noAutoPlayAnimation then
	                        track = lplr.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(animation.type))
	                        track.Looped = animation.looped or false
	                        track:Play(nil, nil, animation.speed or 1)
	                    end
	                    if not meta.animation then
	                        local gui = Instance.new('BillboardGui')
	                        gui.Size = UDim2.fromScale(6, 2.5)
	                        gui.StudsOffset = Vector3.new(0, 2, 0)
	                        gui.AlwaysOnTop = true
	                        gui.Adornee = lplr.Character.Head
	
	                        local image = Instance.new('ImageLabel')
	                        image.AnchorPoint = Vector2.new(0.5, 1)
	                        image.Position = UDim2.fromScale(0.5, 1)
	                        image.Size = UDim2.fromScale(0, 0)
	                        image.Image = meta.image
	                        image.BackgroundTransparency = 1
	                        image.ImageTransparency = 1
	                        image.ScaleType = Enum.ScaleType.Fit
	                        image.Parent = gui
	
	                        gui.Parent = lplr.Character.Head
	                        tweenService:Create(image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
	                            Position = UDim2.fromScale(0.5, 0.5),
	                            Size = UDim2.fromScale(1, 1),
	                            ImageTransparency = 0
	                        }):Play()
	                    end
	                    if meta.allowMovement then
	                        task.delay(6, cancelEmote)
	                    else
	                        lplr.Character.Humanoid:GetPropertyChangedSignal('MoveDirection'):Once(cancelEmote)
	                    end
	                end
	            end
	        end
	    end,
	    Tooltip = 'Plays selected emote clientsidedly'
	})
	
	Emote = SetEmote:CreateDropdown({
	    Name = 'Emote',
	    List = list,
	    Default = 'nightmare'
	})
end)

run(function()
	local SetSettings
	local old = bedwars.SettingsController.settings or {}
	local options = {}
	
	SetSettings = vape.Categories.Utility:CreateModule({
	    Name = 'SetSettings',
	    Function = function(callback)
	        if callback then
	            for i in old do
	                local module = options[i]
	                if module then
	                    bedwars.SettingsController:setSetting(i, module.Value)
	                end
	            end
	        end
	    end,
	    Tooltip = 'Adds bedwars settings options to cat vape (also carries the settings with your cv config).'
	})
	
	for i, v in old do
	    if bedwars.SettingsMeta[i] and bedwars.SettingsMeta[i].tab == 'Mobile' then
	        continue
	    end
	    local create = typeof(v) == 'boolean' and 'Toggle' or typeof(v) == 'number' and 'Slider' or nil
	    if create and bedwars.SettingsMeta[i] then
	        options[i] = SetSettings["Create".. create](SetSettings, {
	            Name = bedwars.SettingsMeta[i].name,
	            Default = v,
	            Min = 1,
	            Max = 360,
	            Decimal = 5,
	            Function = function(val)
	                if SetSettings.Enabled then
	                    bedwars.SettingsController:setSetting(i, val)
	                end
	            end
	        })
	    elseif shared.VapeDeveloper then
	        notif('Vape', 'Unknown bedwars setting detected ('.. i.. ')', 20, 'alert')
	    end
	end
end)

run(function()
	local ShopQuickBuy -- coded by seven
	local HoldDelay
	local CPS
	
	local holding = false
	local clickThread
	
	local function getShopId()
	    if not entitylib.isAlive then return nil end
	    local localPosition = entitylib.character.RootPart.Position
	    local id
	    for _, v in store.shop do
	        if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
	            id = v.Id
	        end
	    end
	    return id
	end
	
	local function getHoveredItem()
	    local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	    for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
	        local obj = v
	        while obj and obj ~= lplr.PlayerGui do
	            local itemType = obj.Name:match('^(.+)_ShopItemCard$')
	            if itemType then
	                return itemType
	            end
	            obj = obj.Parent
	        end
	    end
	end
	
	local function canBuy(item)
	    if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
	    if item.lockedByForge or item.disabled then return false end
	    if item.require and item.require.teamUpgrade then
	        if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
	            return false
	        end
	    end
	    local currency = getItem(item.currency)
	    return (currency and currency.amount or 0) >= item.price
	end
	
	local function purchase(itemType, shopId)
	    if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end
	
	    local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
	    if not item or not canBuy(item) then return end
	
	    bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
	        shopItem = item,
	        shopId = shopId
	    }):andThen(function(suc)
	        if not suc then return end
	        bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
	        bedwars.Store:dispatch({
	            type = 'BedwarsAddItemPurchased',
	            itemType = itemType
	        })
	        if item.tiered then
	            bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
	        end
	    end)
	end
	
	local function startClicking(itemType)
	    if clickThread then
	        task.cancel(clickThread)
	    end
	    clickThread = task.spawn(function()
	        repeat
	            local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
	            if shopId then
	                purchase(itemType, shopId)
	            end
	            task.wait(1 / CPS.Value)
	        until not holding
	        clickThread = nil
	    end)
	end
	
	ShopQuickBuy = vape.Categories.Utility:CreateModule({
	    Name = 'ShopClicker',
	    Function = function(callback)
	        if callback then
	            ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
	                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	                if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end
	
	                local itemType = getHoveredItem()
	                if not itemType then return end
	
	                holding = true
	                task.delay(HoldDelay.Value, function()
	                    if holding and getHoveredItem() == itemType then
	                        startClicking(itemType)
	                    end
	                end)
	            end))
	
	            ShopQuickBuy:Clean(inputService.InputEnded:Connect(function(input)
	                if input.UserInputType == Enum.UserInputType.MouseButton1 then
	                    holding = false
	                end
	            end))
	        else
	            holding = false
	            if clickThread then
	                task.cancel(clickThread)
	                clickThread = nil
	            end
	        end
	    end,
	    Tooltip = 'Hold on a shop item to rapidly buy it.'
	})
	HoldDelay = ShopQuickBuy:CreateSlider({
	    Name = 'Hold Delay',
	    Min = 0,
	    Max = 1,
	    Default = 0.15,
	    Decimal = 20,
	    Suffix = 'seconds'
	})
	CPS = ShopQuickBuy:CreateSlider({
	    Name = 'CPS',
	    Min = 1,
	    Max = 20,
	    Default = 20,
	    Darker = true
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined = {}
	
	local function getRole(plr, id)
		local suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if not suc then
			notif('StaffDetector', res, 30, 'alert')
		end
		return suc and res or 0
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function checkFriends(list)
		for _, v in list do
			if joined[v] then
				return joined[v]
			end
		end
		return nil
	end
	
	local function checkJoin(plr, connection)
		if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
			connection:Disconnect()
			local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
			for _ = 1, 4 do
				for _, v in pages:GetCurrentPage() do
					table.insert(tab, v.Id)
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
	
			local friend = checkFriends(tab)
			if not friend then
				staffFunction(plr, 'impossible_join')
				return true
			else
				notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
			end
		end
	end
	
	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
	
		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
		elseif getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
		else
			local connection
			connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
				checkJoin(plr, connection)
			end)
			StaffDetector:Clean(connection)
			if checkJoin(plr, connection) then
				return
			end
	
			if not plr:GetAttribute('ClanTag') then
				plr:GetAttributeChangedSignal('ClanTag'):Wait()
			end
	
			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
				connection:Disconnect()
				staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			StaffDetector:Toggle()
		end
	end)
end)

run(function()
    local originalAmbient
    local originalOutdoorAmbient

    local ChillLight = vape.Categories.Render:CreateModule({
        Name = "Chill Lighting",
        HoverText = "Changes lighting to a chill cyan/teal theme",
        Function = function(callback)
            if callback then
                -- Save original values
                originalAmbient = game.Lighting.Ambient
                originalOutdoorAmbient = game.Lighting.OutdoorAmbient

                -- Apply chill lighting
                game.Lighting.Ambient = Color3.fromRGB(32, 212, 212)
                game.Lighting.OutdoorAmbient = Color3.fromRGB(32, 212, 212)
                
                -- Optional: You can also adjust more properties
                -- game.Lighting.Brightness = 1.5
                -- game.Lighting.ClockTime = 14
            else
                -- Restore original lighting
                if originalAmbient then
                    game.Lighting.Ambient = originalAmbient
                end
                if originalOutdoorAmbient then
                    game.Lighting.OutdoorAmbient = originalOutdoorAmbient
                end
            end
        end,
        Default = false
    })
end)

run(function()
    local ChatModule = vape.Categories.Render:CreateModule({
        Name = "Chat Position",
        HoverText = "Changes the position of the chat window",
        Function = function(callback)
            if callback then
                -- Move chat down
                game:GetService("StarterGui"):SetCore("ChatWindowPosition", UDim2.new(0, 0, 0, 200))
            else
                -- Reset to default position
                game:GetService("StarterGui"):SetCore("ChatWindowPosition", UDim2.new(0, 0, 0, 0))
            end
        end,
        Default = false
    })
end)

run(function()
    local ChatCrasherThread = nil

    local ChatModule = vape.Categories.Utility:CreateModule({
        Name = "ChatCrasher",
        HoverText = "Disables Chat",
        Function = function(callback)
            if callback then
                ChatCrasherThread = task.spawn(function()
                    while task.wait(1.7) do
                        game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(" ", "All")
                    end
                end)
            else
                if ChatCrasherThread then
                    task.cancel(ChatCrasherThread)
                    ChatCrasherThread = nil
                end
            end
        end,
        Default = false
    })
end)
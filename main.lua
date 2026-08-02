local license = ... or {}
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end
license.Key = license.Key or '_key'

if isfolder('catnext') and isfolder('catnext/profiles') then
	for _, v in listfiles('catnext/profiles') do
		if not v:find('commit.txt') then
			local old = v
			v = v:gsub('catnext', 'catsix')
			writefile(v, readfile(old))
		end
	end
	delfolder('catnext/profiles')
end

local vape
local original_loadstring = loadstring
local loadstring = function(...)
	local res, err = original_loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))

if not isfolder('catnext') then
	makefolder('catnext')
end
if not isfolder('catnext/profiles') then
	makefolder('catnext/profiles')
end
if not isfolder('catnext/guis') then
	makefolder('catnext/guis')
end
if not isfolder('catnext/games') then
	makefolder('catnext/games')
end
if not isfolder('catnext/libraries') then
	makefolder('catnext/libraries')
end
if not isfolder('catnext/assets') then
	makefolder('catnext/assets')
end

local redirect = function()
	local body = httpService:JSONEncode({
		nonce = httpService:GenerateGUID(false),
		args = {
			invite = {code = 'catvape'},
			code = 'catvape'
		},
		cmd = 'INVITE_BROWSER'
	})

	for i = 1, 2 do
		task.spawn(request, {
			Method = 'POST',
			Url = 'http://127.0.0.1:6463/rpc?v=1',
			Headers = {
				['Content-Type'] = 'application/json',
				Origin = 'https://discord.com'
			},
			Body = body
		})
	end
end

if not isfile('catnext/profiles/commit.txt') then
	writefile('catnext/profiles/commit.txt', 'main')
end

local function downloadFile(path, func)
	if not isfile(path) then
		local commit = 'main'
		if isfile('catnext/profiles/commit.txt') then
			commit = readfile('catnext/profiles/commit.txt')
		end
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/Catv67/'..commit..'/'..select(1, path:gsub('catnext/', '')), true)
		end)
		if not suc then
			error('Failed to download '..path..': '..tostring(res))
		end
		if res == '404: Not Found' or res == nil or res == '' then
			error('Failed to download '..path..': '..tostring(res))
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('catnext/main.lua'), 'main')(_scriptconfig)
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/amack7002-code/CatV6/'..readfile('catnext/profiles/commit.txt')..'/init.lua', true), 'init')(_scriptconfig)
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('":true', "=true"):gsub('{"', '{')
			teleportConfig = teleportConfig:gsub(',"', ','):gsub('":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_key', tostring(license.Key or '_key'))
			teleportScript = teleportScript:gsub('_scriptconfig', teleportConfig)
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if getgenv().catrole == 'HWID MISMATCH' then
			vape:CreateNotification('Cat', 'HWID MISMATCH, Go to the script panel to reset hwid', 25, 'alert')
			getgenv().catrole = ''
			task.wait(0.1)
		end
		if not shared.vapereload then
			vape:CreateNotification('Finished Loading', (getgenv().catname and ('Authenticated as '..tostring(getgenv().catname)..' with '..tostring(getgenv().catrole)..', ') or '').. (vape.VapeButton and 'Press the button in the top right' or ('Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI')), 5)
			task.delay(0.05 + cloneref(game:GetService('RunService')).PostSimulation:Wait(), function()
				if shared.updated then
					vape:CreateNotification('Cat', "Script has updated from "..tostring(shared.updated).." to "..tostring(readfile('catnext/profiles/commit.txt')), 10, 'info')
				end
			end)
		end	
	end
end


downloadFile('catnext/libraries/pathfind.lua')
if not isfile('catnext/profiles/gui.txt') then
	writefile('catnext/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('catnext/profiles/gui.txt')

if not isfolder('catnext/assets/'..gui) then
	makefolder('catnext/assets/'..gui)
end
if not isfile('catnext/profiles/commit.txt') then
	writefile('catnext/profiles/commit.txt', 'main')
end
downloadFile('catnext/libraries/pathfind.lua')

getgenv().used_init = true
vape = loadstring(downloadFile('catnext/guis/'..gui..'.lua'), 'gui')(license)
_G.vape = vape
if not isfile('catnext/profiles/gui.txt') then
	writefile('catnext/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('catnext/profiles/gui.txt')

if not isfolder('catnext/assets/'..gui) then
	makefolder('catnext/assets/'..gui)
end
vape = loadstring(downloadFile('catnext/guis/'..gui..'.lua'), 'gui')(license)

shared.vape = vape
_G.vape = vape
getgenv().used_init = true

if hookmetamethod then
	local old; old = hookmetamethod(game, '__namecall', function(self, Remote, ...)
		if not checkcaller() and getnamecallmethod() == 'FireServer' then
			if typeof(Remote) == "Instance" and Remote.Name == 'TabFreezeAnticheat_ClientToServerReport' then
				return
			end
		end
		return old(self, Remote, ...)
	end)
end

if shared.maincat then
	redirect()
	playersService.LocalPlayer:Kick('Your script is outdated, Get new one at discord.gg/catvape')
	return
end

if not shared.VapeIndependent then
	loadstring(downloadFile('catnext/games/universal.lua'), 'universal')(license)
	if isfile('catnext/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('catnext/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/amack7002-code/Catv67/'..readfile('catnext/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('catnext/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
			end
		end
	end
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	loadstring(downloadFile('catnext/libraries/premium.lua'), 'premium')(license)
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
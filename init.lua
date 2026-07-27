--!nocheck
local license = ... or {}
license.Key = script_key or license.Key

local cloneref = cloneref or function(ref) return ref end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

-- Utility: Log messages with error handling
local function log(msg)
	pcall(function()
		print("[Catv67 Loader] " .. tostring(msg))
	end)
end

-- Status UI for downloads
local downloader = Instance.new('TextLabel')
downloader.Size = UDim2.new(1, 0, 0, 40)
downloader.BackgroundTransparency = 1
downloader.TextStrokeTransparency = 0
downloader.TextSize = 20
downloader.TextColor3 = Color3.new(1, 1, 1)
downloader.Font = Enum.Font.Arial
downloader.Text = ''
downloader.Parent = Instance.new('ScreenGui', gethui and gethui() or cloneref(game:GetService('CoreGui')))

local function setStatus(text)
	if not license.Closet then
		downloader.Text = text
		log(text)
	end
end

-- Fetch the latest commit hash from GitHub API
local function getLatestCommit()
	local suc, res = pcall(function()
		local req = request({
			Url = 'https://api.github.com/repos/amack7002-code/Catv67/commits?per_page=1',
			Method = 'GET'
		})
		if req.StatusCode ~= 200 then
			log("Failed to fetch commits: HTTP " .. req.StatusCode)
			return nil
		end
		local body = cloneref(game:GetService('HttpService')):JSONDecode(req.Body)
		if body and typeof(body) == 'table' and #body > 0 then
			return body[1].sha
		end
		return nil
	end)
	
	if not suc then
		log("Error fetching latest commit: " .. tostring(res))
		return nil
	end
	return res
end

-- Download file from GitHub with error handling
local function downloadFile(path, func)
	if not isfile(path) then
		setStatus('Downloading ' .. path)
		
		local commitFile = 'catnextwrite/profiles/commit.txt'
		local commit = 'main'
		
		if isfile(commitFile) then
			commit = readfile(commitFile)
		end
		
		local url = 'https://raw.githubusercontent.com/amack7002-code/Catv67/' .. commit .. '/' .. select(1, path:gsub('catnextwrite/', ''))
		
		local suc, res = pcall(function()
			return game:HttpGet(url, true)
		end)
		
		if not suc then
			log("Network error downloading " .. path .. ": " .. tostring(res))
			error("Failed to download " .. path .. ": " .. tostring(res))
		end
		
		if res == '404: Not Found' then
			log("File not found: " .. url)
			error("File not found at " .. url)
		end
		
		-- Add watermark to Lua files for cache detection
		if path:find('.lua') then
			res = '--[[ Catv67 Cache Marker - Auto-generated ]]\n' .. res
		end
		
		pcall(function()
			writefile(path, res)
		end)
		
		setStatus('')
	end
	
	return (func or readfile)(path)
end

-- Recursively wipe folder contents (preserving init and profile files)
local function wipeFolder(path)
	if not isfolder(path) then return end
	
	local suc, files = pcall(function()
		return listfiles(path)
	end)
	
	if not suc then
		log("Could not list files in " .. path)
		return
	end
	
	for _, file in ipairs(files) do
		-- Skip protected files
		if file:find('init') or file:find('profile') then
			continue
		end
		
		local fileSuc, isFileResult = pcall(function()
			return isfile(file)
		end)
		
		if fileSuc and isFileResult then
			pcall(delfile, file)
		elseif pcall(function() return isfolder(file) end) then
			wipeFolder(file)
		end
	end
end

-- Ensure required folders exist
for _, folder in {'catnextwrite', 'catnextwrite/games', 'catnextwrite/profiles', 'catnextwrite/assets', 'catnextwrite/libraries', 'catnextwrite/guis'} do
	if not isfolder(folder) then
		setStatus('Creating folder: ' .. folder)
		pcall(makefolder, folder)
	end
end

-- Main initialization logic
if not shared.VapeDeveloper then
	-- Determine which commit to use
	local commit = license.Commit
	
	if not commit then
		setStatus('Fetching latest commit...')
		commit = getLatestCommit()
		
		if not commit then
			log("Could not fetch commit from API, falling back to 'main'")
			commit = 'main'
		else
			log("Latest commit: " .. commit)
		end
	end
	
	-- Check if we need to update
	local commitFile = 'catnextwrite/profiles/commit.txt'
	local previousCommit = isfile(commitFile) and readfile(commitFile) or nil
	
	if previousCommit and previousCommit ~= commit and commit ~= 'main' then
		log("Update detected: " .. (previousCommit or 'none') .. " -> " .. commit)
		shared.updated = previousCommit
		
		-- Wipe cached files on update
		wipeFolder('catnextwrite')
		wipeFolder('catnextwrite/games')
		wipeFolder('catnextwrite/guis')
		wipeFolder('catnextwrite/libraries')
	elseif not previousCommit then
		log("First run detected")
	end
	
	-- Save current commit
	pcall(function()
		writefile(commitFile, commit)
	end)
	
	-- Download profile files if missing
	if #listfiles('catnextwrite/profiles') < 4 then
		setStatus('Downloading profile files...')
		
		local reqSuc, req = pcall(function()
			return request({
				Url = 'https://api.github.com/repos/amack7002-code/Catv67/contents/profiles',
				Method = 'GET'
			})
		end)
		
		if reqSuc and req.StatusCode == 200 then
			local decodeSuc, body = pcall(function()
				return cloneref(game:GetService('HttpService')):JSONDecode(req.Body)
			end)
			
			if decodeSuc and body and typeof(body) == 'table' then
				for _, v in ipairs(body) do
					if v.type == 'file' then
						pcall(downloadFile, 'catnextwrite/' .. ({v.path:gsub(' ', '%%20')})[1])
					end
				end
			else
				log("Failed to decode profile API response")
			end
		else
			log("Failed to fetch profile files: HTTP " .. (req and req.StatusCode or "N/A"))
		end
	end
end

setStatus('')

-- Load and execute main script
local mainSuc, main = pcall(function()
	return downloadFile('catnextwrite/main.lua')
end)

if not mainSuc then
	log("CRITICAL: Failed to download main.lua: " .. tostring(main))
	error("Failed to load main.lua: " .. tostring(main))
end

local loadSuc, loadRes = pcall(function()
	return loadstring(main, 'main')(license)
end)

if not loadSuc then
	log("CRITICAL: Failed to execute main.lua: " .. tostring(loadRes))
	error("Failed to execute main.lua: " .. tostring(loadRes))
end

return loadRes

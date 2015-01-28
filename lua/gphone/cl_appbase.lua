----// Clientside Application Base //----

local client = LocalPlayer()

-- gApp is the gPhone's app base, it contains all the apps and related functions
gApp = {}

gApp["_children_"] = {} -- Contains all the panels of an app
gApp["_tickers_"] = {} -- Hook names of all added tickers
gApp["_active_"] = {} -- Active app's table

-- Backing up homescreen functions
local oldScreenPaint = nil
local oldScreenThink = nil
local oldScreenMousePressed = nil
local appLayout = nil

-- Prepares the phone to run an application
gApp["_init_"] = function()
	oldScreenPaint = gPhone.phoneScreen.Paint
	oldScreenThink = gPhone.phoneScreen.Think
	oldScreenMousePressed = gPhone.phoneScreen.OnMousePressed
	
	gPhone.homeIconLayout:SetVisible( false )
end

-- Removes application panels and restores the home screen
gApp["_close_"] = function( app )
	gPhone.phoneScreen.Paint = oldScreenPaint
	gPhone.phoneScreen.Think = oldScreenThink
	 gPhone.phoneScreen.OnMousePressed = oldScreenMousePressed
	
	if app and app.Data then
		if app.Data.Close then
			app.Data.Close()
		end
	end
	gApp.removeTicker( app )
	
	-- Hides all the app children
	for k, v in pairs( gApp["_children_"] ) do
		if type(v) == "table" then 
			for k, v in pairs(v) do 
				-- What if someone has 2 tables inside each other? Find a better way...
				v:Remove()
			end
		end
		
		if IsValid( v ) then
			v:Remove()
		end
	end
	
	gPhone.homeIconLayout:SetVisible( true )
	
	if gPhone.config.darkStatusBar == true then
		gPhone.darkenStatusBar()
	else
		gPhone.lightenStatusBar()
	end
	gPhone.showStatusBar()
	
	gPhone.setActiveApp( nil ) 
	
	net.Start("gPhone_DataTransfer")
		net.WriteTable({header=GPHONE_CUR_APP, app=nil})
	net.SendToServer()
end

--// Grabs all app files and runs them
function gPhone.importApps()
	gPhone.msgC( GPHONE_MSGC_NONE, "Importing applications..." )
	local files = file.Find( "gphone/apps/*.lua", "LUA" )
	
	if #files == 0 then
		error("gPhone was unable to load any apps!")
		return
	end
	
	for k, v in pairs(files) do
		include("gphone/apps/"..v)
	end
	gPhone.setActiveApp( nil ) 
end

--// Adds an application table to the phone
function gPhone.addApp( tbl )
	local name = string.lower(tbl.PrintName) or "error"
	
	gApp[name] = {
		["Data"] = tbl,
		["Start"] = function() -- A shortcut function to launch the app
			-- Call the 'APP.Run' function
			tbl.Run( gApp["_children_"], gPhone.phoneScreen )
			
			-- Override the phone's Paint and Think function
			gPhone.phoneScreen.Paint = tbl.Paint or function() end
			gPhone.phoneScreen.Think = tbl.Think or function() end
			
			-- Check if the app is a game and uses custom frame rate
			if tonumber(tbl.FPS) != nil and tonumber(tbl.FPS) != 0 then
				-- Detour the app's Think function to our ticker and kill the phone's Think function
				gApp.createTicker( tbl, tbl.FPS, tbl.Think )
				gPhone.phoneScreen.Think = function() end
			end
		end,
	}
	
	-- Don't add the app to the phone if we hide unusable apps
	if gPhone.config.ShowUnusableApps == false then
		if tbl.Gamemode and tbl.Gamemode != "" then
			if string.lower(tbl.Gamemode) != string.lower(engine.ActiveGamemode()) then
				gPhone.msgC( GPHONE_MSGC_WARNING, "Hiding unusable application: "..tbl.PrintName ) 
				return
			end
		end
	end
	
	-- Add the app to the homescreen table
	table.insert(gPhone.apps, {icon=tbl.Icon, name=tbl.PrintName})
end

--// Runs the app on the phone
function gPhone.runApp(name)
	local name = string.lower(name)
	
	if gApp[name] then
		gApp["_init_"]() -- Prepare the phone
		
		local app = gApp[name]
		
		-- Check if the app has a set run gamemode
		local appGM = app.Data.Gamemode
		if appGM != nil and appGM != "" then
			if string.lower(appGM) != string.lower(engine.ActiveGamemode()) then
				gPhone.denyApp( appGM, "This app cannot be used in this\r\n gamemode!" )
				return
			end
		end
		
		-- Check usergroup privelages (unsafe, I should do this on the server)
		local whitelist = app.AllowedUsergroups
		if whitelist != nil and #whitelist > 0 then
			local isWhitelisted = false
			
			for k, v in pairs(whitelist) do
				if client:GetUserGroup():lower() == v:lower() then
					isWhitelisted = true
				end
			end
			
			if not isWhitelisted then 
				gPhone.denyApp( appGM, "Your usergroup cannot use this app!" )
				return 
			end
		end
		
		-- Run a hook to see if there are any other conditions that need to be met
		local shouldRun = hook.Run( "gPhone_ShouldAppRun", name, gApp[name].Data )
		if shouldRun == false then
			gPhone.toHomeScreen()
			return 
		end
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_CUR_APP, app=app.Data.PrintName})
		net.SendToServer()
		
		-- All seems to be be good, run the application
		gPhone.setPhoneState( "app" )
		app.Start()
		gPhone.setActiveApp( app ) 
	else
		-- This only occurs when you save the config file while the phone is open
		error(string.format("App '%s' does not exist in the Application table, aborting", name))
		gPhone.toHomeScreen()
	end
end

--// Opens an app from another app
function gPhone.switchApps( newApp )
	gPhone.toHomeScreen()
	timer.Simple(0.3, function()
		gPhone.runApp( newApp )
	end)
end

--// Denies the user access to an app without breaking everything
function gPhone.denyApp( gmName, reason )
	gPhone.msgC( GPHONE_MSGC_WARNING, "You cannot use this application!" ) 
	-- Don't need to initialize the app base, its already been done
	gPhone.setPhoneState( "app" )
	gPhone.setActiveApp( {name=gmName} )
		
	local screen = gPhone.phoneScreen
	local objs = gApp["_children_"]
	local containerWidth = screen:GetWide()-20
	
	objs.Container = vgui.Create("DPanel", screen)
	objs.Container:SetSize( containerWidth, screen:GetTall()/3 )
	objs.Container:SetPos( 10, screen:GetTall()/2 - objs.Container:GetTall()/2 )
	objs.Container.Paint = function()
		draw.RoundedBox(0, 0, 0, objs.Container:GetWide(), objs.Container:GetTall(), Color(250, 250, 250))
	end
	
	local topError = vgui.Create( "DLabel", objs.Container ) -- Header
	topError:SetText( "[App Error]" )
	topError:SetTextColor(Color(0,0,0))
	topError:SetFont("gPhone_22")
	topError:SizeToContents()
	local width, height = gPhone.getTextSize("App Error", "gPhone_22")
	topError:SetPos( containerWidth/2 - width/2, 5 )
	
	local errorMsg = vgui.Create( "DLabel", objs.Container ) -- Actual message
	errorMsg:SetText( reason )
	errorMsg:SetTextColor(Color(0,0,0))
	errorMsg:SetFont("gPhone_14")
	errorMsg:SizeToContents()
	local width, height = gPhone.getTextSize(reason, "gPhone_14")
	errorMsg:SetPos( containerWidth/2 - width/2, 30 )
end

--// Calls an app's function X times per second in order to simulate a constant framerate. 
local fpsReturn = 0
function gApp.createTicker( app, fps, func )
	gPhone.msgC( GPHONE_MSGC_NONE, "Creating ticker for "..app.PrintName.." to run at "..fps.." ticks per second" )
	
	local appName = app.PrintName:lower() or "error"
	
	local tickRate = 1/fps
	local nextTick = CurTime() + tickRate
	local frameCount = 0
	local startTime = CurTime()
	local endTime = CurTime() + 1
	
	hook.Add("Think", "gPhone_AppTicker_"..appName, function()
		-- Call the next tick
		if CurTime() > nextTick then
			frameCount = frameCount + 1
			--nextTick = CurTime() + (tickRate - RealFrameTime())
			nextTick = CurTime() + tickRate - (RealFrameTime()/2)
			
			func()
		end
		
		-- Its been a second
		if CurTime() >= endTime then
			startTime = CurTime()
			endTime = CurTime() + 1
			
			frameCount = 0
		end
		
		fpsReturn = frameCount / (CurTime() - startTime)
	end)

	gApp["_tickers_"][appName] = "gPhone_AppTicker_"..appName
end

--// Removes an app's ticker 
function gApp.removeTicker( app )
	if not app or not app.Data then return end
	
	local appName = app.Data.PrintName:lower() or "error"
	
	if gApp["_tickers_"][appName] then
		gPhone.msgC( GPHONE_MSGC_NONE, "Removing ticker for "..app.Data.PrintName)
		local hookName = gApp["_tickers_"][appName] 
		
		hook.Remove("Think", hookName)
		fpsReturn = 0
	end
end

--// Removes all tickers in the table
function gApp.removeTickers()
	for name, hookName in pairs( gApp["_tickers_"] ) do
		hook.Remove("Think", hookName)
	end
end

--// Returns a psuedo-framerate of the current app
function gApp.getFPS()
	return math.Round(fpsReturn, 6)
end

--// Returns an average frame rate
function gApp.getFPSAverage()
	local fps = tonumber(fpsReturn) or 0
	
	local nextUpdate = 0
	hook.Add("Think", "gPhone_AppFPSSmooth", function()
		if CurTime() > nextUpdate then
			--nextUpdate = CurTime() + 0.5
		end
	end)
end








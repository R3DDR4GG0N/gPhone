----// Clientside Phone //----

local client = LocalPlayer()
local phone = Material( "vgui/gphone/gphone.png" )
local firstTimeUsed = CreateClientConVar("gphone_firsttime", "1", true, true)	

--// Builds the phone 
function gPhone.BuildPhone()
	gPhone.LoadClientConfig()

	gPhone.Apps = {}
	gPhone.ImportApps()
	gPhone.SettingsTabs = {
		"General",
		"Wallpaper",
		"_SPACE_", -- Moves the next entry down one button height (not an actual tab)
		"Text",
		"Phone",
		"Contacts",
	}
	
	-- Dimensions
	local pWidth, pHeight = 300, 600 -- Phone
	local sWidth, sHeight = 234, 416 -- Screen
	local hWidth, hHeight = 45, 45 -- Home button
	
	gPhone.IsPortrait = true
	gPhone.Rotation = 0
	gPhone.IsInAnimation = false
	gPhone.ShouldUnlock = true
	
	-- Create the phone 
		gPhone.phoneBase = vgui.Create( "DFrame" )
	gPhone.phoneBase:SetSize( pWidth, pHeight )
	gPhone.phoneBase:SetPos( ScrW()-pWidth, ScrH() - 40 )
	gPhone.phoneBase:SetTitle( "" )
	gPhone.phoneBase:SetDraggable( true )  -- TEMPORARY
	gPhone.phoneBase:SetDeleteOnClose( true )
	gPhone.phoneBase:ShowCloseButton( true ) -- TEMPORARY
	gPhone.phoneBase.Paint = function( self, w, h)
		surface.SetDrawColor( gPhone.Config.PhoneColor )
		surface.SetMaterial( phone ) 
		--surface.DrawTexturedRect( 0, 0, pWidth, pHeight )
		surface.DrawTexturedRectRotated( self:GetWide()/2, self:GetTall()/2, pWidth, pHeight, gPhone.Rotation )
	end
	gPhone.phoneBase.btnClose.DoClick = function ( button ) -- TEMPORARY
		gPhone.DestroyPhone()
	end
	
	local phoneBase = gPhone.phoneBase
	local pX, pY = phoneBase:GetPos()
	gPhone.SetWallpaper( true, gPhone.Config.HomeWallpaper )
	gPhone.SetWallpaper( false, gPhone.Config.LockWallpaper )
	
		gPhone.phoneScreen = vgui.Create("DPanel", gPhone.phoneBase)
	gPhone.phoneScreen:SetPos( 31, 87 )
	gPhone.phoneScreen:SetSize( sWidth, sHeight ) 
	gPhone.phoneScreen.Paint = function( self )
		surface.SetMaterial( gPhone.GetWallpaper( true, true ) )  -- Draw the wallpaper
		surface.SetDrawColor(255,255,255)
		surface.DrawTexturedRect(0, 0, self:GetWide(), self:GetTall())
	end
	gPhone.phoneScreen.Think = function()
		if gPhone.Config.DarkenStatusBar == true then
			gPhone.DarkenStatusBar()
		end
	end
	
	local nextTimeUpdate = 0
	local phoneTime = vgui.Create( "DLabel", gPhone.phoneScreen )
	phoneTime:SetText( os.date("%I:%M %p") )
	phoneTime:SizeToContents()
	phoneTime:SetPos( sWidth/2 - phoneTime:GetWide()/2, 0 )
	phoneTime.Think = function()
		if CurTime() > nextTimeUpdate then
			phoneTime:SetText(os.date("%I:%M %p"))
			phoneTime:SizeToContents()
			phoneTime:SetPos( sWidth/2 - phoneTime:GetWide()/2, 0 )
			nextTimeUpdate = CurTime() + 5
		end
	end
	
	--// Status bar
	local batteryPercent = vgui.Create( "DLabel", gPhone.phoneScreen )
	batteryPercent:SetText( "100%" )
	batteryPercent:SizeToContents()
	batteryPercent:SetPos( sWidth - batteryPercent:GetWide() - 23, 0 )
	local nextPass, battPerc = CurTime() + math.random(30, 60), 100
	batteryPercent.Think = function()
		if CurTime() > nextPass then
			batteryPercent:SetPos( sWidth - batteryPercent:GetWide() - 21, 0)
			local dropPerc = math.random(1, 3)

			battPerc = battPerc - dropPerc
			batteryPercent:SetText( battPerc.."%" )
			batteryPercent:SetPos( sWidth - batteryPercent:GetWide() - 20, 0 )
			
			nextPass = CurTime() + math.random(60, 180)
		end
		
		if battPerc < math.random(1, 4) then -- Simulate a phone dying, its kinda silly and few people will ever see it
			gPhone.ChatMsg( "Your phone has run out of battery and died! Recharging..." )
			gPhone.HidePhone()
			timer.Simple(math.random(2, 5), function()
				gPhone.ChatMsg( "Phone recharged!" )
				gPhone.ShowPhone()
				battPerc = 100
			end)
		end
	end
	
	local batteryImage = vgui.Create("DImage", gPhone.phoneScreen)
	batteryImage:SetSize( 16, 8 )
	batteryImage:SetPos( sWidth - 20, 3)
	batteryImage:SetImageColor(Color(255,255,255))
	local batteryMat = Material( "vgui/gphone/battery.png" )
	batteryImage.Paint = function( self )
		-- Draw the battery icon
		surface.SetMaterial( batteryMat ) 
		surface.SetDrawColor( batteryImage:GetImageColor() )
		surface.DrawTexturedRect(0, 0, self:GetWide(), self:GetTall())
		
		-- Math to determine the size of the battery bar
		local segments = 11 / 100
		local batterySize = math.Clamp(battPerc * segments, 1, 11)
		
		-- Battery bar color
		if battPerc <= 20 then
			col = Color(200, 30, 30) 
		else
			col = batteryImage:GetImageColor() 
		end
		
		-- Draw the battery bar
		draw.RoundedBox( 0, 2, 2, batterySize, 4, col )
	end
	
	local serviceProvider = vgui.Create( "DLabel", gPhone.phoneScreen )
	serviceProvider:SetText( "Garry" )
	serviceProvider:SizeToContents()
	serviceProvider:SetPos( 5, 0 )
	
	gPhone.homeButton = vgui.Create( "DButton", gPhone.phoneBase )
	gPhone.homeButton:SetSize( hWidth, hHeight )
	gPhone.homeButton:SetPos( pWidth/2 - hWidth/2 - 3, pHeight - hHeight - 35 )
	gPhone.homeButton:SetText( "" )
	gPhone.homeButton.Paint = function() end
	gPhone.homeButton.DoClick = function()
		if gPhone.IsOnHomeScreen != true and gPhone.IsInAnimation != true then
			gPhone.ToHomeScreen()
		end
	end
	
	gPhone.StatusBar = { -- Gotta keep track of all the status bar elements
		["text"] = { battery=batteryPercent, network=serviceProvider, time=phoneTime },
		["image"] = { battery=batteryImage },
	}
	gPhone.StatusBarHeight = 15
	
	--// Homescreen
	local homeIcons = {}
	
	-- Loads up icon positions from the oosition file
	local txtPositions = gPhone.GetAppPositions()
	local newApps = {}
	local denies = 0
	if #txtPositions > 1 then
		for a = 1,#gPhone.Apps do
			local app = gPhone.Apps[a] -- name and icon
			local name = app.name
			denies = 0
			
			-- Checks if an app exists in the config file and at which key
			for i = 1,#txtPositions do
				if name == txtPositions[i].name then
					if app.icon == txtPositions[i].icon then -- Config icon matches app's set icon path
						newApps[i] = txtPositions[i]
					else -- Use the app's icon path anyways
						newApps[i] = txtPositions[i]
						newApps[i].icon = app.icon
					end
				else
					denies = denies + 1
				end
			end
			
			-- This app does not exist in the config, put it at the end
			if denies == #txtPositions then
				table.insert(newApps, app)
			end
		end
		
		gPhone.Apps = newApps
	end
	
	-- Build the layout
	gPhone.HomeIconLayout = vgui.Create( "DPanel", gPhone.phoneScreen )
	gPhone.HomeIconLayout:SetSize( sWidth - 10, sHeight - 40 )
	gPhone.HomeIconLayout:SetPos( 5, 25 )
	gPhone.HomeIconLayout.Paint = function() end
	gPhone.CanMoveApps = true
	gPhone.IsInFolder = false
	
	-- Handles the dropping of icons on the home screen
	gPhone.HomeIconLayout:Receiver( "gPhoneIcon", function( pnl, item, drop, i, x, y ) 
		if drop then
			--[[
				// Issues //
			Cant drag icons out of folders
			Cant move icons inside folders
			Folders sometimes throw lua errors due to being in the homeIcons table strangely
			*gPhone.IsInFolder
			]]
			
			for k, v in pairs(homeIcons) do
				local iX, iY = v.pnl:GetPos()
				local iW, iH = v.pnl:GetSize()
				
				if x >= iX + iW/3 and x <= iX + iW - iW/3 then
					if y >= iY and y <= iY + iH then	
						-- Create a folder
						gPhone.CanMoveApps = false
						local droppedData = {name="Folder", apps={}}
						local droppedKey = 0
						
						-- Get the name and image of the icon we are moving
						for i = 1,#homeIcons do
							if item[1] == homeIcons[i].pnl:GetChildren()[1] then
								if gPhone.Apps[k].apps then return end -- Dont drop folders on anything
								local droppedName = homeIcons[i].name
								
								for i = 1, #gPhone.Apps do
									if gPhone.Apps[i].name == droppedName then
										droppedKey = i
									end
								end
							end
						end
						
						if gPhone.Apps[k] == gPhone.Apps[droppedKey] then return end

						if gPhone.Apps[k].apps != nil then -- Dropped on a folder
							table.insert(gPhone.Apps[k].apps, {name=gPhone.Apps[droppedKey].name, icon=gPhone.Apps[droppedKey].icon})
							table.remove(gPhone.Apps, droppedKey)
						else
							-- Put the 2 icons into the folder
							table.insert(droppedData.apps, {name=gPhone.Apps[k].name, icon=gPhone.Apps[k].icon})
							table.insert(droppedData.apps, {name=gPhone.Apps[droppedKey].name, icon=gPhone.Apps[droppedKey].icon})
							
							-- Remove the moved icon and the dropped-on icon, create a folder
							table.remove(gPhone.Apps, droppedKey)
							table.remove(gPhone.Apps, k)
							table.insert(gPhone.Apps, k, droppedData)
						end
						
						-- Build a shiny new homescreen
						gPhone.BuildHomescreen( gPhone.Apps )
						gPhone.CanMoveApps = true
					end
				elseif dragndrop.GetDroppable() != nil and gPhone.CanMoveApps then
					-- We are not dropping in the folder area, move the apps instead
					local prevX, prevY 

					local x, y = v.pnl:GetPos()
					local w, h = v.pnl:GetSize()
					local heldPanel = dragndrop.GetDroppable()[1]
					local shouldMove = false
					-- GetDroppable doesnt return a true pos, this works just as well
					local mX, mY = gPhone.HomeIconLayout:ScreenToLocal( gui.MouseX(), gui.MouseY() )
					if x != 0 and homeIcons[k-1] != nil then
						prevX, prevY = homeIcons[k-1].pnl:GetPos()
						prevH, prevW = homeIcons[k-1].pnl:GetSize()		
					
						-- Check if the mouse is in the droppable area (between panels)
						if mX <= x + w/3 and mX >= prevX + (prevH/3 *2) then -- Increase the drop area by 33% on each side
							if mY >= y and mY <= y + h then
								shouldMove = true
							end
						end
					else
						if mX <= x + w/3 then 
							if mY >= y and mY <= y + h then
								shouldMove = true
							end
						end
					end
					
					if shouldMove then
						local droppedData = {name="N/A", icon="N/A"}
						local droppedKey = 0
						
						-- Get the name and image of the icon we are moving
						for i = 1,#homeIcons do
							if heldPanel == homeIcons[i].pnl:GetChildren()[1] then
								local droppedName = homeIcons[i].name
								
								for i = 1, #gPhone.Apps do
									if gPhone.Apps[i].name == droppedName then
										droppedData = gPhone.Apps[i]
										droppedKey = i
									end
								end
							end
						end
						
						-- Drop the panel
						dragndrop.StopDragging()
						
						-- Remove the icon from its old key and move it to its new key
						table.remove(gPhone.Apps, droppedKey)
						table.insert(gPhone.Apps, k, droppedData )
						
						-- Build a shiny new homescreen
						gPhone.BuildHomescreen( gPhone.Apps )
					end
				end
			end
		end
	end, {})
	
	-- Populate the homescreen with apps
	function gPhone.BuildHomescreen( tbl )
		-- Destroy the old homescreen 
		for k, v in pairs( gPhone.HomeIconLayout:GetChildren() ) do
			v:Remove()
		end
		homeIcons = {}
						
		local xBuffer, yBuffer, iconCount = 0, 0, 1
		for key, data in pairs( tbl ) do
			local bgPanel
			if data.icon then
				-- Create a normal app icon
				bgPanel = vgui.Create( "DPanel", gPhone.HomeIconLayout )
				bgPanel:SetSize( 50, 45 )
				bgPanel:SetPos( 0 + xBuffer, 10 + yBuffer )
				bgPanel.Paint = function( self, w, h )
					--draw.RoundedBox(0, 0, 0, w, h, Color(255,0,0) )
				end
				
				local imagePanel = vgui.Create( "DImageButton", bgPanel ) 
				imagePanel:SetSize( 32, 32 )
				imagePanel:SetPos( 10, 0 )
				imagePanel:SetImage( data.icon )
				imagePanel:Droppable( "gPhoneIcon" )
				imagePanel.DoClick = function()
					gPhone.RunApp( string.lower(data.name) )
				end
				
				local iconLabel = vgui.Create( "DLabel", bgPanel )
				iconLabel:SetText( data.name )
				iconLabel:SetFont("gPhone_12")
				iconLabel:SizeToContents()
				iconLabel:SetPos( bgPanel:GetWide()/2 - iconLabel:GetWide()/2, imagePanel:GetTall() + 2)
			else 
				-- The fun part, create a folder
				local folderLabel, folderName, nameEditor 
				bgPanel = vgui.Create( "DPanel", gPhone.HomeIconLayout )
				bgPanel:SetSize( 50, 45 )
				bgPanel:SetPos( 0 + xBuffer, 10 + yBuffer )
				bgPanel.Paint = function( self, w, h )
					if IsValid(nameEditor) and nameEditor:IsEditing() then
						local w, h = folderName:GetSize()
						local x, y = folderName:GetPos()
						draw.RoundedBox(4, 0, y - 5, bgPanel:GetWide(), h + 10, Color(50, 50, 50, 150) )
					end
				end
				
				local previewPanel = vgui.Create( "DImageButton", bgPanel ) 
				previewPanel:SetSize( 32, 32 )
				previewPanel:SetPos( 10, 0 )
				previewPanel:Droppable( "gPhoneIcon" )
				previewPanel.Paint = function( self, w, h )
					draw.RoundedBox(4, 0, 0, w, h, Color(255, 0, 0, 255) )
					
					draw.DrawText( #tbl[key].apps, "gPhone_18", 10, 10, color_white )
					-- Draw icons of the other apps inside the folder
				end
				
				local iconLabel = vgui.Create( "DLabel", bgPanel )
				iconLabel:SetText( data.name )
				iconLabel:SetFont("gPhone_12")
				iconLabel:SizeToContents()
				if iconLabel:GetWide() <= bgPanel:GetWide() then
					iconLabel:SetPos( bgPanel:GetWide()/2 - iconLabel:GetWide()/2, previewPanel:GetTall() + 2)
				else
					iconLabel:SetPos( 0, previewPanel:GetTall() + 2)
				end
				
				local x, y = previewPanel:GetPos()
				local w, h = previewPanel:GetSize()
				local oldBGPos = {bgPanel:GetPos()}
				local oldBGSize = {bgPanel:GetSize()}
				
				-- Declared early because I am terrible at managing this
				local function closeFolder() 
					nameEditor:OnEnter()
					
					previewPanel:SetCursor( "hand" )
					bgPanel:SetPos( unpack(oldBGPos) )
					bgPanel:SetSize( unpack(oldBGSize) )
					
					nameEditor:SetVisible(false)
					folderName:SetVisible(false)
					
					previewPanel:SizeTo( w, h, 0.5)
					timer.Simple(0.5, function()
						if IsValid(bgPanel) then
							--bgPanel:Remove()
						end
					end)
					
					gPhone.IsInFolder = false
					gPhone.BuildHomescreen( gPhone.Apps )
				end
				
				-- Handle the building of folders
				previewPanel.DoClick = function( self )
					gPhone.IsInFolder = true
					previewPanel:SetCursor( "arrow" )
						
					-- Hide the other apps
					for k, v in pairs( gPhone.HomeIconLayout:GetChildren() ) do
						if v != bgPanel then
							v:SetVisible(false)
						end
					end
					
					bgPanel.OnMousePressed = function()
						if IsValid(previewPanel) and IsValid(folderName) then
							closeFolder()
						end
					end
					
					iconLabel:SetVisible(false)
					bgPanel:SetPos( 0, 0 )
					bgPanel:SetSize( gPhone.HomeIconLayout:GetWide(),  gPhone.HomeIconLayout:GetTall() )
					
					local w, h = gPhone.HomeIconLayout:GetWide(), gPhone.HomeIconLayout:GetTall()/1.7
					self:SizeTo( w, h, 0.5)
					self:MoveTo( 0, gPhone.HomeIconLayout:GetTall()/2 - h/2, 0.5)
					
					folderName = vgui.Create( "DLabel", bgPanel )
					folderName:SetText( data.name )
					folderName:SetFont("gPhone_40")
					folderName:SizeToContents()
					folderName:SetPos( bgPanel:GetWide()/2 - folderName:GetWide()/2, 15)
					local strTable = {}
					local nextFlash = 0
					folderName.Paint = function( self, w , h )
						-- Create a flashing fake carret on the Label
						
						if CurTime() > nextFlash and IsValid(nameEditor) then
							-- Put all the of letters into a table
							for i = 1, string.len(self:GetText()) do
								strTable[i] = self:GetText()[i]
							end
							
							-- Get the size from the 
							local x = 0
							for i = 1, nameEditor:GetCaretPos() do
								x = x + gPhone.GetTextSize( strTable[i], self:GetFont() )
							end
							
							draw.RoundedBox(0, x, 5, 2, h - 10, Color(255, 255, 255, 255) )
							
							timer.Simple(0.5, function()
								nextFlash = CurTime() + 0.1
							end)
						end
					end
						
					nameEditor = vgui.Create( "DTextEntry", bgPanel )
					nameEditor:SetText( data.name )
					nameEditor:SetFont( "gPhone_36" )
					nameEditor:SizeToContents()
					nameEditor.Paint = function() end
					nameEditor.Think = function()
						-- Size and position the editor on top of the label
						local x, y = folderName:GetPos()
						nameEditor:SetPos( x, y )
						nameEditor:SetSize(folderName:GetSize())
						
						if self.Opened == false then
							nameEditor:Remove()
						end
						
						if folderName:GetWide() <= bgPanel:GetWide() then
							folderName:SizeToContents()
							local w, h = folderName:GetSize()
							folderName:SetSize( w + 10, h )
						end
						
						if IsValid( nameEditor.Menu ) then
							nameEditor.Menu:Remove()
						end
					end
					nameEditor.OnChange = function()
						-- Position the label based on the text
						folderName:SetText( nameEditor:GetText() or data.name )
						if folderName:GetWide() <= bgPanel:GetWide() then
							folderName:SizeToContents()
							local w, h = folderName:GetSize()
							folderName:SetSize( w + 10, h )
						end
						folderName:SetPos( bgPanel:GetWide()/2 - folderName:GetWide()/2, 15 )
					end
					nameEditor.OnEnter = function()
						-- Set the name of the folder based on the text
						local text = folderName:GetText()
						if text == "" then
							folderName:SetText("Folder")
							folderName:SizeToContents()
							
							local w, h = folderName:GetSize()
							folderName:SetSize( w + 10, h )
							folderName:SetPos( bgPanel:GetWide()/2 - folderName:GetWide()/2, 15 )
							nameEditor:SetPos( bgPanel:GetWide()/2 - folderName:GetWide()/2, 55 )
							return
						end
						data.name = folderName:GetText()
					end
					
					-- Create the folder's app icons
					local xBuffer, yBuffer = 0,0
					local folderIconCount = 0
					for k, v in pairs( tbl[key].apps ) do
						-- Create a normal app icon
						local bgPanel = vgui.Create( "DPanel", previewPanel )
						bgPanel:SetSize( 50, 45 )
						bgPanel:SetPos( 0 + xBuffer, 10 + yBuffer )
						bgPanel.Paint = function( self, w, h )
						end
						
						local imagePanel = vgui.Create( "DImageButton", bgPanel ) 
						imagePanel:SetSize( 32, 32 )
						imagePanel:SetPos( 10, 0 )
						imagePanel:SetImage( v.icon )
						imagePanel:Droppable( "gPhoneIcon" )
						imagePanel.DoClick = function()
							gPhone.RunApp( string.lower(v.name) )
						end
						
						local iconLabel = vgui.Create( "DLabel", bgPanel )
						iconLabel:SetText( v.name )
						iconLabel:SetFont("gPhone_12")
						iconLabel:SizeToContents()
						iconLabel:SetPos( bgPanel:GetWide()/2 - iconLabel:GetWide()/2, imagePanel:GetTall() + 2)
						
						local folderLabel = vgui.Create( "DLabel", bgPanel )
						folderLabel:SetText( v.name )
						folderLabel:SetFont("gPhone_12")
						folderLabel:SizeToContents()
						folderLabel:SetPos( bgPanel:GetWide()/2 - folderLabel:GetWide()/2, 34)
						
						if folderIconCount % 4 == 0 then
							xBuffer = 0
							yBuffer = yBuffer + 75
						else
							xBuffer = xBuffer + 55
							yBuffer = yBuffer
						end
						folderIconCount = folderIconCount+ 1
					end
				end
			end
		
			if iconCount % 4 == 0 then
				xBuffer = 0
				yBuffer = yBuffer + 75
			else
				xBuffer = xBuffer + 55
				yBuffer = yBuffer
			end
			
			iconCount = iconCount + 1
			table.insert(homeIcons, {name=data.name, pnl=bgPanel })
		end
		
		-- Save the app positions
		--gPhone.SetAppPositions( gPhone.Apps ) -- TEMP FOR TESTING
	end
	gPhone.BuildHomescreen( gPhone.Apps )
	
	-- Assorted stuff
	gPhone.PhoneExists = true
	gPhone.Config.PhoneColor.a = 100
	
	-- Check cache
	local files = file.Find( "gphone/cache/*.txt", "DATA" )
	if #files > 0 then
		local tbl = {}
		for k, name in pairs(files) do
			local body = file.Read( "gphone/cache/"..name, "DATA" )
			-- Only need the important stuff here
			local title = string.gsub(name, ".txt", "")
			title = string.gsub(title, "app_", "")
			
			table.insert(tbl, {name=title, body=body})
		end
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_F_EXISTS, data=tbl})
		net.SendToServer()
	end
end

--// Moves the phone up into visiblity
function gPhone.ShowPhone()
	if gPhone and gPhone.phoneBase then
		local pWidth, pHeight = gPhone.phoneBase:GetSize()
		gPhone.phoneBase:MoveTo( ScrW()-pWidth, ScrH()-pHeight, 0.7, 0, 2, function()
			gPhone.phoneBase:MakePopup()
		end)
		
		gPhone.Config.PhoneColor.a = 255
		
		if firstTimeUsed:GetBool() then
			gPhone.BootUp()
			LocalPlayer():ConCommand("gphone_firsttime 0")
		end
		
		gPhone.BuildLockScreen()
		
		gPhone.IsOnHomeScreen = true
		gPhone.PhoneActive = true
		
		-- Tell the server we are done and the phone is ready to be used
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_STATE_CHANGED, open=true})
		net.SendToServer()
	end
end

--// Moves the phone down and disables it
function gPhone.HidePhone()
	if gPhone and gPhone.phoneBase then
		local x, y = gPhone.phoneBase:GetPos()
		
		gPhone.phoneBase:SetMouseInputEnabled( false )
		gPhone.phoneBase:SetKeyboardInputEnabled( false )
		
		gPhone.phoneBase:MoveTo( x, ScrH()-40, 0.7, 0, 2, function()
			gPhone.Config.PhoneColor.a = 100 -- Fade the alpha
		end)
		
		gPhone.PhoneActive = false
		
		gApp.RemoveTickers()
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_STATE_CHANGED, open=false})
		net.SendToServer()
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_CUR_APP, app=nil})
		net.SendToServer()
	end
end

--// Completely removes the phone from the game
function gPhone.DestroyPhone()
	if gPhone and gPhone.phoneBase then
		gPhone.phoneBase:Close()
		gPhone.phoneBase = nil
		
		gPhone.PhoneActive = false
		gPhone.PhoneExists = false
		
		gApp.RemoveTickers()
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_STATE_CHANGED, open=false})
		net.SendToServer()
		
		net.Start("gPhone_DataTransfer")
			net.WriteTable({header=GPHONE_CUR_APP, app=nil})
		net.SendToServer()
	end
end

--// Receives a Server-side net message
net.Receive( "gPhone_DataTransfer", function( len, ply )
	local data = net.ReadTable()
	local header = data.header
	
	if header == GPHONE_BUILD then
		gPhone.BuildPhone()
	elseif header == GPHONE_NOTIFY_GAME then
		local sender = data.sender
		local game = data.text
		
		local msg = sender:Nick().." has invited you to play "..game
		
		if not gPhone.PhoneActive then
			gPhone.Vibrate()
			gPhone.Notification( msg, {game=game} )
		else
			gPhone.Notification( msg, {game=game} )
		end
	elseif header == GPHONE_RETURNAPP then
		local name, active = nil, gApp["_active_"]
		active = active or {}
		active.Data = active.Data or {}
		
		if active.Data.PrintName then
			name = active.Data.PrintName or nil
		end

		net.Start("gPhone_DataTransfer")
			net.WriteTable( {header=GPHONE_RETURNAPP, app=name} )
		net.SendToServer()
	elseif header == GPHONE_RUN_APPFUNC then
		local app = data.app
		local func = data.func
		local args = data.args
		
		if gApp[app:lower()] then
			app = app:lower()
			for k, v in pairs( gApp[app].Data ) do
				if k:lower() == func:lower() then
					gApp[app].Data[k]( unpack(args) )
					return
				end
			end
		end
		gPhone.MsgC( GPHONE_MSGC_WARNING, "Unable to run application function "..func.."!" )
	elseif header == GPHONE_RUN_FUNC then
		local func = data.func
		local args = data.args
		
		for k, v in pairs(gPhone) do
			if k:lower() == func:lower() and type(k) == "function" then
				gPhone[k]( unpack(args) )
				return
			end
		end
		
		gPhone.MsgC( GPHONE_MSGC_WARNING, "Unable to run phone function "..func.."!")
	elseif header == GPHONE_MONEY_CONFIRMED then
		local writeTable = {}
		data.header = nil
		data = data[1]
		
		--[[
			Problemo:
		On Client - ALL transactions for any server will show up
		On Server - Server gets flooded with tons of .txt documents that might only contain 1 transaction
		
		No limit on logs
		]]
		
		if file.Exists( "gphone/transaction_log.txt", "DATA" ) then
			local readFile = file.Read( "gphone/transaction_log.txt", "DATA" )
			print("File exists", readFile)
			local readTable = util.JSONToTable( readFile ) 
			
			--table.Add( tbl, readTable )/
			writeTable = readTable
			
			--local key = #writeTable+1
			table.insert( writeTable, 1, {amount=data.amount, target=data.target, time=data.time} )
			--writeTable[key] = {amount=data.amount, target=data.target, time=data.time}
			gPhone.MsgC( GPHONE_MSGC_NONE, "Appending new transaction log into table")
		else
			gPhone.MsgC( GPHONE_MSGC_WARNING, "No transaction file, creating one...")
			writeTable[1] = {amount=data.amount, target=data.target, time=data.time}
			PrintTable(writeTable)
		end
		
		local json = util.TableToJSON( writeTable )
	
		file.CreateDir( "gphone" )
		file.Write( "gphone/transaction_log.txt", json)
	elseif header == GPHONE_TEXT_MSG then
		gPhone.ReceiveTextMessage( data.data )
	end
end)

--// Logic for opening the phone by holding down a key
local keyStartTime = 0
hook.Add( "Think", "gPhone_OpenAndCloseKey", function()
	if input.IsKeyDown( gPhone.Config.OpenKey ) then
		if keyStartTime == 0 then
			keyStartTime = CurTime()
		end
		
		if CurTime() - keyStartTime >= gPhone.Config.KeyHoldTime and not gPhone.IsInAnimation then
			if gPhone.PhoneActive != true then
				gPhone.ShowPhone()
			else
				gPhone.HidePhone()
			end
			
			keyStartTime = 0
		end
	else
		keyStartTime = 0
	end
end)

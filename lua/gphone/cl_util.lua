----// Clientside Utility Functions //----

local client = LocalPlayer()

--// Console commands
concommand.Add("gphone_build", function()
	gPhone.buildPhone()
end)

concommand.Add("gphone_destroy", function()
	gPhone.destroyPhone()
end)

concommand.Add("gphone_version", function()
	gPhone.msgC( GPHONE_MSGC_NOTIFY, "This server is running the Garry Phone version: "..gPhone.version )
end)

-- TEMPORARY

concommand.Add("text", function()
	gPhone.sendTextMessage( "Exho", "Test message from console command" ) 
end)

concommand.Add("notify_p", function()
	gPhone.notifyPassive( {msg="Test message that should be long and word wrappable telling you to launch an app", app="settings"} )
end)

concommand.Add("notify_i", function()
	gPhone.notifyInteract( {msg="Test message that should be long and word wrappable telling you to launch an app",
	app="settings", options={"Accept", "Deny"}} )
end)

-- END TEMPORARY

--// Chat messages
function gPhone.chatMsg( text )
	chat.AddText(
		Color(17, 148, 240), "[gPhone]", 
		Color(255,255,255), ": "..text
	)
end
 
net.Receive( "gPhone_ChatMsg", function( len, ply )
	gPhone.chatMsg( net.ReadString() )
end)

--// Panel-based blur function kindly given by Netheous (STEAM_0:0:19766778)
local blur = Material( "pp/blurscreen" )
function gPhone.drawPanelBlur( panel, layers, density, alpha )
	local x, y = panel:LocalToScreen(0, 0)

	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.SetMaterial( blur )

	for i = 1, 3 do
		blur:SetFloat( "$blur", ( i / layers ) * density )
		blur:Recompute()

		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
	end
end

--// Hide or show children of a panel
function gPhone.hideChildren( pnl )
	if not IsValid( pnl ) then return end
	
	for k, v in pairs( pnl:GetChildren() ) do
		if IsValid(v) then
			v:SetVisible(false)
		end
	end
end

function gPhone.showChildren( pnl )
	if not IsValid( pnl ) then return end
	
	for k, v in pairs( pnl:GetChildren() ) do
		if IsValid(v) then
			v:SetVisible(true)
		end
	end
end

function gPhone.hideAppObjects()
	if not IsValid( pnl ) then return end
	
	for k, v in pairs( gApp["_children_"] ) do
		if IsValid(v) then
			v:SetVisible( false )
		end
	end
end

--// Color the status bar
function gPhone.darkenStatusBar()
	for class, tab in pairs(gPhone.StatusBar) do
		if class == "text" then
			for k, pnl in pairs(tab) do
				if not IsValid(pnl) then return end
				pnl:SetTextColor(Color(0,0,0))
			end
		else
			for k, pnl in pairs(tab) do
				if not IsValid(pnl) then return end
				pnl:SetImageColor(Color(0,0,0))
			end
		end
	end
end

function gPhone.lightenStatusBar() 
	for class, tab in pairs(gPhone.StatusBar) do
		if class == "text" then
			for k, pnl in pairs(tab) do
				if not IsValid(pnl) then return end
				pnl:SetTextColor(Color(255,255,255))
			end
		else
			for k, pnl in pairs(tab) do
				if not IsValid(pnl) then return end
				pnl:SetImageColor(Color(255,255,255))
			end
		end
	end
end

--// Show or hide the entire status bar or portions
function gPhone.showStatusBar()
	for class, tab in pairs(gPhone.StatusBar) do
		for k, pnl in pairs(tab) do
			pnl:SetVisible(true)
		end
	end
end

function gPhone.showStatusBarElement( name )
	for class, tab in pairs(gPhone.StatusBar) do
		if tab[string.lower(name)] then
			tab[string.lower(name)]:SetVisible(true)
		end
	end
end

function gPhone.hideStatusBar()
	for class, tab in pairs(gPhone.StatusBar) do
		for k, pnl in pairs(tab) do
			pnl:SetVisible(false)
		end
	end
end

function gPhone.hideStatusBarElement( name )
	for class, tab in pairs(gPhone.StatusBar) do
		if tab[string.lower(name)] then
			tab[string.lower(name)]:SetVisible(false)
		end
	end
end

--// Grab text size easily
function gPhone.getTextSize(text, font)
	surface.SetFont(font)
	return surface.GetTextSize(text)
end

--// Center text in a panel
function gPhone.setTextAndCenter(label, text, parent, vertical)
	label:SetText( text or label:GetText() )
	label:SetFont( label:GetFont() )
	label:SizeToContents()
	local x, y = label:GetPos()
	if vertical then
		label:SetPos( parent:GetWide()/2 - label:GetWide()/2, parent:GetTall()/2 - label:GetTall()/2 )
	else
		label:SetPos( parent:GetWide()/2 - label:GetWide()/2, y )
	end
end

--// Save config
function gPhone.saveClientConfig()
	gPhone.msgC( GPHONE_MSGC_NONE, "Saving config file")
	
	cfgJSON = util.TableToJSON( gPhone.config )
	
	file.CreateDir( "gphone" )
	file.Write( "gphone/config.txt", cfgJSON)
end

--// Load config
function gPhone.loadClientConfig()
	gPhone.msgC( GPHONE_MSGC_NONE, "Loading config file")
	
	if not file.Exists( "gphone/config.txt", "DATA" ) then
		gPhone.msgC( GPHONE_MSGC_WARNING, "Unable to locate config file!!")
		gPhone.saveClientConfig()
		gPhone.loadClientConfig()
		return
	end
	
	local cfgFile = file.Read( "gphone/config.txt", "DATA" )
	local cfgTable = util.JSONToTable( cfgFile ) 
	
	-- Make sure the config file accepts new values
	local shouldSave = false
	for k, v in pairs( gPhone.config ) do
		if not cfgTable[k] then
			gPhone.msgC( GPHONE_MSGC_NOTIFY, "Saved config file missing key/value: "..tostring(k).." "..tostring(v))
			cfgTable[k] = v
			shouldSave = true
		end
	end
	
	if shouldSave then
		gPhone.saveClientConfig()
	end
	
	gPhone.config = cfgTable
end

--// Retrieves app positions
function gPhone.saveAppPositions( tbl )
	cfgJSON = util.TableToJSON( tbl )
	
	file.CreateDir( "gphone" )
	file.Write( "gphone/homescreen_layout.txt", cfgJSON)
end

--// Saves moved app positions
function gPhone.getActiveAppPositions()
	if not file.Exists( "gphone/homescreen_layout.txt", "DATA" ) then
		gPhone.msgC( GPHONE_MSGC_WARNING, "Unable to locate app position file!")
		gPhone.saveAppPositions( gPhone.apps )
		return
	end
	
	local posFile = file.Read( "gphone/homescreen_layout.txt", "DATA" )
	local posTable = util.JSONToTable( posFile ) 

	return posTable
end

--// Sends a text message 
function gPhone.sendTextMessage( target, msg ) 
	local ply = util.getPlayerByNick( target )
	local idFormat = gPhone.steamIDToFormat( ply:SteamID() )
	
	local msgTable = {target=target, time=os.date( "%I:%M%p" ), date = os.date( "%x" ), message=msg }
	
	-- Off to the server!
	net.Start("gPhone_DataTransfer")
		net.WriteTable({header=GPHONE_TEXT_MSG, tbl=msgTable})
	net.SendToServer()
	
	-- If the server has flagged us as a spammer our message should not appear in the app
	-- The message does get sent to the server, though, so that we can receive a "X seconds left" message
	if LocalPlayer():GetNWBool("gPhone_CanText", true) == false then return end
	
	-- Store the sent text on the client
	msgTable.self = true
	msgTable.sender = LocalPlayer():Nick()
	gPhone.receiveTextMessage( msgTable, true )
end

--// Saves a text message to an existing txt document or a new one
function gPhone.receiveTextMessage( tbl, bSelf )
	-- tbl.sender, tbl.self, tbl.time, tbl.date, tbl.message
	local writeTable = {}
	local ply
	if bSelf then
		ply = util.getPlayerByNick( tbl.sender )
	else
		ply = util.getPlayerByNick( tbl.target )
	end
	local idFormat = gPhone.steamIDToFormat( ply:SteamID() )
	
	print("Received", bSelf, tbl.sender, tbl.target)
	
	if file.Exists( "gphone/messages/"..idFormat..".txt", "DATA" ) then
		local readFile = file.Read( "gphone/messages/"..idFormat..".txt", "DATA" )
		local readTable = util.JSONToTable( gPhone.unscrambleJSON( readFile ) ) 
		
		writeTable = readTable
	end

	table.insert( writeTable, tbl )

	local json = util.TableToJSON( writeTable ) 
	json = gPhone.scrambleJSON( json )
		
	file.CreateDir( "gphone/messages" )
	file.Write( "gphone/messages/"..idFormat..".txt", json)
	
	local app = gPhone.getActiveApp()
	if app and app.Data.UpdateMessages and gPhone.isOpen() then -- In app (viewing convo?)
	--if app and app.Data and app.Data.UpdateMessages and gPhone.isOpen() then -- In app (viewing convo?)
		print("Update - In app")
		app.Data.UpdateMessages( idFormat ) 
	elseif gPhone.isOpen() then -- In phone
		print("Update - Phone")
		gPhone.incrementBadge( "Messages", idFormat.."_message" )
	else -- Not in phone
		print("Update - Out")
		gPhone.vibrate()
		gPhone.incrementBadge( "Messages", idFormat.."_message" )
	end
end

--// Loads all text messages 
function gPhone.loadTextMessages()
	local msgTable = {}
	local files = file.Find( "gphone/messages/*.txt", "DATA" )
	
	for k, v in pairs(files) do
		local msgJSON = file.Read( "gphone/messages/"..v, "DATA" )
		local tbl = util.JSONToTable( gPhone.unscrambleJSON( msgJSON ) )
		
		local id = string.gsub(v, ".txt", "")
		id = gPhone.formatToSteamID( id )
		
		msgTable[id] = tbl
	end

	return msgTable
end

--// Checks the local gPhone version with the newest version
function gPhone.checkUpdate()
	local isUpdate = false
	http.Fetch( "http://www.exho.comeze.com/gphone/version.php", 
	function ( body, len, headers, code )
		local fragments = string.Explode( ",", body )
		
		local webVersion = fragments[1]
		local description = fragments[2]
		description = string.gsub(description, "|", "\r\n") -- Add in the spacing
		local date = string.sub( fragments[3], 1, 10 ) -- Trim off anything that is not part of the date
		
		gPhone.msgC( GPHONE_MSGC_NONE, "Successfully checked online server for version" )
		
		if webVersion != gPhone.version then
			isUpdate = true
			gPhone.incrementBadge( "Settings", "update" )
		else
			gPhone.decrementBadge( "Settings", true, "update" )
		end
		gPhone.updateTable = {update=isUpdate, version=webVersion, description=description, date=date}
	end,
	function (error)
		-- What now?
		gPhone.msgC( GPHONE_MSGC_WARNING, "Unable to connect to the gPhone webpage to verify versions!" )
		local str = "The gPhone was unable to connect to the update website to verify the local version, please check the workshop page"
		gPhone.updateTable = {update=true, version="N/A", description=str, date="N/A"}
	end)
end

--// Custom word wrapping function originally made for the texting app
function gPhone.WordWrap( label, wrapWidth, buffer )
	buffer = buffer or 10
	wrapWidth = wrapWidth - buffer
	
	label:SizeToContents()
	local w, h = label:GetSize()
	
	if w - buffer >= wrapWidth then -- Gmod's word wrapping is meh, I'll make my own
		local text = label:GetText()
		surface.SetFont(label:GetFont())
		
		-- Split the text by letter into a table
		local frags = string.Explode( "", text )
		local width, lineBreaks = 0, 1
		for k, v in pairs( frags ) do
			width = width + surface.GetTextSize(v)
			
			-- The string is longer than the message's width (minus a buffer)
			if width >= wrapWidth - (buffer + buffer/2) then 
				local letter = frags[k]
				if letter == " " then
					table.insert(frags, k, "\r\n")
				else
					table.insert(frags, k, "-\r\n-") -- Only hyphen words that we interrupted
				end
				lineBreaks = lineBreaks + 1
				width = 0 
			end
		end
		
		-- Reassemble the text 
		text = table.concat( frags, "" )
		label:SetText( text )
		
		-- Size the message box's background according to the number of line breaks
		label:SetSize( wrapWidth - buffer, h * (lineBreaks)) 
		
		return lineBreaks
	end
end

-- Adds a red badge to a homescreen app with a unique id
function gPhone.incrementBadge( app, id )
	id = string.lower( id )
	
	for i = 1, #gPhone.apps do
		if gPhone.apps[i].name == app then
			gPhone.appBadges[app] = gPhone.appBadges[app] or {}
			
			-- Check for repeats of the same badge id
			for k, v in pairs( gPhone.appBadges[app] ) do
				if v == id then
					gPhone.msgC( GPHONE_MSGC_WARNING, "Attempted to add another app badge of the same id: "..id )
					return
				end
			end
			
			-- Log to console and insert into the badge table
			gPhone.msgC( GPHONE_MSGC_NOTIFY, "Incremented "..app.." badge to "..#gPhone.appBadges[app].." with id: "..id )
			table.insert( gPhone.appBadges[app], id )
			
			-- Rebuild on homescreen
			if gPhone.isOnHomescreen then
				gPhone.buildHomescreen( gPhone.apps )
			end
		end
	end
end

-- Removes a badge id or removes all the ids for a specific app
function gPhone.decrementBadge( app, id, bAll )
	for i = 1, #gPhone.apps do
		if gPhone.apps[i].name == app then
			
			for k, v in pairs( gPhone.appBadges[app] ) do
				if v == id then
					if bAll then
						gPhone.appBadges[app] = {}
					else
						gPhone.appBadges[app][k] = nil
					end
				
					gPhone.msgC( GPHONE_MSGC_NOTIFY, "Decremented "..app.." badge to "..#gPhone.appBadges[app].." with id: "..id )
			
					-- Rebuild on homescreen
					if gPhone.isOnHomescreen then
						gPhone.buildHomescreen( gPhone.apps )
					end
					return
				end
			end
			gPhone.msgC( GPHONE_MSGC_WARNING, "Attempted remove badge for nonexistant id: "..id )
		end
	end
end

function gPhone.fixHomescreen( tbl )
	for k, v in pairs( tbl ) do
		if v.name:lower() == "n/a" then -- Invalid name 
			gPhone.msgC( GPHONE_MSGC_WARNING, "Invalid app at key: "..k.."!" )
			table.remove(tbl, k)
		end 
		
		for k2, v2 in pairs( tbl ) do -- Run through the same table a different time
			if v.apps then 
				local strTable = tostring(v.apps)
				for k3, v3 in pairs( v.apps ) do
					if v2.name == v3.name and v2.icon == v3.icon then -- App exists in both folder and homescreen
						gPhone.msgC( GPHONE_MSGC_WARNING, "Repeated app at key: "..k2.." and in folder: "..strTable.." key: "..k3)
						print(v2.name, v3.name)
						table.remove(tbl, k2)
					end
					
					for k4, v4 in pairs( v.apps ) do
						if v3.name == v4.name and v3.icon == v4.icon and k3 ~= k4 then -- Repeated app in a folder
							gPhone.msgC( GPHONE_MSGC_WARNING, "Repeated app in folder: "..strTable..". Keys: "..k3.." and "..k4)
							print(v3.name, v4.name)
							table.remove(tbl[k2].apps, k)
						end
					end
				end
			end
			
			if v.name == v2.name and v.icon == v2.icon and k ~= k2 then -- Repeated app
				if tbl[k].name == v.name and tbl[k].name == v2.name then
					gPhone.msgC( GPHONE_MSGC_WARNING, "Repeated app at keys: "..k.." and "..k2.."!" )
					table.remove(tbl, k)
				end
			end
		end
	end
end
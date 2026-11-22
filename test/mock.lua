-- Заглушки игрового API для прогона скриптов MyrrhAlert вне игры (luajit или texlua)
function Global( n, v ) _G[ n ] = v end

-- WString
local WSmt = {}
local function WSt( s ) return setmetatable( { s = s }, WSmt ) end
local rawtype = type
local function IsWS( v ) return rawtype( v ) == "table" and getmetatable( v ) == WSmt end
function type( v ) if IsWS( v ) then return "userdata" end return rawtype( v ) end
function apitype( v ) if IsWS( v ) then return "WString" end return rawtype( v ) end
WS = WSt

local function deep( t )
	if rawtype( t ) ~= "table" then return t end
	local r = {}
	for k, v in pairs( t ) do r[ k ] = deep( v ) end
	return r
end

CONFIG = {}     -- что лежит в файле настроек
CHAT = {}       -- что аддон написал в чат
userMods = {
	ToWString = function( s ) return WSt( s ) end,
	FromWString = function( w ) assert( IsWS( w ), "not WString" ) return w.s end,
	GetGlobalConfigSection = function( n ) return CONFIG[ n ] and deep( CONFIG[ n ] ) end,
	SetGlobalConfigSection = function( n, t ) CONFIG[ n ] = deep( t ) end,
	SendSelfChatMessage = function( w ) CHAT[ #CHAT + 1 ] = w.s end,
}

EVENTS, REACTIONS = {}, {}
DND = {}        -- что аддон отдал LibDnD: окно и то, за что его тянут
DnD = { Init = function( movable, reacting ) DND.movable, DND.reacting = movable, reacting end }
common = {
	RegisterReactionHandler = function( f, r ) REACTIONS[ r ] = f end,
	GetAddonName = function() return "MyrrhAlert" end,
	RegisterEventHandler = function( f, ev )
		local prev = EVENTS[ ev ]
		EVENTS[ ev ] = prev and function( p ) prev( p ) f( p ) end or f
	end,
}

-- Виджеты: помнят, показаны ли, и сколько раз их переключали
local Widget = {}
Widget.__index = Widget
function Widget.Show( w, on ) w.visible = on w.showCalls = w.showCalls + 1 end
function Widget.SetVal( w, tag, v ) assert( tag == "value" ) w.val = v.s end
function Widget.SetText( w, v ) w.text = v.s end
function Widget.GetText( w ) return WS( w.text or "" ) end
-- как в игре: смена фокуса поля ввода присылает реакцию
function Widget.SetFocus( w, on )
	if w.focused == on then return end
	w.focused = on
	REACTIONS.ma_threshold_focus( { active = on, widget = w } )
end
WIDGETS = {}
mainForm = {}
function mainForm.GetChildChecked( _, name )
	if not WIDGETS[ name ] then WIDGETS[ name ] = setmetatable( { visible = false, showCalls = 0 }, Widget ) end
	return WIDGETS[ name ]
end

-- Игра: MYRRH = nil — у персонажа мирры нет совсем (валюта не находится), иначе её количество
MYRRH = nil
EXISTS = true
local myrrhId = { currency = "myrrh" }
avatar = {
	IsExist = function() return EXISTS end,
	GetCurrencyId = function( sysName )
		if sysName == "myrrh" and MYRRH ~= nil then return myrrhId end
		return nil
	end,
	GetCurrencyValue = function( id )
		assert( id == myrrhId, "чужая валюта" )
		return { value = MYRRH }
	end,
}

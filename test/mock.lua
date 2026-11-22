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
function Widget.GetName( w ) return w.name end
-- как в игре: смена фокуса поля ввода присылает реакцию
function Widget.SetFocus( w, on )
	if w.focused == on then return end
	w.focused = on
	REACTIONS.ma_threshold_focus( { active = on, widget = w } )
end
WIDGETS = {}
mainForm = {}
function mainForm.GetChildChecked( _, name )
	if not WIDGETS[ name ] then WIDGETS[ name ] = setmetatable( { name = name, visible = false, showCalls = 0 }, Widget ) end
	return WIDGETS[ name ]
end

-- Игра.
-- MYRRH, MODULES = nil — такой валюты у персонажа нет совсем (игра её не находит), иначе её количество.
-- BAG — сумка: слот -> { name = название, count = сколько в стопке (nil — предмет не в стопке) }; nil — сумка не загружена.
MYRRH, MODULES = nil, nil
BAG = {}
EXISTS = true
ITEM_CONT_INVENTORY = 0
ITEM_CONT_DEPOSITE = 1

local function Currency( sysName, name )
	local id = { sysName = sysName }
	function id.GetInfo() return { sysName = sysName, name = WS( name ) } end
	return id
end
local CUR = {
	myrrh = Currency( "myrrh", "Мирра" ),
	gold = Currency( "gold_sys", "Золотые слитки" ),
	memory = Currency( "memory_sys", "Модуль памяти" ),
}
local function Value( id )
	if id == CUR.myrrh then return MYRRH end
	if id == CUR.memory then return MODULES end
	if id == CUR.gold then return 7 end
end

avatar = {
	IsExist = function() return EXISTS end,
	-- как в игре: таблица с индексами от 0, только те валюты, которые есть у персонажа
	GetCurrencies = function()
		local t, n = {}, 0
		for _, key in ipairs( { "gold", "myrrh", "memory" } ) do
			if Value( CUR[ key ] ) ~= nil then t[ n ] = CUR[ key ] n = n + 1 end
		end
		return t
	end,
	GetCurrencyId = function( sysName )
		for _, id in pairs( CUR ) do
			if id.sysName == sysName and Value( id ) ~= nil then return id end
		end
		return nil
	end,
	GetCurrencyValue = function( id )
		assert( Value( id ) ~= nil, "нет такой валюты" )
		return { value = Value( id ) }
	end,
}

BAG_READS = 0   -- сколько раз аддон читал сумку
containerLib = {
	GetItems = function( slotType )
		assert( slotType == ITEM_CONT_INVENTORY, "не сумка" )
		BAG_READS = BAG_READS + 1
		return BAG
	end,
}
itemLib = {
	GetItemInfo = function( item ) return { name = WS( item.name ) } end,
	GetStackInfo = function( item ) return item.count and { count = item.count, limit = 100 } or nil end,
}

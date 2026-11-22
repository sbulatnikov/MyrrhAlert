--------------------------------------------------------------------------------
-- MyrrhAlert / Util.lua
-- Общие помощники: строки, сообщение в чат, кэш виджетов.
--------------------------------------------------------------------------------
Global( "MA", {} )

MA.VERSION = "0.1.0"
MA.THRESHOLD_MAX = 9999999999    -- 10 знаков, как в поле ввода: мирры у персонажа бывают сотни миллионов

-- За чем следим. key — имя запаса в настройках и в логике, default — порог, пока игрок не задал свой
-- (0 — предупреждение выключено). Порядок — порядок строк в окне и надписей на экране.
MA.RESOURCES = {
	{ key = "myrrh", default = 100 },     -- мирра (ценности)
	{ key = "battery", default = 0 },     -- мана-батареи в сумке
	{ key = "memory", default = 0 },      -- модули памяти (ценности)
}

--------------------------------------------------------------------------------
-- Строки
--------------------------------------------------------------------------------
function MA.WS( s )
	return userMods.ToWString( s or "" )
end

-- Обычная строка из string или WString; для остального — пустая строка
function MA.S( v )
	if type( v ) == "string" then return v end
	-- Ожидаем: на входе может быть не строка (nil, число, другой объект API) — тогда пустая строка
	if v ~= nil and apitype( v ) == "WString" then return userMods.FromWString( v ) end
	return ""
end

function MA.Trim( s )
	return ( string.gsub( s or "", "^%s*(.-)%s*$", "%1" ) )
end

-- Целое число с пробелами между разрядами: 497523688 -> «497 523 688»
function MA.Num( n )
	local s = string.format( "%.0f", n )
	local head = #s % 3
	local parts = {}
	if head > 0 then parts[ 1 ] = string.sub( s, 1, head ) end
	for i = head + 1, #s, 3 do parts[ #parts + 1 ] = string.sub( s, i, i + 2 ) end
	return table.concat( parts, " " )
end

-- Ответ аддона игроку — строкой в чат, которую видит только он
function MA.Chat( text )
	userMods.SendSelfChatMessage( MA.WS( "[MyrrhAlert] " .. text ), "notice" )
end

--------------------------------------------------------------------------------
-- Виджеты: кэш и пропуск повторных вызовов с тем же значением
--------------------------------------------------------------------------------
local widgetCache = {}

function MA.W( name )
	local w = widgetCache[ name ]
	if w == nil then
		w = mainForm:GetChildChecked( name, true )
		widgetCache[ name ] = w
	end
	return w
end

local shown = setmetatable( {}, { __mode = "k" } )
local texts = setmetatable( {}, { __mode = "k" } )

function MA.Show( w, on )
	on = on and true or false
	if shown[ w ] ~= on then
		shown[ w ] = on
		w:Show( on )
	end
end

-- Текст надписи (WidgetTextView с <r name="value"/> в формате)
function MA.SetText( w, s )
	if texts[ w ] ~= s then
		texts[ w ] = s
		w:SetVal( "value", MA.WS( s ) )
	end
end

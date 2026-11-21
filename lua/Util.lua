--------------------------------------------------------------------------------
-- MyrrhAlert / Util.lua
-- Общие помощники: строки, сообщение в чат, кэш виджетов.
--------------------------------------------------------------------------------
Global( "MA", {} )

MA.VERSION = "0.1.0"
MA.CURRENCY = "myrrh"            -- внутреннее имя мирры в игре (документация: avatar.GetCurrencyId)
MA.THRESHOLD_DEFAULT = 100       -- порог, пока игрок не задал свой
MA.THRESHOLD_MAX = 1000000       -- больше мирры у персонажа не бывает, а число в настройках остаётся разумным

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

function MA.Show( w, on )
	on = on and true or false
	if shown[ w ] ~= on then
		shown[ w ] = on
		w:Show( on )
	end
end

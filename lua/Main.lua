--------------------------------------------------------------------------------
-- MyrrhAlert / Main.lua
-- Запуск, события, команда /myrrh.
--------------------------------------------------------------------------------
local Cfg, Myrrh, UI = MA.Cfg, MA.Myrrh, MA.UI
local started = false

-- Пересчитать и показать или спрятать надпись
local function Refresh()
	UI.ShowWarning( Myrrh.IsLow() )
end

-- Изменилось количество какой-то валюты: нас интересует только мирра
local function OnCurrencyValueChanged( p )
	if p.sysName == MA.CURRENCY then Refresh() end
end

local function Report()
	local threshold = MA.cfg.threshold
	local limit = threshold > 0 and ( "порог " .. threshold ) or "предупреждение выключено (порог 0)"
	MA.Chat( limit .. ", мирры сейчас " .. Myrrh.Amount() .. ". Изменить порог: /myrrh <число>" )
end

-- /myrrh — показать порог и количество мирры; /myrrh <число> — задать порог (0 — выключить)
local function OnSlash( p )
	local text = string.lower( MA.Trim( MA.S( p.text ) ) )
	-- после /myrrh — конец строки или пробел: команду /myrrhabc своей не считаем
	local arg = ( text == "/myrrh" ) and "" or string.match( text, "^/myrrh%s+(.*)$" )
	-- Ожидаем: это чужая команда, а не /myrrh — не наше дело
	if not arg then return end
	if arg ~= "" then
		local n = Cfg.NormalizeThreshold( arg )
		-- Ожидаем: после /myrrh написано не число — подсказываем, как правильно, и порог не меняем
		if not n then
			MA.Chat( "порог — это число, например: /myrrh 100 (0 — выключить предупреждение)" )
			return
		end
		Cfg.SetThreshold( n )
		Refresh()
	end
	Report()
end

local function Start()
	if started then return end
	started = true
	Cfg.Load()
	common.RegisterEventHandler( OnCurrencyValueChanged, "EVENT_CURRENCY_VALUE_CHANGED" )
	-- список валют меняется, когда у персонажа появляется первая мирра или пропадает последняя
	common.RegisterEventHandler( Refresh, "EVENT_CURRENCIES_CHANGED" )
	common.RegisterEventHandler( OnSlash, "EVENT_UNKNOWN_SLASH_COMMAND" )
	Refresh()
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end

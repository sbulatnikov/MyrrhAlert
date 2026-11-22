--------------------------------------------------------------------------------
-- MyrrhAlert / Main.lua
-- Запуск, события, реакции окна, команда /myrrh.
--------------------------------------------------------------------------------
local Cfg, Myrrh, UI = MA.Cfg, MA.Myrrh, MA.UI
local started = false

-- Пересчитать и перерисовать надпись и окно
local function Refresh()
	local amount = Myrrh.Amount()
	UI.Render( { low = Myrrh.IsLow( amount ), amount = amount, threshold = MA.cfg.threshold } )
end

-- Изменилось количество какой-то валюты: нас интересует только мирра
local function OnCurrencyValueChanged( p )
	if p.sysName == MA.CURRENCY then Refresh() end
end

local function SetThreshold( n )
	Cfg.SetThreshold( n )
	Refresh()
end

-- /myrrh — открыть окно настроек; /myrrh <число> — сразу задать порог (0 — выключить)
local function OnSlash( p )
	local text = string.lower( MA.Trim( MA.S( p.text ) ) )
	-- после /myrrh — конец строки или пробел: команду /myrrhabc своей не считаем
	local arg = ( text == "/myrrh" ) and "" or string.match( text, "^/myrrh%s+(.*)$" )
	-- Ожидаем: это чужая команда, а не /myrrh — не наше дело
	if not arg then return end
	if arg == "" then
		Refresh()   -- окно открывается со свежим количеством мирры
		UI.ShowWindow( true )
		return
	end
	local n = Cfg.NormalizeThreshold( arg )
	-- Ожидаем: после /myrrh написано не число — подсказываем, как правильно, и порог не меняем
	if not n then
		MA.Chat( "порог — это число, например: /myrrh 100 (0 — выключить предупреждение). Окно настроек: /myrrh" )
		return
	end
	SetThreshold( n )
	MA.Chat( n > 0 and ( "порог " .. n .. ", мирры сейчас " .. Myrrh.Amount() ) or "предупреждение выключено (порог 0)" )
end

local REACTIONS = {
	ma_close = UI.OnClose,
	ma_apply = UI.OnApply,
	ma_threshold_enter = UI.OnEnter,
	ma_threshold_esc = UI.OnEsc,
	ma_threshold_focus = UI.OnFocus,
}

local function Start()
	if started then return end
	started = true
	Cfg.Load()
	UI.onThreshold = SetThreshold
	UI.Init()
	for name, fn in pairs( REACTIONS ) do common.RegisterReactionHandler( fn, name ) end
	common.RegisterEventHandler( OnCurrencyValueChanged, "EVENT_CURRENCY_VALUE_CHANGED" )
	-- список валют меняется, когда у персонажа появляется первая мирра или пропадает последняя
	common.RegisterEventHandler( Refresh, "EVENT_CURRENCIES_CHANGED" )
	common.RegisterEventHandler( OnSlash, "EVENT_UNKNOWN_SLASH_COMMAND" )
	Refresh()
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end

--------------------------------------------------------------------------------
-- MyrrhAlert / Main.lua
-- Запуск, события, реакции окна, команда /myrrh.
--------------------------------------------------------------------------------
local Cfg, Stock, UI = MA.Cfg, MA.Stock, MA.UI
local started = false

-- Перерисовать надписи и окно по тому, что сейчас известно о запасах
local function Refresh()
	local state = {}
	for i, r in ipairs( MA.RESOURCES ) do
		state[ i ] = { key = r.key, low = Stock.IsLow( r.key ), amount = Stock.Amount( r.key ), threshold = MA.cfg[ r.key ] }
	end
	UI.Render( state )
end

local function RefreshCurrencies()
	Stock.ReadCurrencies()
	Refresh()
end

local function RefreshBag()
	Stock.ReadBag()
	Refresh()
end

-- Изменилось количество какой-то валюты: нас интересуют только мирра и модули памяти
local function OnCurrencyValueChanged( p )
	if Stock.IsOurCurrency( p.sysName ) then RefreshCurrencies() end
end

-- В сумке появился, пропал или изменился предмет (например, уменьшилась стопка батарей)
local function OnBagItem( p )
	-- Ожидаем: событие про другой контейнер (банк, экипировка) — батареи считаем только в сумке
	if p.slotType ~= ITEM_CONT_INVENTORY then return end
	-- Ожидаем: предмет просто переложили внутри сумки — количество не изменилось, не пересчитываем
	if p.isNewItem == false or p.isRemovedItem == false then return end
	RefreshBag()
end

local function SetThreshold( key, n )
	Cfg.SetThreshold( key, n )
	Refresh()
end

-- /myrrh — открыть окно настроек; /myrrh <число> — сразу задать порог мирры (0 — выключить)
local function OnSlash( p )
	local text = string.lower( MA.Trim( MA.S( p.text ) ) )
	-- после /myrrh — конец строки или пробел: команду /myrrhabc своей не считаем
	local arg = ( text == "/myrrh" ) and "" or string.match( text, "^/myrrh%s+(.*)$" )
	-- Ожидаем: это чужая команда, а не /myrrh — не наше дело
	if not arg then return end
	if arg == "" then
		-- окно открывается со свежими количествами
		Stock.ReadCurrencies()
		RefreshBag()
		UI.ShowWindow( true )
		return
	end
	local n = Cfg.NormalizeThreshold( arg )
	-- Ожидаем: после /myrrh написано не число — подсказываем, как правильно, и порог не меняем
	if not n then
		MA.Chat( "порог — это число, например: /myrrh 100 (0 — выключить предупреждение). Окно настроек: /myrrh" )
		return
	end
	SetThreshold( "myrrh", n )
	MA.Chat( n > 0 and ( "порог " .. MA.Num( n ) .. ", мирры сейчас " .. MA.Num( Stock.Amount( "myrrh" ) ) ) or "предупреждение выключено (порог 0)" )
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
	-- список валют меняется, когда у персонажа появляется первая мирра (или модуль памяти) или пропадает последняя
	common.RegisterEventHandler( RefreshCurrencies, "EVENT_CURRENCIES_CHANGED" )
	common.RegisterEventHandler( OnBagItem, "EVENT_CONTAINER_ITEM_ADDED" )
	common.RegisterEventHandler( OnBagItem, "EVENT_CONTAINER_ITEM_REMOVED" )
	common.RegisterEventHandler( OnBagItem, "EVENT_CONTAINER_ITEM_CHANGED" )
	common.RegisterEventHandler( OnSlash, "EVENT_UNKNOWN_SLASH_COMMAND" )
	Stock.ReadCurrencies()
	RefreshBag()
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end

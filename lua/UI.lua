--------------------------------------------------------------------------------
-- MyrrhAlert / UI.lua
-- Интерфейс: надписи-предупреждения вверху экрана и окно настроек с порогами.
-- Виджеты, тексты и текстуры собирает gen/build.py.
-- Интерфейс ничего не считает и не сохраняет сам: состояние приходит в UI.Render,
-- а новый порог уходит в Main через UI.onThreshold.
-- Строки окна и надписи идут в порядке MA.RESOURCES: строка i — это state[ i ].
--------------------------------------------------------------------------------
MA.UI = {}
local UI = MA.UI

-- Надпись на экране для каждого запаса
local WARNING = {
	myrrh = "НЕДОСТАТОЧНО МИРРЫ",
	battery = "НЕДОСТАТОЧНО МАНА-БАТАРЕЙ",
	memory = "НЕДОСТАТОЧНО МОДУЛЕЙ ПАМЯТИ",
}

local ui = { warning = {}, edit = {}, focus = {}, amount = {} }
local rows = 0             -- сколько строк в окне (и надписей на экране)
local editing = nil        -- номер строки, в поле которой игрок сейчас печатает: его текст не перезаписываем
local shownEdit = {}       -- какой текст мы сами положили в поле строки (чтобы не писать тот же)
local state = nil          -- последнее состояние из UI.Render

-- Main подставляет сюда функцию: что делать с новым порогом — function( key, n )
UI.onThreshold = nil

function UI.Init()
	rows = #MA.RESOURCES
	for i = 1, rows do
		ui.warning[ i ] = MA.W( "Warning" .. i )
		ui.edit[ i ] = MA.W( "ThresholdEdit" .. i )
		ui.focus[ i ] = MA.W( "ThresholdFocus" .. i )
		ui.amount[ i ] = MA.W( "AmountText" .. i )
	end
	ui.window = MA.W( "MAWindow" )
	ui.header = MA.W( "Header" )
	-- окно перетаскивается за шапку; LibDnD сам запоминает положение в настройках
	DnD.Init( ui.window, ui.header, true, true )
end

local function Draw()
	-- надписи идут подряд сверху вниз, без пустых мест: первая нехватка — в первой строке
	local line = 0
	for i = 1, rows do
		local s = state[ i ]
		if s.low then
			line = line + 1
			MA.SetText( ui.warning[ line ], WARNING[ s.key ] )
			MA.Show( ui.warning[ line ], true )
		end
	end
	for i = line + 1, rows do MA.Show( ui.warning[ i ], false ) end

	for i = 1, rows do
		local s = state[ i ]
		MA.Show( ui.focus[ i ], editing == i )
		MA.SetText( ui.amount[ i ], "Сейчас: " .. MA.Num( s.amount ) )
		local text = string.format( "%.0f", s.threshold )   -- без разделителей: поле принимает только цифры
		if editing ~= i and shownEdit[ i ] ~= text then
			shownEdit[ i ] = text
			ui.edit[ i ]:SetText( MA.WS( text ) )
		end
	end
end

-- s — список по MA.RESOURCES: { key = запас, low = надпись видна, amount = сколько есть, threshold = порог }
function UI.Render( s )
	state = s
	Draw()
end

-- Игрок перестал печатать в строке i, введённое не принимаем: поле покажет прежний порог
local function Discard( i )
	editing = nil
	shownEdit[ i ] = nil
	ui.edit[ i ]:SetFocus( false )
	Draw()
end

function UI.ShowWindow( on )
	MA.Show( ui.window, on )
	-- Ожидаем: окно закрыли, не закончив ввод — недописанное число отбрасываем
	if not on and editing then Discard( editing ) end
end

--------------------------------------------------------------------------------
-- Поля порогов. Значение принимается по Enter, по кнопке «Применить» и при потере
-- фокуса; Esc возвращает прежнее.
--------------------------------------------------------------------------------
-- Номер строки по виджету поля ввода из параметров реакции
local function RowOf( params )
	return tonumber( string.match( params.widget:GetName(), "^ThresholdEdit(%d+)$" ) )
end

local function Commit( i )
	editing = nil
	shownEdit[ i ] = nil    -- поле перерисуется: покажет принятый порог или вернёт прежний
	local n = MA.Cfg.NormalizeThreshold( MA.Trim( MA.S( ui.edit[ i ]:GetText() ) ) )
	-- Ожидаем: поле пустое — это не число, порог не меняем и возвращаем в поле прежний
	if n then
		UI.onThreshold( state[ i ].key, n )   -- Main сохранит порог и вызовет UI.Render
	else
		Draw()
	end
end

function UI.OnFocus( params )
	local i = RowOf( params )
	if params.active then
		editing = i
		Draw()
	elseif editing == i then
		Commit( i )
	end
end

function UI.OnEnter( params )
	local i = RowOf( params )
	Commit( i )
	ui.edit[ i ]:SetFocus( false )
end

-- Кнопка принимает поле, в котором игрок печатает; остальные приняты, когда он из них ушёл
function UI.OnApply()
	local i = editing
	if not i then return end
	Commit( i )
	ui.edit[ i ]:SetFocus( false )
end

function UI.OnEsc( params )
	Discard( RowOf( params ) )
end

function UI.OnClose()
	UI.ShowWindow( false )
end

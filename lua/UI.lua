--------------------------------------------------------------------------------
-- MyrrhAlert / UI.lua
-- Интерфейс: надпись «НЕДОСТАТОЧНО МИРРЫ» вверху экрана и окно настроек с порогом.
-- Виджеты, тексты и текстуры собирает gen/build.py.
-- Интерфейс ничего не считает и не сохраняет сам: состояние приходит в UI.Render,
-- а новый порог уходит в Main через UI.onThreshold.
--------------------------------------------------------------------------------
MA.UI = {}
local UI = MA.UI

local ui = {}
local editing = false      -- игрок сейчас печатает в поле порога: его текст не перезаписываем
local shownEdit = nil      -- какой текст мы сами положили в поле (чтобы не писать тот же)
local state = nil          -- последнее состояние из UI.Render

-- Main подставляет сюда функцию: что делать с новым порогом
UI.onThreshold = nil

function UI.Init()
	ui.warning = MA.W( "Warning" )
	ui.window = MA.W( "MAWindow" )
	ui.header = MA.W( "Header" )
	ui.edit = MA.W( "ThresholdEdit" )
	ui.focus = MA.W( "ThresholdFocus" )
	ui.amount = MA.W( "AmountText" )
	-- окно перетаскивается за шапку; LibDnD сам запоминает положение в настройках
	DnD.Init( ui.window, ui.header, true, true )
end

local function Draw()
	MA.Show( ui.warning, state.low )
	MA.Show( ui.focus, editing )
	MA.SetText( ui.amount, "Сейчас мирры: " .. MA.Num( state.amount ) )
	local s = string.format( "%.0f", state.threshold )   -- без разделителей: поле принимает только цифры
	if not editing and shownEdit ~= s then
		shownEdit = s
		ui.edit:SetText( MA.WS( s ) )
	end
end

-- s = { low = надпись видна, amount = сколько мирры, threshold = порог }
function UI.Render( s )
	state = s
	Draw()
end

function UI.ShowWindow( on )
	MA.Show( ui.window, on )
	-- Ожидаем: окно закрыли, не закончив ввод — недописанное число отбрасываем
	if not on and editing then
		editing = false
		shownEdit = nil
		ui.edit:SetFocus( false )
		Draw()
	end
end

--------------------------------------------------------------------------------
-- Поле порога. Значение принимается по Enter, по кнопке «Применить» и при потере
-- фокуса; Esc возвращает прежнее.
--------------------------------------------------------------------------------
local function Commit()
	editing = false
	shownEdit = nil    -- поле перерисуется: покажет принятый порог или вернёт прежний
	local n = MA.Cfg.NormalizeThreshold( MA.Trim( MA.S( ui.edit:GetText() ) ) )
	-- Ожидаем: поле пустое — это не число, порог не меняем и возвращаем в поле прежний
	if n then
		UI.onThreshold( n )   -- Main сохранит порог и вызовет UI.Render
	else
		Draw()
	end
end

function UI.OnFocus( params )
	if params.active then
		editing = true
		Draw()
	elseif editing then
		Commit()
	end
end

function UI.OnEnter()
	Commit()
	ui.edit:SetFocus( false )
end

function UI.OnApply()
	Commit()
	ui.edit:SetFocus( false )
end

function UI.OnEsc()
	editing = false
	shownEdit = nil
	ui.edit:SetFocus( false )
	Draw()
end

function UI.OnClose()
	UI.ShowWindow( false )
end

-- Тесты MyrrhAlert на заглушках:  <lua> test/run.lua <корень репозитория> <папка со скриптами>
local root, scripts = arg[ 1 ], arg[ 2 ]
dofile( root .. "/test/mock.lua" )

local failed, passed = 0, 0
local function check( what, cond )
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		print( "ПРОВАЛ: " .. what )
	end
end

local function fire( ev, p ) EVENTS[ ev ]( p or {} ) end
local function slash( text ) fire( "EVENT_UNKNOWN_SLASH_COMMAND", { text = WS( text ) } ) end
local function currencyEvent( key ) fire( "EVENT_CURRENCY_VALUE_CHANGED", { sysName = CUR_ID[ key ].sysName, id = CUR_ID[ key ], delta = 1 } ) end
local function setMyrrh( n )
	MYRRH = n
	currencyEvent( "myrrh" )
end
local function warning() return WIDGETS.Warning1 and WIDGETS.Warning1.visible end
local function lastChat() return CHAT[ #CHAT ] or "" end

-- Запуск до входа в мир: аддон ждёт EVENT_AVATAR_CREATED
EXISTS = false
MYRRH = 37
-- LibDnD в тестах заменён заглушкой DnD из mock.lua
for _, s in ipairs( { "Util", "Config", "Stock", "UI", "Main" } ) do dofile( scripts .. "/" .. s .. ".lua" ) end
check( "до входа в мир аддон не запущен", MA.cfg == nil and WIDGETS.Warning1 == nil )
EXISTS = true
fire( "EVENT_AVATAR_CREATED" )
check( "порог по умолчанию 100", MA.cfg.myrrh == 100 )
check( "37 < 100 — надпись видна", warning() == true )

setMyrrh( 100 )
check( "100 при пороге 100 — мирры хватает, надписи нет", warning() == false )
setMyrrh( 99 )
check( "99 < 100 — надпись видна", warning() == true )

-- чужая валюта не трогает надпись и не дёргает виджет
local calls = WIDGETS.Warning1.showCalls
MYRRH = 500
currencyEvent( "gold" )
check( "чужая валюта: пересчёта нет", warning() == true and WIDGETS.Warning1.showCalls == calls )
setMyrrh( 500 )
setMyrrh( 600 )
check( "виджет переключается, только когда значение изменилось", WIDGETS.Warning1.showCalls == calls + 1 )

-- мирры нет совсем: игра не находит валюту
MYRRH = nil
fire( "EVENT_CURRENCIES_CHANGED" )
check( "валюты нет у персонажа — мирры 0, надпись видна", warning() == true and MA.Stock.Amount( "myrrh" ) == 0 )

-- команда /myrrh <число>
MYRRH = 250
fire( "EVENT_CURRENCIES_CHANGED" )
check( "250 при пороге 100 — надписи нет", warning() == false )
slash( "/myrrh 300" )
check( "/myrrh 300: порог сохранён", MA.cfg.myrrh == 300 and CONFIG.MyrrhAlert.ma.myrrh == 300 )
check( "/myrrh 300: надпись появилась сразу", warning() == true )
check( "/myrrh 300: ответ в чат", string.find( lastChat(), "порог 300, мирры сейчас 250", 1, true ) ~= nil )
slash( "/myrrh много" )
check( "не число: порог не меняется, есть подсказка", MA.cfg.myrrh == 300 and string.find( lastChat(), "число", 1, true ) ~= nil )
local n = #CHAT
slash( "/myrrhх 5" )
slash( "/baa" )
check( "чужие команды аддон не трогает", #CHAT == n and MA.cfg.myrrh == 300 )
slash( "/myrrh 12.9" )
check( "дробный порог округляется вниз", MA.cfg.myrrh == 12 )
slash( "/myrrh -5" )
check( "отрицательный порог — это 0", MA.cfg.myrrh == 0 )
check( "порог 0: в ответе сказано, что выключено", string.find( lastChat(), "выключено", 1, true ) ~= nil )
MYRRH = nil
fire( "EVENT_CURRENCIES_CHANGED" )
check( "порог 0 выключает предупреждение", warning() == false )

-- окно настроек
local win, edit, focus = WIDGETS.MAWindow, WIDGETS.ThresholdEdit1, WIDGETS.ThresholdFocus1
local function typeIn( text ) edit:SetFocus( true ) edit.text = text end
check( "окно перетаскивается за шапку", DND.movable == win and DND.reacting == WIDGETS.Header )
check( "до команды окно закрыто", win.visible == false )
n = #CHAT
MYRRH = 250
slash( "/MYRRH" )
check( "/myrrh открывает окно и ничего не пишет в чат", win.visible == true and #CHAT == n )
check( "в окне — порог и количество мирры", edit.text == "0" and WIDGETS.AmountText1.val == "Сейчас: 250" )

typeIn( "300" )
check( "при вводе поле подсвечено, порог ещё прежний", focus.visible == true and MA.cfg.myrrh == 0 )
setMyrrh( 260 )
check( "пока игрок печатает, его текст не затирается", edit.text == "300" and WIDGETS.AmountText1.val == "Сейчас: 260" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "Enter: порог принят и сохранён", MA.cfg.myrrh == 300 and CONFIG.MyrrhAlert.ma.myrrh == 300 )
check( "Enter: надпись появилась, подсветка снята", warning() == true and focus.visible == false and edit.focused == false )

typeIn( "50" )
REACTIONS.ma_threshold_esc( { widget = edit } )
check( "Esc: порог прежний, в поле снова он", MA.cfg.myrrh == 300 and edit.text == "300" and focus.visible == false )

typeIn( "200" )
REACTIONS.ma_apply( {} )
check( "кнопка «Применить»: порог принят", MA.cfg.myrrh == 200 and warning() == false and edit.focused == false )

typeIn( "150" )
edit:SetFocus( false )
check( "потеря фокуса: порог принят", MA.cfg.myrrh == 150 and edit.text == "150" )

typeIn( "" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "пустое поле: порог не меняется, в поле прежний", MA.cfg.myrrh == 150 and edit.text == "150" )

-- мирры бывают сотни миллионов: порог и количество такого размера работают, в окне разряды разделены
setMyrrh( 497523688 )
typeIn( "500000000" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "порог 500 млн принят, в поле — цифры без разделителей", MA.cfg.myrrh == 500000000 and edit.text == "500000000" )
check( "497 523 688 < 500 млн — надпись видна", warning() == true )
check( "количество мирры — с пробелами между разрядами", WIDGETS.AmountText1.val == "Сейчас: 497 523 688" )
check( "разделение разрядов", MA.Num( 0 ) == "0" and MA.Num( 999 ) == "999" and MA.Num( 1000 ) == "1 000" and MA.Num( 9999999999 ) == "9 999 999 999" )
slash( "/myrrh 99999999999" )
check( "слишком большой порог обрезается до 9999999999", MA.cfg.myrrh == 9999999999 and edit.text == "9999999999" )

typeIn( "77" )
REACTIONS.ma_close( {} )
check( "закрытие окна отбрасывает недописанное", win.visible == false and MA.cfg.myrrh == 9999999999 and edit.text == "9999999999" and edit.focused == false )

-- мана-батареи в сумке и модули памяти в ценностях
local function bagEvent( ev, p )
	p = p or {}
	p.slotType = p.slotType or ITEM_CONT_INVENTORY
	fire( ev, p )
end
local function warnings()
	local t = {}
	for i = 1, 3 do
		local w = WIDGETS[ "Warning" .. i ]
		if w.visible then t[ #t + 1 ] = w.val end
	end
	return table.concat( t, " | " )
end
MA.Cfg.SetThreshold( "myrrh", 0 )
setMyrrh( 1000 )
check( "батареи и модули по умолчанию выключены", MA.cfg.battery == 0 and MA.cfg.memory == 0 and warnings() == "" )

BAG = { [ 0 ] = { name = "Мана-батарея", count = 20 }, [ 3 ] = { name = "Зелье маны", count = 50 },
	[ 7 ] = { name = "Мана-батарея", count = 5 }, [ 9 ] = { name = "Меч" } }
bagEvent( "EVENT_CONTAINER_ITEM_ADDED", { isNewItem = true } )
check( "батареи: складываются все стопки, чужие предметы не считаются", MA.Stock.Amount( "battery" ) == 25 )
check( "в окне — количество батарей", WIDGETS.AmountText2.val == "Сейчас: 25" )

local edit2, edit3 = WIDGETS.ThresholdEdit2, WIDGETS.ThresholdEdit3
slash( "/myrrh" )
edit2:SetFocus( true ) edit2.text = "30"
check( "подсвечено только то поле, в котором печатают", WIDGETS.ThresholdFocus2.visible == true and WIDGETS.ThresholdFocus1.visible == false )
REACTIONS.ma_threshold_enter( { widget = edit2 } )
check( "порог батарей принят из своего поля", MA.cfg.battery == 30 and CONFIG.MyrrhAlert.ma.battery == 30 and MA.cfg.myrrh == 0 )
check( "25 < 30 — надпись про батареи, в первой строке", warnings() == "НЕДОСТАТОЧНО МАНА-БАТАРЕЙ" )

BAG[ 7 ].count = 12
bagEvent( "EVENT_CONTAINER_ITEM_CHANGED" )
check( "стопка выросла: 32 батареи, надписи нет", MA.Stock.Amount( "battery" ) == 32 and warnings() == "" )
BAG[ 0 ] = nil
local reads = BAG_READS
bagEvent( "EVENT_CONTAINER_ITEM_REMOVED", { isRemovedItem = false } )
bagEvent( "EVENT_CONTAINER_ITEM_ADDED", { isNewItem = false } )
bagEvent( "EVENT_CONTAINER_ITEM_REMOVED", { isRemovedItem = true, slotType = ITEM_CONT_DEPOSITE } )
check( "перекладывание в сумке и чужой контейнер: сумку не перечитываем", BAG_READS == reads )
bagEvent( "EVENT_CONTAINER_ITEM_REMOVED", { isRemovedItem = true } )
check( "стопку убрали: 12 батарей, надпись видна", MA.Stock.Amount( "battery" ) == 12 and warnings() == "НЕДОСТАТОЧНО МАНА-БАТАРЕЙ" )
BAG = nil
bagEvent( "EVENT_CONTAINER_ITEM_CHANGED" )
check( "сумка не загружена — батарей 0", MA.Stock.Amount( "battery" ) == 0 )
BAG = { [ 1 ] = { name = "Батарея маны" } }
bagEvent( "EVENT_CONTAINER_ITEM_ADDED", { isNewItem = true } )
check( "предмет не в стопке — это одна батарея", MA.Stock.Amount( "battery" ) == 1 )

-- модули памяти: пока их нет, игра не показывает эту валюту
edit3:SetFocus( true ) edit3.text = "5"
REACTIONS.ma_apply( {} )
check( "порог модулей принят кнопкой", MA.cfg.memory == 5 and edit3.focused == false )
check( "модулей нет совсем — их 0, обе надписи видны по порядку",
	MA.Stock.Amount( "memory" ) == 0 and warnings() == "НЕДОСТАТОЧНО МАНА-БАТАРЕЙ | НЕДОСТАТОЧНО МОДУЛЕЙ ПАМЯТИ" )
-- список валют ещё не обновился, а событие про модули уже пришло: узнаём их по названию; в общем списке их нет
IN_LIST = false
MODULES = 3
currencyEvent( "memory" )
check( "модули появились: найдены по названию в категории ценностей", MA.Stock.Amount( "memory" ) == 3 and WIDGETS.AmountText3.val == "Сейчас: 3" )
IN_LIST = true
MODULES = 8
currencyEvent( "memory" )
check( "модулей стало 8 при пороге 5 — осталась только надпись про батареи", warnings() == "НЕДОСТАТОЧНО МАНА-БАТАРЕЙ" )
MA.Cfg.SetThreshold( "battery", 0 )
MODULES = 2
currencyEvent( "memory" )
check( "надпись про модули поднимается в первую строку", warnings() == "НЕДОСТАТОЧНО МОДУЛЕЙ ПАМЯТИ" and WIDGETS.Warning2.visible == false )
MA.Cfg.SetThreshold( "myrrh", 2000 )
setMyrrh( 1000 )
check( "мирра и модули: надписи в порядке окна", warnings() == "НЕДОСТАТОЧНО МИРРЫ | НЕДОСТАТОЧНО МОДУЛЕЙ ПАМЯТИ" )
slash( "/myrrh 0" )
check( "/myrrh <число> меняет только порог мирры", MA.cfg.myrrh == 0 and MA.cfg.memory == 5 )
REACTIONS.ma_close( {} )

-- настройки: чужие ключи секции не теряются, испорченный порог чинится
CONFIG.MyrrhAlert = { other = "keep", ma = { threshold = "сломано" } }
MA.Cfg.Load()
check( "испорченный порог — берём 100", MA.cfg.myrrh == 100 )
MA.Cfg.SetThreshold( "myrrh", 40 )
check( "запись не теряет чужие ключи", CONFIG.MyrrhAlert.other == "keep" and CONFIG.MyrrhAlert.ma.myrrh == 40 )

CONFIG.MyrrhAlert = { ma = { version = 1, threshold = 250 } }
MA.Cfg.Load()
check( "настройки версии 1: порог мирры переезжает, новые пороги выключены",
	MA.cfg.myrrh == 250 and MA.cfg.threshold == nil and MA.cfg.battery == 0 and MA.cfg.memory == 0 and MA.cfg.version == 2 )

print( string.format( "тестов: %d, провалов: %d", passed + failed, failed ) )
os.exit( failed == 0 and 0 or 1 )

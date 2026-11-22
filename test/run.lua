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
local function setMyrrh( n )
	MYRRH = n
	fire( "EVENT_CURRENCY_VALUE_CHANGED", { sysName = "myrrh", delta = 1 } )
end
local function warning() return WIDGETS.Warning and WIDGETS.Warning.visible end
local function lastChat() return CHAT[ #CHAT ] or "" end

-- Запуск до входа в мир: аддон ждёт EVENT_AVATAR_CREATED
EXISTS = false
MYRRH = 37
-- LibDnD в тестах заменён заглушкой DnD из mock.lua
for _, s in ipairs( { "Util", "Config", "Myrrh", "UI", "Main" } ) do dofile( scripts .. "/" .. s .. ".lua" ) end
check( "до входа в мир аддон не запущен", MA.cfg == nil and WIDGETS.Warning == nil )
EXISTS = true
fire( "EVENT_AVATAR_CREATED" )
check( "порог по умолчанию 100", MA.cfg.threshold == 100 )
check( "37 < 100 — надпись видна", warning() == true )

setMyrrh( 100 )
check( "100 при пороге 100 — мирры хватает, надписи нет", warning() == false )
setMyrrh( 99 )
check( "99 < 100 — надпись видна", warning() == true )

-- чужая валюта не трогает надпись и не дёргает виджет
local calls = WIDGETS.Warning.showCalls
MYRRH = 500
fire( "EVENT_CURRENCY_VALUE_CHANGED", { sysName = "gold", delta = 5 } )
check( "чужая валюта: пересчёта нет", warning() == true and WIDGETS.Warning.showCalls == calls )
setMyrrh( 500 )
setMyrrh( 600 )
check( "виджет переключается, только когда значение изменилось", WIDGETS.Warning.showCalls == calls + 1 )

-- мирры нет совсем: игра не находит валюту
MYRRH = nil
fire( "EVENT_CURRENCIES_CHANGED" )
check( "валюты нет у персонажа — мирры 0, надпись видна", warning() == true and MA.Myrrh.Amount() == 0 )

-- команда /myrrh <число>
MYRRH = 250
fire( "EVENT_CURRENCIES_CHANGED" )
check( "250 при пороге 100 — надписи нет", warning() == false )
slash( "/myrrh 300" )
check( "/myrrh 300: порог сохранён", MA.cfg.threshold == 300 and CONFIG.MyrrhAlert.ma.threshold == 300 )
check( "/myrrh 300: надпись появилась сразу", warning() == true )
check( "/myrrh 300: ответ в чат", string.find( lastChat(), "порог 300, мирры сейчас 250", 1, true ) ~= nil )
slash( "/myrrh много" )
check( "не число: порог не меняется, есть подсказка", MA.cfg.threshold == 300 and string.find( lastChat(), "число", 1, true ) ~= nil )
local n = #CHAT
slash( "/myrrhх 5" )
slash( "/baa" )
check( "чужие команды аддон не трогает", #CHAT == n and MA.cfg.threshold == 300 )
slash( "/myrrh 12.9" )
check( "дробный порог округляется вниз", MA.cfg.threshold == 12 )
slash( "/myrrh -5" )
check( "отрицательный порог — это 0", MA.cfg.threshold == 0 )
check( "порог 0: в ответе сказано, что выключено", string.find( lastChat(), "выключено", 1, true ) ~= nil )
MYRRH = nil
fire( "EVENT_CURRENCIES_CHANGED" )
check( "порог 0 выключает предупреждение", warning() == false )

-- окно настроек
local win, edit, focus = WIDGETS.MAWindow, WIDGETS.ThresholdEdit, WIDGETS.ThresholdFocus
local function typeIn( text ) edit:SetFocus( true ) edit.text = text end
check( "окно перетаскивается за шапку", DND.movable == win and DND.reacting == WIDGETS.Header )
check( "до команды окно закрыто", win.visible == false )
n = #CHAT
MYRRH = 250
slash( "/MYRRH" )
check( "/myrrh открывает окно и ничего не пишет в чат", win.visible == true and #CHAT == n )
check( "в окне — порог и количество мирры", edit.text == "0" and WIDGETS.AmountText.val == "Сейчас мирры: 250" )

typeIn( "300" )
check( "при вводе поле подсвечено, порог ещё прежний", focus.visible == true and MA.cfg.threshold == 0 )
setMyrrh( 260 )
check( "пока игрок печатает, его текст не затирается", edit.text == "300" and WIDGETS.AmountText.val == "Сейчас мирры: 260" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "Enter: порог принят и сохранён", MA.cfg.threshold == 300 and CONFIG.MyrrhAlert.ma.threshold == 300 )
check( "Enter: надпись появилась, подсветка снята", warning() == true and focus.visible == false and edit.focused == false )

typeIn( "50" )
REACTIONS.ma_threshold_esc( { widget = edit } )
check( "Esc: порог прежний, в поле снова он", MA.cfg.threshold == 300 and edit.text == "300" and focus.visible == false )

typeIn( "200" )
REACTIONS.ma_apply( {} )
check( "кнопка «Применить»: порог принят", MA.cfg.threshold == 200 and warning() == false and edit.focused == false )

typeIn( "150" )
edit:SetFocus( false )
check( "потеря фокуса: порог принят", MA.cfg.threshold == 150 and edit.text == "150" )

typeIn( "" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "пустое поле: порог не меняется, в поле прежний", MA.cfg.threshold == 150 and edit.text == "150" )

-- мирры бывают сотни миллионов: порог и количество такого размера работают, в окне разряды разделены
setMyrrh( 497523688 )
typeIn( "500000000" )
REACTIONS.ma_threshold_enter( { widget = edit } )
check( "порог 500 млн принят, в поле — цифры без разделителей", MA.cfg.threshold == 500000000 and edit.text == "500000000" )
check( "497 523 688 < 500 млн — надпись видна", warning() == true )
check( "количество мирры — с пробелами между разрядами", WIDGETS.AmountText.val == "Сейчас мирры: 497 523 688" )
check( "разделение разрядов", MA.Num( 0 ) == "0" and MA.Num( 999 ) == "999" and MA.Num( 1000 ) == "1 000" and MA.Num( 9999999999 ) == "9 999 999 999" )
slash( "/myrrh 99999999999" )
check( "слишком большой порог обрезается до 9999999999", MA.cfg.threshold == 9999999999 and edit.text == "9999999999" )

typeIn( "77" )
REACTIONS.ma_close( {} )
check( "закрытие окна отбрасывает недописанное", win.visible == false and MA.cfg.threshold == 9999999999 and edit.text == "9999999999" and edit.focused == false )

-- настройки: чужие ключи секции не теряются, испорченный порог чинится
CONFIG.MyrrhAlert = { other = "keep", ma = { threshold = "сломано" } }
MA.Cfg.Load()
check( "испорченный порог — берём 100", MA.cfg.threshold == 100 )
MA.Cfg.SetThreshold( 40 )
check( "запись не теряет чужие ключи", CONFIG.MyrrhAlert.other == "keep" and CONFIG.MyrrhAlert.ma.threshold == 40 )

print( string.format( "тестов: %d, провалов: %d", passed + failed, failed ) )
os.exit( failed == 0 and 0 or 1 )

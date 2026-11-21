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

-- команда /myrrh
MYRRH = 250
fire( "EVENT_CURRENCIES_CHANGED" )
check( "250 при пороге 100 — надписи нет", warning() == false )
slash( "/myrrh 300" )
check( "/myrrh 300: порог сохранён", MA.cfg.threshold == 300 and CONFIG.MyrrhAlert.ma.threshold == 300 )
check( "/myrrh 300: надпись появилась сразу", warning() == true )
check( "/myrrh 300: ответ в чат", string.find( lastChat(), "порог 300, мирры сейчас 250", 1, true ) ~= nil )

local n = #CHAT
slash( "/MYRRH" )
check( "/myrrh без числа: только отчёт", #CHAT == n + 1 and MA.cfg.threshold == 300 )
slash( "/myrrh много" )
check( "не число: порог не меняется, есть подсказка", MA.cfg.threshold == 300 and string.find( lastChat(), "число", 1, true ) ~= nil )
n = #CHAT
slash( "/myrrhх 5" )
slash( "/baa" )
check( "чужие команды аддон не трогает", #CHAT == n and MA.cfg.threshold == 300 )
slash( "/myrrh 12.9" )
check( "дробный порог округляется вниз", MA.cfg.threshold == 12 )
slash( "/myrrh -5" )
check( "отрицательный порог — это 0", MA.cfg.threshold == 0 )
MYRRH = nil
fire( "EVENT_CURRENCIES_CHANGED" )
check( "порог 0 выключает предупреждение", warning() == false )
check( "порог 0: в отчёте сказано, что выключено", string.find( lastChat(), "выключено", 1, true ) ~= nil )

-- настройки: чужие ключи секции не теряются, испорченный порог чинится
CONFIG.MyrrhAlert = { other = "keep", ma = { threshold = "сломано" } }
MA.Cfg.Load()
check( "испорченный порог — берём 100", MA.cfg.threshold == 100 )
MA.Cfg.SetThreshold( 40 )
check( "запись не теряет чужие ключи", CONFIG.MyrrhAlert.other == "keep" and CONFIG.MyrrhAlert.ma.threshold == 40 )

print( string.format( "тестов: %d, провалов: %d", passed + failed, failed ) )
os.exit( failed == 0 and 0 or 1 )

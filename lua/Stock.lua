--------------------------------------------------------------------------------
-- MyrrhAlert / Stock.lua
-- Логика без интерфейса: сколько у персонажа мирры, мана-батарей и модулей памяти
-- и хватает ли их.
--   мирра         — ценности, внутреннее имя "myrrh" (документация: avatar.GetCurrencyId)
--   модули памяти — ценности; внутреннего имени в документации нет, находим по названию
--   мана-батареи  — предметы в сумке; находим по названию, складываем все стопки
-- Количества хранятся в amounts и перечитываются только по событиям игры.
--------------------------------------------------------------------------------
MA.Stock = {}
local Stock = MA.Stock

local MYRRH = "myrrh"
local memorySys = nil      -- внутреннее имя модулей памяти; узнаём, когда находим их среди ценностей
local amounts = { myrrh = 0, battery = 0, memory = 0 }

local function Has( s, part )
	return string.find( s, part, 1, true ) ~= nil
end

-- Названия сравниваем без первой буквы слова: так регистр не важен
-- («Мана-батарея», «Батарея маны», «Модуль памяти»).
local function IsBatteryName( name )
	return Has( name, "атаре" ) and ( Has( name, "ан" ) )
end

local function IsMemoryName( name )
	return Has( name, "одул" ) and Has( name, "амят" )
end

--------------------------------------------------------------------------------
-- Ценности: мирра и модули памяти
--------------------------------------------------------------------------------
local function CurrencyAmount( sysName )
	local id = avatar.GetCurrencyId( sysName )
	-- Ожидаем: пока у персонажа нет ни одной единицы валюты, игра её не находит (nil) — считаем, что её 0
	if not id then return 0 end
	local info = avatar.GetCurrencyValue( id )
	-- Ожидаем: игра может не отдать количество (nil по документации) — считаем, что валюты 0
	if not info then return 0 end
	return info.value
end

-- Найти модули памяти среди ценностей персонажа и запомнить их внутреннее имя
local function FindMemory()
	local ids = avatar.GetCurrencies()
	-- Ожидаем: сразу после входа список ценностей может быть ещё не готов (nil) — найдём по EVENT_CURRENCIES_CHANGED
	if type( ids ) ~= "table" then return end
	for _, id in pairs( ids ) do
		local info = id:GetInfo()
		-- Ожидаем: игра может не отдать описание валюты (nil) — такую пропускаем
		if info and IsMemoryName( MA.S( info.name ) ) then
			memorySys = info.sysName
			return
		end
	end
end

function Stock.ReadCurrencies()
	amounts.myrrh = CurrencyAmount( MYRRH )
	-- Ожидаем: модулей памяти у персонажа ещё не было, и их имя неизвестно — ищем среди ценностей; не нашли — их 0
	if not memorySys then FindMemory() end
	amounts.memory = memorySys and CurrencyAmount( memorySys ) or 0
end

-- Это мирра или модули памяти? (sysName из EVENT_CURRENCY_VALUE_CHANGED)
function Stock.IsOurCurrency( sysName )
	return sysName == MYRRH or ( memorySys ~= nil and sysName == memorySys )
end

--------------------------------------------------------------------------------
-- Сумка: мана-батареи
--------------------------------------------------------------------------------
function Stock.ReadBag()
	local items = containerLib.GetItems( ITEM_CONT_INVENTORY )
	-- Ожидаем: сумка может быть ещё не загружена (nil) — батарей 0, пересчитаем по событию сумки
	if type( items ) ~= "table" then
		amounts.battery = 0
		return
	end
	local total = 0
	-- в таблице сумки бывают пустые слоты, поэтому pairs, а не обход по индексам
	for _, itemId in pairs( items ) do
		local info = itemLib.GetItemInfo( itemId )
		-- Ожидаем: предмет мог исчезнуть из сумки, пока мы её читаем (nil) — пропускаем
		if info and IsBatteryName( MA.S( info.name ) ) then
			local stack = itemLib.GetStackInfo( itemId )
			-- Ожидаем: у предмета не в стопке GetStackInfo возвращает nil — тогда он один
			total = total + ( stack and stack.count or 1 )
		end
	end
	amounts.battery = total
end

--------------------------------------------------------------------------------
function Stock.Amount( key )
	return amounts[ key ]
end

-- Запаса key меньше порога? Порог 0 выключает предупреждение.
function Stock.IsLow( key )
	local threshold = MA.cfg[ key ]
	return threshold > 0 and amounts[ key ] < threshold
end

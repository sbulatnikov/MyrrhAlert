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
local memoryId = nil       -- CurrencyId модулей памяти; узнаём, когда находим их среди ценностей
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
local function CurrencyAmount( id )
	-- Ожидаем: пока у персонажа нет ни одной единицы валюты, игра её не находит (id = nil) — считаем, что её 0
	if not id then return 0 end
	local info = avatar.GetCurrencyValue( id )
	-- Ожидаем: игра может не отдать количество (nil по документации) — считаем, что валюты 0
	if not info then return 0 end
	return info.value
end

-- Модули памяти в списке валют (таблица игры с индексами от 0); nil, если их там нет
local function MemoryIn( ids )
	-- Ожидаем: сразу после входа список может быть ещё не готов (nil) — найдём по EVENT_CURRENCIES_CHANGED
	if type( ids ) ~= "table" then return nil end
	for _, id in pairs( ids ) do
		local info = id:GetInfo()
		-- Ожидаем: игра может не отдать описание валюты (nil) — такую пропускаем
		if info and IsMemoryName( MA.S( info.name ) ) then return id end
	end
	return nil
end

-- Найти модули памяти среди ценностей персонажа: в общем списке, а если там нет — по категориям ценностей
local function FindMemory()
	local id = MemoryIn( avatar.GetCurrencies() )
	if id then return id end
	local categories = avatar.GetCurrencyCategories()
	-- Ожидаем: список категорий может быть ещё не готов (nil) — найдём по EVENT_CURRENCIES_CHANGED
	if type( categories ) ~= "table" then return nil end
	for _, categoryId in pairs( categories ) do
		id = MemoryIn( avatar.GetCategoryCurrencies( categoryId ) )
		if id then return id end
	end
	return nil
end

function Stock.ReadCurrencies()
	amounts.myrrh = CurrencyAmount( avatar.GetCurrencyId( MYRRH ) )
	-- Ожидаем: модулей памяти у персонажа ещё не было — ищем их среди ценностей; не нашли — их 0
	if not memoryId then memoryId = FindMemory() end
	-- количество берём по самому CurrencyId, как и нашли: внутреннее имя для этого не нужно
	amounts.memory = CurrencyAmount( memoryId )
end

-- Это мирра или модули памяти? (параметры EVENT_CURRENCY_VALUE_CHANGED)
function Stock.IsOurCurrency( p )
	if p.sysName == MYRRH then return true end
	if memoryId then return p.id:IsEqual( memoryId ) end
	-- Ожидаем: модули памяти ещё не найдены, а изменилась как раз их валюта — узнаём её по названию
	local info = p.id:GetInfo()
	return info ~= nil and IsMemoryName( MA.S( info.name ) )
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

----------------------------------------------------------------------------
--	函数式编程工具 —LINQ 风格集合操作函数
--	独立于 Dota API，可在任何 Lua 项目中复用
----------------------------------------------------------------------------
local Func = {}

-- ========== 魔法表机制（支持方法链式调用）==========

local magicTable = {}
local function NewTable()
    local a = {}
    setmetatable(a, magicTable)
    return a
end
magicTable.__index = magicTable

Func.NewTable = NewTable

-- 生成一个从 min 到 max、步长为 step 的数字范围表
function Func.Range(min, max, step)
    if step == nil then
        step = 1
    end
    local g = NewTable()
    for i = min, max, step do
        table.insert(g, i)
    end
    return g
end

-- 判断表中是否包含指定值
function Func.Contains(tb, value, equals)
    equals = equals or function(a, b)
        return a == b
    end
    for _, v in ipairs(tb) do
        if equals(v, value) then
            return true
        end
    end
    return false
end

-- 判断表中是否包含指定 key
function Func.ContainsKey(tb, key, equals)
    equals = equals or function(a, b)
        return a == b
    end
    for k, _ in pairs(tb) do
        if equals(key, k) then
            return true
        end
    end
    return false
end

-- 获取表的所有键
function Func.Keys(tb)
    local g = NewTable()
    for k, _ in pairs(tb) do
        table.insert(g, k)
    end
    return g
end

-- 过滤表：返回所有满足 filter 条件的元素
function Func.Filter(tb, filter)
    local g = NewTable()
    for k, v in ipairs(tb) do
        if filter(v, k) then
            table.insert(g, v)
        end
    end
    return g
end

-- 反向过滤：返回所有不满足 filter 条件的元素
function Func.FilterNot(tb, filter)
    local g = NewTable()
    for k, v in ipairs(tb) do
        if not filter(v, k) then
            table.insert(g, v)
        end
    end
    return g
end

-- 计数：统计满足 filter 条件的元素数量
function Func.Count(tb, filter)
    local g = 0
    for k, v in ipairs(tb) do
        if filter == nil or filter(v, k) then
            g = g + 1
        end
    end
    return g
end

-- 过滤掉空表/nil
function Func.NonEmpty(tb)
    return Func.Filter(tb, function(t)
        return t ~= nil and #t ~= 0
    end)
end

-- 映射：对表中每个元素应用转换函数
function Func.Map(tb, transform)
    local g = NewTable()
    for k, v in ipairs(tb) do
        g[k] = transform(v)
    end
    return g
end

-- 字典映射：遍历 pairs，对每个键值对应用转换函数
function Func.MapDic(tb, transform)
    local g = NewTable()
    for k, v in pairs(tb) do
        g[k] = transform(k, v)
    end
    return g
end

-- 遍历执行：对表中每个元素执行操作
function Func.ForEach(tb, action)
    for k, v in ipairs(tb) do
        action(v, k)
    end
end

-- 任一匹配：是否有至少一个元素满足条件
function Func.Any(tb, filter)
    for k, v in ipairs(tb) do
        if filter == nil or filter(v, k) then
            return true
        end
    end
    return false
end

-- 全部匹配：是否所有元素都满足条件
function Func.All(tb, filter)
    for k, v in ipairs(tb) do
        if not filter(v, k) then
            return false
        end
    end
    return true
end

-- 聚合：从初始值开始，依次对每个元素应用聚合函数
function Func.Aggregate(seed, tb, aggregate)
    for k, v in ipairs(tb) do
        seed = aggregate(seed, v, k)
    end
    return seed
end

-- 浅拷贝表
function Func.ShallowCopy(tb)
    local g = NewTable()
    for k, v in pairs(tb) do
        g[k] = v
    end
    return g
end

-- 获取第一个满足条件的元素
function Func.First(tb, filter)
    for k, v in ipairs(tb) do
        if filter == nil or filter(v, k) then
            return v
        end
    end
end

-- 跳过前 number 个元素
function Func.Skip(tb, number)
    local g = NewTable()
    local i = 0
    for _, v in ipairs(tb) do
        i = i + 1
        if i > number then
            table.insert(g, v)
        end
    end
    return g
end

-- 取前 number 个元素
function Func.Take(tb, number)
    local g = NewTable()
    local i = 0
    for _, v in ipairs(tb) do
        i = i + 1
        if i <= number then
            table.insert(g, v)
        else
            break
        end
    end
    return g
end

-- 深拷贝表（带循环引用检测）
local function deepCopy(tb)
    local copiedTables = NewTable()
    local g = NewTable()
    table.insert(copiedTables, tb)
    for k, v in pairs(tb) do
        if type(v) ~= "table" then
            g[k] = v
        else
            if Func.Contains(copiedTables, v) then
                print("深拷贝检测到循环引用")
                return {}
            end
            g[k] = deepCopy(v)
        end
    end
    return g
end
Func.DeepCopy = deepCopy

-- 拼接多个表
function Func.Concat(a, ...)
    local g = NewTable()
    local rec
    rec = function(b, ...)
        if b == nil then
            return
        end
        for _, v in ipairs(b) do
            table.insert(g, v)
        end
        rec(...)
    end
    rec(a, ...)
    return g
end

-- 移除指定元素（返回新表）
function Func.Remove(a, b)
    local g = Func.ShallowCopy(a)
    for k, v in pairs(a) do
        if v == b then
            g[k] = nil
        end
    end
    return g
end

-- 移除所有出现在 b 中的元素
function Func.RemoveAll(a, b)
    local g = NewTable()
    for _, v in pairs(a) do
        if not Func.Contains(b, v) then
            table.insert(g, v)
        end
    end
    return g
end

-- 在开头插入元素
function Func.Prepend(a, b)
    return Func.Concat(b, a)
end

-- 分组：根据 keySelector 对集合进行分组
function Func.GroupBy(collection, keySelector, elementSelector, resultSelector, comparer)
    comparer = comparer or function(a, b)
        return a == b
    end
    resultSelector = resultSelector or function(key, value)
        return value
    end
    elementSelector = elementSelector or Func.IdentityFunction
    local keys = NewTable()
    local values = NewTable()
    for _, k in ipairs(collection) do
        local keyFound = false
        for readKeyIndex, readKey in ipairs(keys) do
            if comparer(readKey, keySelector(k)) then
                keyFound = true
                table.insert(values[readKeyIndex], elementSelector(k))
                break
            end
        end
        if not keyFound then
            table.insert(keys, keySelector(k))
            table.insert(values, { elementSelector(k) })
        end
    end
    return Func.Map2(keys, values, resultSelector)
end

-- 分区：根据 filter 将表分为两个部分
function Func.Partition(tb, filter)
    local a = NewTable()
    local b = NewTable()
    for k, v in pairs(tb) do
        if filter(v, k) then
            table.insert(a, v)
        else
            table.insert(b, v)
        end
    end
    return a, b
end

-- 去重：返回表中不重复的元素
function Func.Distinct(tb, equals)
    equals = equals or function(a, b)
        return a == b
    end
    local g = NewTable()
    for _, v in pairs(tb) do
        if not Func.Contains(g, v, equals) then
            table.insert(g, v)
        end
    end
    return g
end

-- 反转 table
function Func.Reverse(tb)
    local g = NewTable()
    for i = #tb, 1, -1 do
        table.insert(g, tb[i])
    end
    return g
end

-- 获取最后一个满足条件的元素
function Func.Last(tb, filter)
    return Func.First(Func.Reverse(tb), filter)
end

-- 恒等函数
function Func.Identity(t)
    return t
end

Func.IdentityFunction = Func.Identity

-- 求最大值（可指定映射函数）
function Func.Max(tb, map)
    if #tb == 0 then
        return nil
    end
    map = map or Func.IdentityFunction
    local maxv, maxm = tb[1], map(tb[1])
    for i = 2, #tb do
        local m = map(tb[i])
        if m > maxm then
            maxm = m
            maxv = tb[i]
        end
    end
    return maxv
end

-- 求最小值（可指定映射函数）
function Func.Min(tb, map)
    if #tb == 0 then
        return nil
    end
    map = map or Func.IdentityFunction
    local maxv, maxm = tb[1], map(tb[1])
    for i = 2, #tb do
        local m = map(tb[i])
        if m < maxm then
            maxm = m
            maxv = tb[i]
        end
    end
    return maxv
end

-- 重复元素 count 次，生成新表
function Func.Repeat(element, count)
    local g = NewTable()
    for i = 1, count do
        table.insert(g, element)
    end
    return g
end

Func.Select = Func.Map
Func.Where = Func.Filter

-- 展平映射
function Func.SelectMany(tb, map, filter)
    local g = NewTable()
    for _, source in ipairs(tb) do
        local collection = map(source)
        for index, value in ipairs(collection) do
            if filter == nil or filter(value, index) then
                table.insert(g, value)
            end
        end
    end
    return g
end

-- 跳过末尾 number 个元素
function Func.SkipLast(tb, number)
    return Func.Skip(Func.Reverse(tb), number)
end

-- 替换满足条件的元素
function Func.Replace(tb, filter, map)
    local g = NewTable()
    for k, v in ipairs(tb) do
        if filter(v, k) then
            table.insert(g, map(v, k))
        else
            table.insert(g, v)
        end
    end
    return g
end

-- 查找元素索引
function Func.IndexOf(tb, filter)
    for k, v in ipairs(tb) do
        if type(filter) == "function" then
            if filter(v, k) then
                return k
            end
        elseif filter ~= nil then
            if v == filter then
                return k
            end
        end
    end
    return -1
end

-- 拉链合并两个表
function Func.Zip2(tb1, tb2, map)
    if map == nil then
        map = function(a, b)
            return { a, b }
        end
    end
    local g = NewTable()
    for i = 1, #tb1 do
        table.insert(g, map(tb1[i], tb2[i]))
    end
    return g
end

-- 双表遍历
function Func.ForEach2(tb1, tb2, func)
    for i = 1, #tb1 do
        func(tb1[i], tb2[i])
    end
end

-- 双表映射
function Func.Map2(tb1, tb2, map)
    local g = NewTable()
    for i = 1, #tb1 do
        table.insert(g, map(tb1[i], tb2[i], i))
    end
    return g
end

-- 双表过滤
function Func.Filter2(tb1, tb2, filter, map)
    if map == nil then
        map = function(a, b, c)
            return { a, b, c }
        end
    end
    local g = NewTable()
    for i = 1, #tb1 do
        if filter(tb1[i], tb2[i], i) then
            table.insert(map(tb1[i], tb2[i], i))
        end
    end
    return g
end

-- 慢速排序
function Func.SlowSort(tb, sort)
    local g = Func.ShallowCopy(tb)
    local len = #g
    if sort ~= nil then
        for i = 1, len - 1 do
            for j = i + 1, len do
                if sort(g[i], g[j]) > 0 then
                    g[i], g[j] = g[j], g[i]
                end
            end
        end
    else
        for i = 1, len - 1 do
            for j = i + 1, len do
                if g[i] > g[j] then
                    g[i], g[j] = g[j], g[i]
                end
            end
        end
    end
    return g
end

-- 归并排序
function Func.MergeSort(tb, sort)
    if sort == nil then
        sort = function(a, b)
            return a - b
        end
    end
    local function Merge(a, b)
        local g = NewTable()
        local aLen = #a
        local bLen = #b
        local i = 1
        local j = 1
        while i <= aLen and j <= bLen do
            if sort(a[i], b[j]) > 0 then
                table.insert(g, b[j])
                j = j + 1
            else
                table.insert(g, a[i])
                i = i + 1
            end
        end
        if i <= aLen then
            for _ = i, aLen do
                table.insert(g, a[i])
            end
        end
        if j <= bLen then
            for _ = j, bLen do
                table.insert(g, b[j])
            end
        end
        return g
    end
    local function SortRec(tab)
        local tableLength = #tab
        if tableLength == 1 then
            return tab
        end
        local left = SortRec(Func.Take(tab, tableLength / 2))
        local right = SortRec(Func.Skip(tab, tableLength / 2))
        return Merge(left, right)
    end
    return SortRec(tb)
end

Func.Sort = Func.SlowSort

-- 按映射值从大到小排序
function Func.SortByMaxFirst(tb, map)
    map = map or function(a, b)
        return b - a
    end
    return Func.Sort(tb, function(a, b)
        return map(b) - map(a)
    end)
end

-- 按映射值从小到大排序
function Func.SortByMinFirst(tb, map)
    map = map or function(a, b)
        return a - b
    end
    return Func.Sort(tb, function(a, b)
        return map(a) - map(b)
    end)
end

-- 原地移除元素
function Func.Remove_Modify(tb, item)
    local filter = item
    if type(item) ~= "function" then
        filter = function(t)
            return t == item
        end
    end
    local i = 1
    local d = #tb
    while i <= d do
        if filter(tb[i]) then
            table.remove(tb, i)
            d = d - 1
        else
            i = i + 1
        end
    end
end

-- 在指定元素后插入
function Func.InsertAfter_Modify(tb, item, after)
    if after == nil then
        table.insert(tb, item)
    else
        for index, value in ipairs(tb) do
            if item == value then
                table.insert(tb, index)
                return
            end
        end
        table.insert(tb, item)
    end
end

-- 解包表为多返回值
function Func.Unpack(tb)
    local index = #tb
    local function rec(...)
        if index >= 1 then
            index = index - 1
            return rec(tb[index + 1], ...)
        else
            return ...
        end
    end
    return rec()
end

-- 如果是表则解包，否则返回原值
function Func.UnpackIfTable(p)
    if type(p) == "table" then
        return Func.Unpack(p)
    else
        return p
    end
end

-- 对表执行操作后返回自身
function Func.Also(tb, block)
    block(tb)
    return tb
end

-- 对表执行操作后返回结果
function Func.Let(tb, block)
    return block(tb)
end

-- ========== 数学工具函数 ==========

-- 求多项式系数对应的函数在区间 [min, max] 上的最小值
-- coefficients = {常数项系数, 一次项系数, 二次项系数, ...}
function Func.MinValue(coefficients, min, max)
    max = max or 10000
    min = min or -10000
    local function Differential(coeffs)
        local g = {}
        for index, coefficient in pairs(coeffs) do
            g[index - 1] = coefficient * index
        end
        return g
    end
    local function Y(coeffs, x)
        local g = 0
        for index, coefficient in pairs(coeffs) do
            g = g + coefficient * x ^ index
        end
        return g
    end

    local differential = Differential(coefficients)
    if differential[1] ~= nil and differential[1] ~= 0 then
        local zeroPoint = -differential[0] / differential[1]
        if Y(coefficients, zeroPoint + 0.1) > 0 then
            if zeroPoint > max then
                return Y(coefficients, max)
            elseif zeroPoint < min then
                return Y(coefficients, min)
            else
                return Y(coefficients, zeroPoint)
            end
        else
            if zeroPoint > max then
                return Y(coefficients, min)
            elseif zeroPoint < min then
                return Y(coefficients, max)
            else
                local val1 = Y(coefficients, min)
                local val2 = Y(coefficients, max)
                return math.min(val1, val2)
            end
        end
    else
        return Y(coefficients, min)
    end
end

-- 求多项式系数对应的函数在区间 [min, max] 上的最大值
function Func.MaxValue(coefficients, min, max)
    local g = {}
    for index, coefficient in coefficients do
        g[index] = -coefficient
    end
    return Func.MinValue(g, -max, -min)
end

-- 反转键值对
function Func.ReverseTable(tb)
    local g = {}
    for k, v in pairs(tb) do
        if type(v) == "number" or type(v) == "string" then
            g[v] = k
        end
    end
    return g
end

-- 计算两个物体的碰撞信息（位置/速度）
-- TODO: 此函数未完成，暂不实现
-- function Func.GetCollapseInfo(obj1, obj2, timeLimit)
-- end

-- ========== 设置魔法表（支持链式调用）==========

do
    local mt = magicTable
    for k, v in pairs(Func) do
        mt[k] = function(...)
            return v(...)
        end
    end
    for functionName, func in pairs(table) do
        mt[functionName] = func
    end
end

return Func

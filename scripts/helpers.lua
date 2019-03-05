local this = {}
local util = scripts.util
local metatables = scripts.metatables

local type, rawget, rawset, pairs, ipairs = type, rawget, rawset, pairs, ipairs

metatables.helpers = {
    __index = function(t, k)
        return this[k] or rawget(t, "__on")[k]
    end,
    __newindex = function(t, k, v)
        rawget(t, "__on")[k] = v
    end,
}

function this.on(obj)
    if type(obj) == "table" and not obj.__self and rawget(obj, "__on") then -- reapply metatable
        return metatables.use(obj, "helpers")
    else                                                         -- new metatable
        return metatables.use({ __on = obj }, "helpers")
    end
end
local on = this.on

function this:toPlain()
    return rawget(self, "__on")
end

local conditions = {
    ["nil"] = function(obj) return obj == nil end,
    ["empty"] = util.isEmpty,
    ["filled"] = util.isFilled,
    ["valid"] = util.isValid,
    ["valid stack"] = util.isValidStack,
    ["valid player"] = util.isValidPlayer,
    ["ignored entity"] = util.isIgnoredEntity,

    -- Custom type conditions
    ["crafting machine"] = util.isCraftingMachine,
}

local function applyNot(notModeActive, value)
    if notModeActive then
        return not value
    else
        return value
    end
end

function this:is(...)
    local args = {...}
    local obj = rawget(self, "__on")
    local notModeActive = false
    local checkMode = "condition"
    local result = true

    for _,condition in ipairs(args) do

        if condition == "not" then
            notModeActive = not notModeActive                -- toggle notModeActive

        elseif type(condition) == "table" then               -- custom field check
            local value = obj
            for _,key in ipairs(condition) do
                value = value[key]
            end

            local nestedIs = condition.is       -- nested Is check on custom field
            if nestedIs ~= nil then 
                if type(nestedIs) == "table" then
                    result = result and applyNot(notModeActive, on(nestedIs):is(unpack(nestedIs)))
                else
                    result = result and applyNot(notModeActive, on(nestedIs):is(nestedIs))
                end
            end
        
            local nestedIsnot = condition.isnot -- nested Isnot check on custom field
            if nestedIsnot ~= nil then 
                if type(nestedIsnot) == "table" then
                    result = result and applyNot(notModeActive, on(nestedIsnot):isnot(unpack(nestedIsnot)))
                else
                    result = result and applyNot(notModeActive, on(nestedIsnot):isnot(nestedIsnot))
                end
            end

            if condition.is == nil and condition.isnot == nil then -- simple if value then... check on custom field
                result = result and applyNot(notModeActive, value)
            end

        elseif conditions[condition] then       -- normal condition check
            result = result and applyNot(notModeActive, conditions[condition](obj)) 

        else                                    -- direct value check
            result = result and applyNot(notModeActive, obj == condition) 
        end

         -- early return if condition not met
        if not result then return result end
    end

    return result
end

function this:isnot(...)
    return self:is("not", ...)
end

function this:has(condition, ...)
    return self:is(condition, {...})
end

function this:hasnot(condition, ...)
    return self:isnot(condition, {...})
end

function this:each(func)
    local obj = rawget(self, "__on")
    local iter = metatables.uses(obj, "entityAsIndex") and util.epairs or pairs

    for k,v in iter(obj) do
        func(k, v)
    end

    return self
end

function this:where(...)
    local args = {...}
    local func = args[#args]
    local obj = rawget(self, "__on")
    local iter = metatables.uses(obj, "entityAsIndex") and util.epairs or pairs

    if #args > 1 and type(func) == "function" then -- if user passed anonymouse function to where() directly (as last argument)
        args[#args] = nil

        for k,v in iter(obj) do
            if on(v or k):is(unpack(args)) then
                func(k, v)
            end 
        end

        return self

    else  -- else only filter out results
        local result = {}
            
        for k,v in iter(obj) do
            if on(v or k):is(...) then
                result[k] = v
            end
        end

        return on(result)
    end
end

function this:unless(...)
    return self:where("not", ...) 
end

function this:wherehas(condition, ...)
    local args = {...}
    local func = args[#args]

    if #args > 1 and type(func) == "function" then
        args[#args] = nil
        return self:where(condition, args, func) 
    else
        return self:where(condition, args) 
    end
end

function this:unlesshas(condition, ...)
    local args = {...}
    local func = args[#args]

    if #args > 1 and type(func) == "function" then
        args[#args] = nil
        return self:unless(condition, args, func) 
    else
        return self:unless(condition, args) 
    end
end

function this:get(...)
    local args = {...}
    local value = rawget(self, "__on")

    for _,key in ipairs(args) do
        if not value[key] then error(false, 2) end
        value = value[key]
    end

    return on(value)
end

function this:set(values)
    local obj = rawget(self, "__on")

    for k,v in pairs(values) do
        obj[k] = v    
    end

    return self
end

return this
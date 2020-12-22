local ast = require 'parser.ast'

-- HACK: Transform Synchrony enum declarations to allow treating them as passthrough functions (Lua.runtime.special)
local substitutes = {
    ["enum%.%a[%w_]*%s*%{"] = function (str)
        return str:gsub("%.", "_")
    end,
}

return function (self, lua, mode, version, options)
    for k, v in pairs(substitutes) do
        lua = lua:gsub(k, v)
    end
    local errs  = {}
    local diags = {}
    local comms = {}
    local state = {
        version = version,
        lua = lua,
        root = {},
        errs = errs,
        diags = diags,
        comms = comms,
        options = options or {},
        pushError = function (err)
            if err.finish < err.start then
                err.finish = err.start
            end
            local last = errs[#errs]
            if last then
                if last.start <= err.start and last.finish >= err.finish then
                    return
                end
            end
            err.level = err.level or 'error'
            errs[#errs+1] = err
            return err
        end,
        pushDiag = function (code, info)
            if not diags[code] then
                diags[code] = {}
            end
            diags[code][#diags[code]+1] = info
        end,
        pushComment = function (comment)
            comms[#comms+1] = comment
        end
    }
    local clock = os.clock()
    ast.init(state)
    local suc, res, err = xpcall(self.grammar, debug.traceback, self, lua, mode)
    ast.close()
    if not suc then
        return nil, res
    end
    if not res and err then
        state.pushError(err)
    end
    state.ast = res
    state.parseClock = os.clock() - clock
    return state
end

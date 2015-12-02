-- Copyright (C) 2015 Xiaojie Liu (jie123108@163.com).
-- lua-resty-bloomd -  Is a ngx_lua client library to interface with bloomd servers
-- https://github.com/armon/bloomd

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local ok, clear_tab = pcall(require, "table.clear")
if not ok then
    clear_tab = function(tab) for k, _ in pairs(tab) do tab[k] = nil end end
end

local _M = new_tab(0, 2)

_M._VERSION = '0.01'

local function split_by_space(str)
    local result = {}
    for match in string.gmatch(str, "[^ ]+") do
        table.insert(result, match);
    end
    return result
end

local mt = { __index = _M }

function _M:new(host, port, timeout)
    host = host or "127.0.0.1"
    port = port or 8673
    return setmetatable({host=host, port=port, timeout=timeout}, mt)
end

function _M:_connect()
    assert(self.sock == nil, "self.sock is not nil")
    local sock = ngx.socket.tcp()
    sock:settimeout(self.timeout)
    local ok, err = sock:connect(self.host, self.port)
    if not ok then
        sock:close()
        return nil, err
    end
    self.sock = sock 
    return ok, err
end

function _M:_setkeepalive()
    if self.sock then
        self.sock:setkeepalive()
        self.sock = nil
    end
end

function _M:_request(command, endval)
    assert(self.sock ~= nil, "socket not inited")
    assert(command ~= nil, "cmd is nil")
    local n, err = self.sock:send(command .. "\n")
    if err then
        return nil, err
    end
    if endval == nil then
        local line, err, partial = self.sock:receive('*l')
        return line, err, partial
    else
        local lines = {}
        for i=1, 10240 do 
            local line, err, partial = self.sock:receive('*l')            
            if err then
                table.insert(lines, partial)
                return nil, err, table.concat(lines, '\n') 
            end
            table.insert(lines, line)
            if line == endval then
                break
            end
        end
        return lines, err
    end
end

function _M:_request_once(cmd, endval)
    local ok, err = self:_connect()
    if not ok then
        return ok, err
    end 
    local line, err, partial = self:_request(cmd, endval)
    self:_setkeepalive()
    return line, err
end

function _M:create(filter_name, capacity, prob, in_memory)
    assert(filter_name ~= nil, "filter_name is nil")
    
    local cmds = {"create " .. filter_name}
    table.insert(cmds, cmd)

    if capacity and type(capacity) == 'number' then
        table.insert(cmds, "capacity=" .. tostring(capacity))
    end
    if prob and type(prob) == 'number' then
        table.insert(cmds, "prob=" .. tostring(prob))
    end
    if in_memory == 0 then
        in_memory = false
    end
    if in_memory then
        table.insert(cmds, "in_memory=1")
    end

    local cmd = table.concat(cmds, " ")
    
    local line, err = self:_request_once(cmd)
    
    if line == nil then
        return false, err
    end
    if line == "Done" or line == "Exists" then
        return true, line
    else
        return false, line 
    end
end

function _M:_do_command1(cmd)
    assert(cmd ~= nil, "cmd is nil")
    local line, err = self:_request_once(cmd)
    if line == nil then
        return false, err
    end
    if line == "Done" then
        return true, line
    else
        return false, line 
    end
end

function _M:drop(filter_name)
    assert(filter_name ~= nil, "filter_name is nil")
    local cmd = "drop " .. filter_name
    return self:_do_command1(cmd)
end 

function _M:close(filter_name)
    assert(filter_name ~= nil, "filter_name is nil")
    local cmd = "close " .. filter_name
    return self:_do_command1(cmd)
end 

function _M:clear(filter_name)
    assert(filter_name ~= nil, "filter_name is nil")
    local cmd = "clear " .. filter_name
    return self:_do_command1(cmd)
end 

function _M:flush(filter_name)
    assert(filter_name ~= nil, "filter_name is nil")
    local cmd = "flush " .. filter_name
    return self:_do_command1(cmd)
end 


function _M:_do_command2(cmd)
    assert(cmd ~= nil, "cmd is nil")
    local line, err = self:_request_once(cmd)
    if line == nil then
        return false, err
    end
    if line == "Yes" or line == "No" then
        return true, line
    else
        return false, line 
    end
end

function _M:check(filter_name, key)
    assert(filter_name ~= nil, "filter_name is nil")
    assert(key ~= nil, "key is nil")
    local cmd = "c " .. filter_name .. " " .. tostring(key)
    return self:_do_command2(cmd)
end

function _M:set(filter_name, key)
    assert(filter_name ~= nil, "filter_name is nil")
    assert(key ~= nil, "key is nil")
    local cmd = "s " .. filter_name .. " " .. tostring(key)
    return self:_do_command2(cmd)
end

function _M:_do_command_multi(cmd)
    assert(cmd ~= nil, "cmd is nil")
    local line, err = self:_request_once(cmd)
    if line == nil then
        return false, err
    end
    if line == "Filter does not exist" then
        return false, line 
    else
        local result = split_by_space(line)
        return true, result
    end
end

function _M:checks(filter_name, keys)
    assert(filter_name ~= nil, "filter_name is nil")
    assert(type(keys) == 'table', "keys must be a 'table'")
    local cmd = "m " .. filter_name .. " " .. table.concat(keys, " ")
    return self:_do_command_multi(cmd)
end

function _M:sets(filter_name, keys)
    assert(filter_name ~= nil, "filter_name is nil")
    assert(type(keys) == 'table', "keys must be a 'table'")
    local cmd = "b " .. filter_name .. " " .. table.concat(keys, " ")
    return self:_do_command_multi(cmd)
end

function _M:_do_command_list(cmd)
    assert(cmd ~= nil, "cmd is nil")
    local lines, err = self:_request_once(cmd, "END")
    if lines == nil then
        return false, err
    end
    assert(type(lines) == 'table')
    local list = {}
    for _,line in ipairs(lines) do
        if line ~= 'START' and line ~= 'END' then
            table.insert(list, line)
        end
    end
    return true, list
end

function _M:info(filter_name)
    assert(filter_name ~= nil, "filter_name is nil")
    local cmd = "info " .. filter_name
    local ok, list = self:_do_command_list(cmd)
    if not ok then
        return ok, list 
    end
    local infos = {} 
    for _, line in ipairs(list) do 
        local item = split_by_space(line)
        if #item == 2 then
            infos[item[1]] = tonumber(item[2])
        else
            ngx.log(ngx.ERR, "invalid line [", line, "]")
        end
    end
    return true, infos
end

function _M:list(prefix)
    local cmd = "list"
    if prefix then
        cmd = cmd .. " " .. prefix
    end
    local ok, list = self:_do_command_list(cmd)
    if not ok then
        return ok, list 
    end
    local filters = {}
    for _, line in ipairs(list) do 
        local item = split_by_space(line)
        if #item == 5 then
            -- filter_name probability  storage capacity size
            local filter_info = {}
            filter_info['name'] = item[1]
            filter_info['probability'] = tonumber(item[2])
            filter_info['storage'] = tonumber(item[3])
            filter_info['capacity'] = tonumber(item[4])
            filter_info['size'] = tonumber(item[5])

            table.insert(filters, filter_info)
        else
            ngx.log(ngx.ERR, "invalid line [", line, "]")
        end
    end
    return true, filters
end

return _M

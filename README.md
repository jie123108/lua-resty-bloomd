Name
====

lua-resty-bloomd -  Is a client library based on ngx_lua to interface with bloomd servers(https://github.com/armon/bloomd)

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [drop](#drop)
    * [close](#close)
    * [clear](#clear)
    * [check](#check)
    * [checks](#checks)
    * [set](#set)
    * [sets](#sets)
    * [info](#info)
    * [flush](#flush)
* [Installation](#installation)
* [Authors](#authors)
* [Copyright and License](#copyright-and-license)

Status
======

This library is production ready.

Synopsis
========
```lua
    lua_package_path "/path/to/lua-resty-bloomd/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
            local bloomd = require("resty.bloomd")
            
            local function debug(name, ok, err)
            	if type(err) == 'table' then
            		local t = {}
            		for k, v in pairs(err) do 
            			table.insert(t, k .. ":" .. tostring(v))
            		end
            		err = table.concat(t, ",")
            	end
            	ngx.say(string.format("%15s -- ok: %5s, err: %s", name, tostring(ok), tostring(err)))
            end
            -- create a new instance and connect to the bloomd(127.0.0.1:8673)
            local filter_obj = bloomd:new("127.0.0.1", 8673, 2000)
            local function test_main()
            	local filter_name = "my_filter"
            	local capacity = 100001
            	local probability = 0.001
            	-- create a filter named filter_name
            	local ok, err = filter_obj:create(filter_name, capacity, probability)
            	debug("create-new", ok, err)
            	assert(ok == true)
            	-- assert(err == "Done", "err ~= 'Done'")
            
            	-- create a filter, the name is exist
            	local ok, err = filter_obj:create(filter_name, capacity, probability)
            	debug("create-exist", ok, err)
            	assert(ok == true)
            	assert(err == "Exists")
            
            	-- set a key, New
            	local ok, err = filter_obj:set(filter_name, 'my_key')
            	debug("set-new", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            	-- set a key, Exist
            	local ok, err = filter_obj:set(filter_name, 'my_key')
            	debug("set-exist", ok, err)
            	assert(ok==true)
            	assert(err == "No")
            
            	-- check a key, Exist
            	local ok, err = filter_obj:check(filter_name, 'my_key')
            	debug("check-exist", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            	-- check a key, Not Exist
            	local ok, err = filter_obj:check(filter_name, 'this_key_not_exist')
            	debug("check-not-exist", ok, err)
            	assert(ok==true)
            	assert(err == "No")
            
            	-- flush a filter
            	local ok, err = filter_obj:flush(filter_name)
            	debug("flush", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	-- close a bloom filter
            	local ok, err = filter_obj:close(filter_name)
            	debug("close", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	-- check a key, Exist
            	local ok, err = filter_obj:check(filter_name, 'my_key')
            	debug("check-exist", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            
            	filter_obj:create("my_filter3", capacity, 0.001)
            	-- list all filter
            	local ok, filters = filter_obj:list(filter_name)
            	debug("list", ok, filters)
            	assert(ok==true)
            	assert(type(filters)=='table' and #filters==2)
            	for _,filter in ipairs(filters) do 
            		if filter.name == filter_name then 
            			assert(filter.size == 1)
            		end		
            	end
            	filter_obj:drop('my_filter3')
            
            	-- Set many items in a filter at once(bulk command)
            	local ok, status = filter_obj:sets(filter_name, {"a", "b", "c"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("sets", ok, err)
            	assert(err == "Yes Yes Yes")
            
            	local ok, status = filter_obj:sets(filter_name, {"a", "b", "d"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("sets", ok, err)
            	assert(err == "No No Yes")
            
            	-- Checks if a list of keys are in a filter
            	local ok, status = filter_obj:checks(filter_name, {"a", "x", "c", "d", "e"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("checks", ok, err)
            	assert(err == "Yes No Yes Yes No")
            
            
            	-- Gets info about a filter
            	local ok, info = filter_obj:info(filter_name)
            	debug("info", ok, info)
            	assert(ok)
            	assert(type(info)=='table')
            	assert(info.capacity == capacity)
            	assert(info.probability == probability)
            	assert(info.size == 5)
            
            	-- drop a filter
            	local ok, err = filter_obj:drop(filter_name)
            	debug("drop", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            
            	-- Test filter not exist
            	local ok, err = filter_obj:drop(filter_name)
            	debug("drop-not-exist", ok, err)
            	assert(ok==false)
            	assert(err == "Filter does not exist")
            
            
            	-- create, close and clear a bloom filter, my_filter2 is still in disk.
            	local ok, err = filter_obj:create("my_filter2", 10000*20, 0.001)
            	debug("create-new", ok, err)
            	assert(ok == true)
            	assert(err == "Done", "err ~= 'Done'")
            	local ok, err = filter_obj:close("my_filter2")
            	debug("close", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            	local ok, err = filter_obj:clear("my_filter2")
            	debug("clear", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	ngx.say("--------- all test ok --------------")
            end
            local ok, err = pcall(test_main)
            if not ok then
            	filter_obj:close("my_filter")
            	filter_obj:close("my_filter2")
            	filter_obj:close("my_filter3")
            	assert(ok, err)
            end
            ';
        }
    }
```

Methods
=======

[Back to TOC](#table-of-contents)
new
---
`syntax: filter_obj = bloomd:new(host, port, timeout)`

Create a new bloom filter object.
* IN: the `host` is the bloomd's host, default is '127.0.0.1'.
* IN: the `port` is the bloomd's port, default is 8673.
* IN: the `timeout` is the timeout time in ms, default is 5000ms.

create
---
`syntax: ok, err = filter_obj:create(filter_name, capacity, prob, in_memory)`

Create a new filter
* IN: the `filter_name` is the name of the filter, and can contain the characters a-z, A-Z, 0-9, ., _.
* IN: the `capacity` is provided the filter will be created to store at least that many items in the initial filter. default is 0.001.
* IN: the `prob` is maximum false positive probability is provided. 
* IN: the 'in_memory' is to force the filter to not be persisted to disk.

list
---
`syntax: ok, filters = filter_obj:list(filter_prefix)`

List all filters or those matching a prefix.<br/>
* OUT: the `ok` is list status.
* OUT: the `filters` is a Lua table holding all the matched filter.

```lua
for _,filter in ipairs(filters) do 
	ngx.say(filter.name, ",", filter.probability, ",", 
	        filter.storage, ",", filter.capacity, ",",filter.size)
end
```

drop
---
`syntax: ok, err = filter_obj:drop(filter_name)`

Drop a filters (Deletes from disk). On Success Returns ok:true, err:'Done'

close
---
`syntax: ok, err = filter_obj:close(filter_name)`

Closes a filter (Unmaps from memory, but still accessible). On Success Returns ok:true, err:'Done'


clear
---
`syntax: ok, err = filter_obj:clear(filter_name)`

Clears a filter from the lists (Removes memory, left on disk)


check
---
`syntax: ok, status = filter_obj:check(filter_name, key)`

Check if a key is in a filter. 
* IN: the `status` is 'Yes'(`key` is exists in filter) or 'No'(if `key` is not exists in filter).

checks
---
`syntax: ok, status = filter_obj:checks(filter_name, keys)`

Checks if a list of keys are in a filter
* IN: the `keys` is a table contains some keys.
* OUT: the `status` is a table contains each key's status('Yes' or 'No').

set
---
`syntax: ok, status = filter_obj:set(filter_name, key)`

Set an item in a filter
* OUT: the `status` is 'Yes'(`key` is success set to the filter) or 'No'(`key` is exists in the filter).


sets
---
`syntax: ok, status = filter_obj:sets(filter_name, keys)`

Set many items in a filter at once
* IN: the `keys` is a table contains some keys.
* OUT: the `status` is a table contains each key's set status('Yes' or 'No').

info
---
`syntax: ok, info = filter_obj:info(filter_name)`

Gets info about a filter
* OUT: the `info` is a table like `{in_memory:1,set_misses:3,checks:8,capacity:100001, probability:0.001,page_outs:1,size:5,check_hits:5,
storage:240141,page_ins:1,set_hits:5,check_misses:3,sets:8}`.

flush
---
`syntax: ok, err = filter_obj:flush(filter_name)`

Flush a specified filter. 

[Back to TOC](#table-of-contents)

Installation
============

You need to compile [ngx_lua](https://github.com/chaoslawful/lua-nginx-module/tags) with your Nginx.

You need to configure
the [lua_package_path](https://github.com/chaoslawful/lua-nginx-module#lua_package_path) directive to
add the path of your `lua-resty-bloomd` source tree to ngx_lua's Lua module search path, as in

    # nginx.conf
    http {
        lua_package_path "/path/to/lua-resty-bloomd/lib/?.lua;;";
        ...
    }

and then load the library in Lua:

    bloomd = require "resty.bloomd"

[Back to TOC](#table-of-contents)

Authors
=======

Xiaojie Liu <jie123108@163.com>。

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2015, by Xiaojie Liu <jie123108@163.com>

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)


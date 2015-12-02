Name
====

lua-resty-bloomd -  Is a ngx_lua client library to interface with bloomd servers(https://github.com/armon/bloomd)

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
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
            	ngx.say(string.format("%15s -- ok: %5s, err: %s", name, tostring(ok), tostring(err)))
            end
            -- create a new instance and connect to the bloomd(127.0.0.1:8673)
            local bloom = bloomd:new("127.0.0.1", 8673, 2000)
            local function test_main()
            	local capacity = 100001
            	local probability = 0.001
            	-- create a filter named 'my_filter'
            	local ok, err = bloom:create("my_filter", capacity, probability)
            	debug("create-new", ok, err)
            	assert(ok == true)
            	-- assert(err == "Done", "err ~= 'Done'")
            
            	-- create a filter, the name is exist
            	local ok, err = bloom:create("my_filter", capacity, probability)
            	debug("create-exist", ok, err)
            	assert(ok == true)
            	assert(err == "Exists")
            
            	-- set a key, New
            	local ok, err = bloom:set("my_filter", 'my_key')
            	debug("set-new", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            	-- set a key, Exist
            	local ok, err = bloom:set("my_filter", 'my_key')
            	debug("set-exist", ok, err)
            	assert(ok==true)
            	assert(err == "No")
            
            	-- check a key, Exist
            	local ok, err = bloom:check("my_filter", 'my_key')
            	debug("check-exist", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            	-- check a key, Not Exist
            	local ok, err = bloom:check("my_filter", 'this_key_not_exist')
            	debug("check-not-exist", ok, err)
            	assert(ok==true)
            	assert(err == "No")
            
            	-- flush a filter
            	local ok, err = bloom:flush("my_filter")
            	debug("flush", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	-- close a bloom filter
            	local ok, err = bloom:close("my_filter")
            	debug("close", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	-- check a key, Exist
            	local ok, err = bloom:check("my_filter", 'my_key')
            	debug("check-exist", ok, err)
            	assert(ok==true)
            	assert(err == "Yes")
            
            
            	bloom:create("my_filter3", capacity, 0.001)
            	-- list all filter
            	local ok, filters = bloom:list("my_filter")
            	debug("list", ok, filters)
            	assert(ok==true)
            	assert(type(filters)=='table' and #filters==2)
            	for _,filter in ipairs(filters) do 
            		if filter.name == "my_filter" then 
            			assert(filter.size == 1)
            		end            		
            	end
            	bloom:drop('my_filter3')
            
            	-- Set many items in a filter at once(bulk command)
            	local ok, status = bloom:sets("my_filter", {"a", "b", "c"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("sets", ok, err)
            	assert(err == "Yes Yes Yes")
            
            	local ok, status = bloom:sets("my_filter", {"a", "b", "d"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("sets", ok, err)
            	assert(err == "No No Yes")
            
            	-- Checks if a list of keys are in a filter
            	local ok, status = bloom:checks("my_filter", {"a", "x", "c", "d", "e"})
            	assert(ok)
            	assert(type(status)=='table')
            	err = table.concat(status, ' ')
            	debug("checks", ok, err)
            	assert(err == "Yes No Yes Yes No")
            
            
            	-- Gets info about a filter
            	local ok, info = bloom:info("my_filter")
            	debug("info", ok, info)
            	assert(ok)
            	assert(type(info)=='table')
            	assert(info.capacity == capacity)
            	assert(info.probability == probability)
            	assert(info.size == 5)
            
            	-- drop a filter
            	local ok, err = bloom:drop('my_filter')
            	debug("drop", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            
            	-- Test filter not exist
            	local ok, err = bloom:drop('my_filter')
            	debug("drop-not-exist", ok, err)
            	assert(ok==false)
            	assert(err == "Filter does not exist")
            
            
            	-- create, close and clear a bloom filter, my_filter2 is still in disk.
            	local ok, err = bloom:create("my_filter2", 10000*20, 0.001)
            	debug("create-new", ok, err)
            	assert(ok == true)
            	assert(err == "Done", "err ~= 'Done'")
            	local ok, err = bloom:close("my_filter2")
            	debug("close", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            	local ok, err = bloom:clear("my_filter2")
            	debug("clear", ok, err)
            	assert(ok==true)
            	assert(err == "Done")
            
            	ngx.say("--------- all test ok --------------")
            end
            local ok, err = pcall(test_main)
            if not ok then
            	bloom:close("my_filter")
            	bloom:close("my_filter2")
            	bloom:close("my_filter3")
            	assert(ok, err)
            end

            ';
        }
    }
```

Methods
=======

[Back to TOC](#table-of-contents)


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

    local bloomd = require "resty.bloomd"

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


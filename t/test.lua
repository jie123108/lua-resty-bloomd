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

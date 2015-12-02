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

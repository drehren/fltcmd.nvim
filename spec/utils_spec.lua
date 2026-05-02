---@module "luassert"
---@module "busted"

---@module 'fltcmd'
local fltcmd

setup(function()
	fltcmd = require('fltcmd')
end)

teardown(function()
	fltcmd = nil
end)

describe('splitline', function()
	it('hello world', function()
		assert.same({ 'hello', 'world' }, fltcmd.splitline('hello world'))
	end)
	it('hello\\ world', function()
		assert.same({ 'hello\\ ', 'world' }, fltcmd.splitline('hello\\  world'))
	end)

	--                    1         2         3 3
	--           1        0         0         0 2
	local ln = [[hello\ to\ all  how is it going?]]
	local getlast = function(l, n)
		local r = fltcmd.splitline(l, n)
		return r[#r]
	end

	it([[hello\ to\ all  how is it going?, 1]], function()
		assert.same('h', getlast(ln, 1))
	end)
	it([[hello\ to\ all  how is it going?, 6]], function()
		assert.same('hello\\ ', getlast(ln, 6))
	end)
	it([[hello\ to\ all  how is it going?, 5]], function()
		assert.same('hello', getlast(ln, 5))
	end)
	it([[hello\ to\ all  how is it going?, 4]], function()
		assert.same('hell', getlast(ln, 4))
	end)
	it([[hello\ to\ all  how is it going?, 18]], function()
		assert.same('ho', getlast(ln, 18))
	end)
	it([[hello\ to\ all  how is it going?, 28]], function()
		assert.same('go', getlast(ln, 28))
	end)
	it([[hello\ to\ all  how is it going?, 33]], function()
		assert.same('going?', getlast(ln, 33))
	end)
	it([[hello\ to\ all  how is it going?, 15]], function()
		assert.same('', getlast(ln, 15))
	end)
	it([[hello\ to\ all  how is it going?, 20]], function()
		assert.same('', getlast(ln, 20))
	end)
	it([[hello\ to\ all  how is it going?, 26]], function()
		assert.same('', getlast(ln, 26))
	end)
	it([[    : 2]], function()
		assert.same('', getlast('    ', 2))
	end)
	it([[hello: 2]], function()
		assert.same('he', getlast('hello', 2))
	end)
	it([[hello: 4]], function()
		assert.same('hell', getlast('hello', 4))
	end)
end)

package.loaded['fltcmd'] = nil

local fltcmd
do
	local ok
	ok, fltcmd = pcall(require, 'fltcmd')
	if not ok then
		-- add to path
		local p = (function()
			return debug.getinfo(2, 'S').source
		end)()
		p = vim.fs.dirname(vim.fs.dirname(p))
		vim.opt.rtp:append(p)
		fltcmd = require('fltcmd')
	end
end

local c = fltcmd.new_command({
	testa = fltcmd.new_command(function(self, args)
		args = fltcmd.process_args(self, args)
		vim.print(args)
	end, {
		['-c'] = fltcmd.getcompletion('file'),
		['-f'] = function(pat)
			local res = {}
			if vim.startswith('hello', pat) then
				res[1] = 'hello'
			end
			return res
		end,
		fltcmd.choiceof({ 'aab', 'abb', 'abc' }),
		fltcmd.choiceof({ 'cc', 'cccc' }),
		fltcmd.getcompletion('file'),
	}),
	testb = fltcmd.new_command(function(_, args)
		print('tb:', vim.inspect(args))
	end, { fltcmd.choiceof({ 'aaa', 'bbb', 'ccc', 'ddd' }), '...' }),
	testc = fltcmd.new_command({
		more = fltcmd.new_command(function()
			print('moar')
		end),
	}),
	testd = fltcmd.new_command(function(_, args)
		print('td:', vim.inspect(args))
	end, { ['...'] = fltcmd.choiceof({ 'ddd', 'fff', 'eee' }) }),
	testf = fltcmd.new_command(function(tf, args)
		local pargs = fltcmd.process_args(tf, args)
		print('tf:', vim.inspect(args))
		if pargs.subcmd1 then
			-- use pargs as it will take care of starting from the correct position
			pargs.subcmd1(args)
		end
	end, {
		subcmd1 = fltcmd.new_command(function(_, args)
			print('subcmd:', vim.inspect(args))
		end, { ['-s'] = fltcmd.choiceof({ 'one', 'two', 'three' }) }),
	}),
})

local ok = pcall(c)
if ok then
	error('testa should have failed')
end
ok = pcall(c, {})
if ok then
	error('testa no args should have failed')
end
c({ 'testa', '-f', 'init.lua', 'aaa', 'cc', 'lua/' })
c({ 'testb' })
c({ 'testb', 'some', 'data' })
ok = pcall(c, { 'testc' })
if ok then
	error('test5 should have failed')
end
c({ 'testc', 'more' })
ok = pcall(c, { 'testc', 'something' })
if ok then
	error('test7 should have failed')
end
c({ 'testf', 'subcmd1' })

local comp = fltcmd.create_completer(c)

local tbl_eq = function(a, b)
	for i, v in ipairs(a) do
		if v ~= b[i] then
			return false
		end
	end
	return #a == #b
end

local function test_comp(l, line, p, expected)
	local res = comp(l, line, p)
	if not tbl_eq(res, expected) then
		local msg = ('bad completion" expected %q, got %q'):format(
			vim.inspect(expected),
			vim.inspect(res)
		)
		error(msg, 2)
	end
end

test_comp('', 'c ', 2, { 'testa', 'testb', 'testc', 'testd', 'testf' })
test_comp('testa', 'c testa', 7, { 'testa' })
test_comp('', 'c testa -f ', 11, { 'hello' })
test_comp('o', 'c testa -f o', 12, {})
test_comp('he', 'c testa -f he', 13, { 'hello' })
test_comp('a', 'c testa a', 9, { 'aab', 'abb', 'abc' })
test_comp('c', 'c testa a c', 11, { 'cc', 'cccc' })
test_comp(
	'',
	'c testa a c ',
	12,
	{ 'doc/', 'lazy.lua', 'LICENSE', 'lua/', 'README.md', 'spec/' }
)
test_comp('m', 'c testc m', 9, { 'more' })
test_comp('-', 'c testa -', 9, { '-c', '-f' })
test_comp('', 'c testb ', 8, { 'aaa', 'bbb', 'ccc', 'ddd' })
test_comp('', 'c testb a ', 10, { 'aaa', 'bbb', 'ccc', 'ddd' })
test_comp('', 'c testd ', 8, { 'ddd', 'fff', 'eee' })
test_comp('', 'c testd a ', 10, { 'ddd', 'fff', 'eee' })
test_comp('', 'c testd a a ', 12, { 'ddd', 'fff', 'eee' })
test_comp('', 'c testf ', 8, { 'subcmd1' })
test_comp('s', 'c testf s', 9, { 'subcmd1' })
test_comp('-', 'c testf subcmd1 -', 17, { '-s' })
test_comp('', 'c testf subcmd1 -s ', 19, { 'one', 'two', 'three' })

---@module "luassert"
---@module "busted"

describe('commands', function()
	local fltcmd

	setup(function()
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
	end)

	teardown(function()
		fltcmd = nil
	end)

	describe('simple subcommand-only command', function()
		local c = fltcmd.new_command({
			sub1 = fltcmd.new_command(function()
				return 'sub1'
			end),
			sub2 = fltcmd.new_command(function()
				return 'sub2'
			end),
		})

		it('bad arguments call', function()
			assert.has.error(c, 'args: expected table, got nil')
			assert.has.error(function()
				c('arg')
			end, 'args: expected table, got string')
			assert.has.error(function()
				c({})
			end, 'no command given')
			assert.has.error(function()
				c({ 'cmd' })
			end, 'unknown command "cmd"')
		end)

		it('only commands are checked', function()
			assert.has.no.error(function()
				c({ 'sub1', 'other', 'args' })
			end)
			assert.has.no.error(function()
				c({ 'sub2', 'arg', 'other' })
			end)
		end)

		it('using correct commands', function()
			assert.equal('sub1', c({ 'sub1' }))
			assert.equal('sub2', c({ 'sub2' }))
		end)
	end)

	describe('commands can be stacked', function()
		local echo = fltcmd.new_command(function(_, args)
			return table.concat(args, ' ')
		end)

		it('standalone use', function()
			assert.equal('hello world!', echo({ 'hello', 'world!' }))
		end)

		it('stacked use', function()
			local c1 = fltcmd.new_command({
				send = echo,
			})
			assert.equal('hello world!', c1({ 'send', 'hello', 'world!' }))
			assert.is.error(function()
				c1({ 'hello', 'world!' })
			end, 'unknown command "hello"')
		end)

		it('2-fold stack', function()
			local c2 = fltcmd.new_command({ send = echo })
			local c1 = fltcmd.new_command({ main = c2 })

			assert.equal(
				'hello world',
				c1({ 'main', 'send', 'hello', 'world' })
			)
			assert.has.error(function()
				c1({ 'main', 'hello', 'world' })
			end, 'unknown command "hello"')
			assert.has.error(function()
				c1({ 'main' })
			end, 'no command given')
		end)
	end)

	describe('argument processing', function()
		local c = fltcmd.new_command(function(c, args)
			return fltcmd.process_args(c, args)
		end, {
			['--file'] = fltcmd.any,
			['-v'] = 3,
			['-r'] = true,
		})

		assert.same({}, c({}))
		assert.same({ ['--file'] = 'a.txt' }, c({ '--file', 'a.txt' }))
		assert.same({ ['-v'] = 2 }, c({ '-v', '-v' }))
		assert.same({ ['-r'] = true }, c({ '-r', '-r' }))
	end)

	it('check completion', function()
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

		local comp = fltcmd.create_completer(c)
		local function test_comp(l, line, p, expected)
			assert.same(expected, comp(l, line, p))
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
	end)
end)

---@module "luassert"
---@module "busted"

describe('commands', function()
	---@module 'fltcmd'
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
		assert.same({ ['-r'] = true }, c({ '-r', '-r', 'arg' }))
	end)

	it('split line', function()
		assert.same({ 'hello', 'world' }, fltcmd.splitline('hello world'))
		assert.same({ 'hello\\ ', 'world' }, fltcmd.splitline('hello\\  world'))

		--                    1         2         3 3
		--           1        0         0         0 2
		local ln = [[hello\ to\ all  how is it going?]]

		local getlast = function(l, n)
			local r = fltcmd.splitline(l, n)
			return r[#r]
		end

		assert.same('h', getlast(ln, 1))
		assert.same('hello\\ ', getlast(ln, 6))
		assert.same('hello', getlast(ln, 5))
		assert.same('hell', getlast(ln, 4))
		assert.same('ho', getlast(ln, 18))
		assert.same('go', getlast(ln, 28))
		assert.same('going?', getlast(ln, 33))
		assert.same('', getlast(ln, 15))
		assert.same('', getlast(ln, 20))
		assert.same('', getlast(ln, 26))
		assert.same('', getlast('    ', 2))
		assert.same('he', getlast('hello', 2))
		assert.same('hell', getlast('hello', 4))
	end)

	it('check completion', function()
		local c = fltcmd.create_completer({
			testa = {
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
			},
			testb = { fltcmd.choiceof({ 'aaa', 'bbb', 'ccc', 'ddd' }), '...' },
			testc = { more = fltcmd.any },
			testd = { ['...'] = fltcmd.choiceof({ 'ddd', 'fff', 'eee' }) },
			testf = {
				subcmd1 = {
					['-s'] = fltcmd.choiceof({ 'one', 'two', 'three' }),
				},
			},
		})

		local function comp(line)
			local splt = fltcmd.splitline(line)
			return c(splt[#splt], line, #line)
		end

		assert.same({ 'testa', 'testb', 'testc', 'testd', 'testf' }, comp('c '))
		assert.same({ 'testa' }, comp('c testa'))
		assert.same({ 'hello' }, comp('c testa -f '))
		assert.same({}, comp('c testa -f o'))
		assert.same({ 'hello' }, comp('c testa -f he'))
		assert.same({ 'aab', 'abb', 'abc' }, comp('c testa a'))
		assert.same({ 'cc', 'cccc' }, comp('c testa a c'))
		assert.same(
			{ 'doc/', 'lazy.lua', 'LICENSE', 'lua/', 'README.md', 'spec/' },
			comp('c testa a c ')
		)
		assert.same({ 'more' }, comp('c testc m'))
		assert.same({ '-c', '-f' }, comp('c testa -'))
		assert.same({ 'aaa', 'bbb', 'ccc', 'ddd' }, comp('c testb '))
		assert.same({ 'aaa', 'bbb', 'ccc', 'ddd' }, comp('c testb a '))
		assert.same({ 'ddd', 'fff', 'eee' }, comp('c testd '))
		assert.same({ 'ddd', 'fff', 'eee' }, comp('c testd a '))
		assert.same({ 'ddd', 'fff', 'eee' }, comp('c testd a a '))
		assert.same({ 'subcmd1' }, comp('c testf '))
		assert.same({ 'subcmd1' }, comp('c testf s'))
		assert.same({ '-s' }, comp('c testf subcmd1 -'))
		assert.same({ 'one', 'two', 'three' }, comp('c testf subcmd1 -s '))
	end)

	it('completion in-between', function()
		local c = fltcmd.create_completer({
			fltcmd.flags({ '-v', '-f', '-r' }),
			['-o'] = fltcmd.any,
			fltcmd.any,
			'...',
		})
		local function compl(str, pos)
			local splt = fltcmd.splitline(str, pos)
			return c(splt[#splt], str, pos or #str)
		end

		assert.same({ '-f', '-o', '-r', '-v' }, compl('c -'))
		assert.same({ '-f', '-o', '-r', '-v' }, compl('c - data', 4))
		assert.same({}, compl('c - data da'))
		assert.same({ '-o' }, compl('c -o data', 4))
	end)
end)

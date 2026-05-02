local function noop() end

---@module 'fltcmd'
local fltcmd
setup(function()
	fltcmd = require('fltcmd')
end)

teardown(function()
	fltcmd = nil
end)

describe('commands', function()
	local c = {
		cmd1 = { cmd1cmd1 = {} },
		cmd2 = {},
		cmd3 = {
			cmd3cmd1 = { cmd3cmd1cmd1 = {}, cmd3cmd1cmd2 = {} },
			cmd3cmd2 = {},
		},
	}

	assert.same({}, fltcmd.process_args(c, { 'c' }))

	it('cmd1', function()
		local p = fltcmd.process_args(c, { 'cmd1' })
		assert.same({ [c.cmd1] = {} }, p)
	end)
	it('cmd1 cmd1cmd1', function()
		local p = fltcmd.process_args(c, { 'cmd1', 'cmd1cmd1' })
		assert.same({ [c.cmd1] = { 'cmd1cmd1' } }, p)
		assert.is_table(p[c.cmd1])
		assert.same(
			{ [c.cmd1.cmd1cmd1] = {} },
			fltcmd.process_args(c.cmd1, p[c.cmd1])
		)
	end)
	it('cmd1 cmd2', function()
		local p = fltcmd.process_args(c, { 'cmd1', 'cmd2' })
		assert.same({ [c.cmd1] = { 'cmd2' } }, p)
		assert.same({}, fltcmd.process_args(c.cmd1, p[c.cmd1]))
	end)
	it('cmd2 cmd1', function()
		local p = fltcmd.process_args(c, { 'cmd2', 'cmd1' })
		assert.same({ [c.cmd2] = { 'cmd1' } }, p)
	end)
	it('cmd3 cmd3cmd1 cmd1', function()
		local p1 = fltcmd.process_args(c, { 'cmd3', 'cmd3cmd1', 'cmd1' })
		assert.same({ [c.cmd3] = { 'cmd3cmd1', 'cmd1' } }, p1)
		local p2 = fltcmd.process_args(c.cmd3, p1[c.cmd3])
		assert.same({ [c.cmd3.cmd3cmd1] = { 'cmd1' } }, p2)
		local p3 = fltcmd.process_args(c.cmd3.cmd3cmd1, p2[c.cmd3.cmd3cmd1])
		assert.same({}, p3)
	end)
end)

describe('flags', function()
	local cdef = { fltcmd.flags({ '-h', '-e', '-v' }) }

	assert.same({ ['-h'] = true }, fltcmd.process_args(cdef, { '-h' }))

	local p = fltcmd.process_args(cdef, { '-h', '-e', '-v' })
	assert.same({ ['-h'] = true, ['-e'] = true, ['-v'] = true }, p)
end)

describe('options', function()
	local cdef = {
		['--file'] = fltcmd.any,
		['--exclude'] = fltcmd.multiple(3, fltcmd.any),
	}

	it('--file', function()
		assert.is.error(function()
			fltcmd.process_args(cdef, { '--file' })
		end, '--file: expected argument')
	end)
	it('--file a.txt', function()
		assert.same(
			{ ['--file'] = 'a.txt' },
			fltcmd.process_args(cdef, { '--file', 'a.txt' })
		)
	end)
	it('--exclude a.txt', function()
		assert.same(
			{ ['--exclude'] = { 'a.txt' } },
			fltcmd.process_args(cdef, { '--exclude', 'a.txt' })
		)
	end)
	it('--exclude a.txt --exclude b.txt', function()
		assert.same(
			{ ['--exclude'] = { 'a.txt', 'b.txt' } },
			fltcmd.process_args(
				cdef,
				{ '--exclude', 'a.txt', '--exclude', 'b.txt' }
			)
		)
	end)
	it('--exclude a.txt --file b.txt --exclude c.txt', function()
		assert.same(
			{ ['--exclude'] = { 'a.txt', 'c.txt' }, ['--file'] = 'b.txt' },
			fltcmd.process_args(cdef, {
				'--exclude',
				'a.txt',
				'--file',
				'b.txt',
				'--exclude',
				'c.txt',
			})
		)
	end)
	it('--exclude --exclude b.txt', function()
		assert.is.error(function()
			fltcmd.process_args(cdef, { '--exclude', '--exclude', 'b.txt' })
		end, '--exclude: "--exclude" is not expected')
	end)
	it('--exclude a.txt b.txt c.txt d.txt', function()
		assert.same(
			{ ['--exclude'] = { 'a.txt', 'b.txt', 'c.txt' } },
			fltcmd.process_args(
				cdef,
				{ '--exclude', 'a.txt', 'b.txt', 'c.txt', 'd.txt' }
			)
		)
	end)
	it('--exclude a.txt b.txt c.txt --exclude d.txt', function()
		assert.same(
			{ ['--exclude'] = { 'a.txt', 'b.txt', 'c.txt' } },
			fltcmd.process_args(cdef, {
				'--exclude',
				'a.txt',
				'b.txt',
				'c.txt',
				'--exclude',
				'd.txt',
			})
		)
	end)
end)

describe('2 positionals', function()
	local c = { fltcmd.any, fltcmd.any }

	assert.same({}, fltcmd.process_args(c, {}))
	it('a', function()
		assert.same({ 'a' }, fltcmd.process_args(c, { 'a' }))
	end)
	it('a b', function()
		assert.same({ 'a', 'b' }, fltcmd.process_args(c, { 'a', 'b' }))
	end)
	it('a b c', function()
		assert.same({ 'a', 'b' }, fltcmd.process_args(c, { 'a', 'b', 'c' }))
	end)
end)

describe('... positional', function()
	local c = { ['...'] = fltcmd.any }

	assert.same({}, fltcmd.process_args(c, {}))
	it('a', function()
		assert.same({ 'a' }, fltcmd.process_args(c, { 'a' }))
	end)
	it('a b', function()
		assert.same({ 'a', 'b' }, fltcmd.process_args(c, { 'a', 'b' }))
	end)
	it('a b c', function()
		assert.same(
			{ 'a', 'b', 'c' },
			fltcmd.process_args(c, { 'a', 'b', 'c' })
		)
	end)
end)

describe('var positional', function()
	local c = { fltcmd.any, '...' }

	assert.same({}, fltcmd.process_args(c, {}))
	it('a', function()
		assert.same({ 'a' }, fltcmd.process_args(c, { 'a' }))
	end)
	it('a b', function()
		assert.same({ 'a', 'b' }, fltcmd.process_args(c, { 'a', 'b' }))
	end)
	it('a b c', function()
		assert.same(
			{ 'a', 'b', 'c' },
			fltcmd.process_args(c, { 'a', 'b', 'c' })
		)
	end)
end)

describe('command and positional', function()
	local c = { cmd1 = {}, fltcmd.any }

	it('arg', function()
		assert.same({ 'arg' }, fltcmd.process_args(c, { 'arg' }))
	end)

	it('cmd1 arg', function()
		assert.same(
			{ [c.cmd1] = { 'arg' } },
			fltcmd.process_args(c, { 'cmd1', 'arg' })
		)
		assert.same({}, fltcmd.process_args(c.cmd1, { 'arg' }))
	end)

	it('arg cmd1', function()
		assert.same({ 'arg' }, fltcmd.process_args(c, { 'arg', 'cmd1' }))
	end)
end)

describe('command and flags', function()
	local c = fltcmd.new_command(noop, {
		fltcmd.flags({ '-h' }),
		cmd1 = fltcmd.new_command(noop, { fltcmd.flags({ '-e' }) }),
	})

	it('cmd1', function()
		local p = fltcmd.process_args(c, { 'cmd1' })
		assert.same({ [c.cmd1] = {} }, p)
	end)
	it('-h cmd1 -e', function()
		local p = fltcmd.process_args(c, { '-h', 'cmd1', '-e' })
		assert.same({ ['-h'] = true, [c.cmd1] = { '-e' } }, p)
	end)
	it('cmd1 -h -e', function()
		local p = fltcmd.process_args(c, { 'cmd1', '-h', '-e' })
		assert.same({ [c.cmd1] = { '-h', '-e' } }, p)
	end)
	it('-h -e cmd1', function()
		local p = fltcmd.process_args(c, { '-h', '-e', 'cmd1' })
		assert.same({ ['-h'] = true, [c.cmd1] = {} }, p)
	end)
end)

describe('command and flags and positionals', function()
	local c = fltcmd.new_command(noop, {
		fltcmd.flags({ '-h' }),
		cmd1 = fltcmd.new_command(noop, {
			fltcmd.flags({ '-e' }),
			fltcmd.any,
			fltcmd.any,
		}),
	})

	it('cmd1 arg', function()
		local p = fltcmd.process_args(c, { 'cmd1', 'arg' })
		assert.same({ 'arg' }, fltcmd.process_args(c.cmd1, p[c.cmd1]))
	end)
	it('-h cmd1 -e arg', function()
		local p = fltcmd.process_args(c, { '-h', 'cmd1', '-e', 'arg' })
		assert.same(
			{ ['-e'] = true, 'arg' },
			fltcmd.process_args(c.cmd1, p[c.cmd1])
		)
	end)
	it('cmd1 -h -e arg', function()
		local p = fltcmd.process_args(c, { 'cmd1', '-h', '-e', 'arg' })
		assert.same(
			{ '-h', 'arg', ['-e'] = true },
			fltcmd.process_args(c.cmd1, p[c.cmd1])
		)
	end)
	it('-h -e cmd1 arg', function()
		local p = fltcmd.process_args(c, { '-h', '-e', 'cmd1', 'arg' })
		assert.same({ 'arg' }, fltcmd.process_args(c.cmd1, p[c.cmd1]))
	end)

	-- two args
	it('cmd1 arg arg2', function()
		local p = fltcmd.process_args(c, { 'cmd1', 'arg', 'arg2' })
		assert.same({ 'arg', 'arg2' }, fltcmd.process_args(c.cmd1, p[c.cmd1]))
	end)
	it('-h cmd1 -e arg arg2', function()
		local p = fltcmd.process_args(c, { '-h', 'cmd1', '-e', 'arg', 'arg2' })
		assert.same(
			{ ['-e'] = true, 'arg', 'arg2' },
			fltcmd.process_args(c.cmd1, p[c.cmd1])
		)
	end)
	it('cmd1 -h -e arg arg2', function()
		local p = fltcmd.process_args(c, { 'cmd1', '-h', '-e', 'arg', 'arg2' })
		assert.same(
			{ '-h', 'arg', ['-e'] = true },
			fltcmd.process_args(c.cmd1, p[c.cmd1])
		)
	end)
	it('-h -e cmd1 arg arg2', function()
		local p = fltcmd.process_args(c, { '-h', '-e', 'cmd1', 'arg', 'arg2' })
		assert.same({ 'arg', 'arg2' }, fltcmd.process_args(c.cmd1, p[c.cmd1]))
	end)
end)

describe('command and options', function()
	local c = {
		cmd1 = { ['-f'] = fltcmd.any },
		cmd2 = {
			cmd21 = { ['-d'] = fltcmd.multiple(2, fltcmd.any), cmd211 = {} },
		},
		['-r'] = fltcmd.any,
		cmd3 = {},
	}

	it('cmd1 -f', function()
		local p1 = fltcmd.process_args(c, { 'cmd1', '-f' })
		assert.same({ [c.cmd1] = { '-f' } }, p1)
		assert.has_error(function()
			fltcmd.process_args(c.cmd1, p1[c.cmd1])
		end, '-f: expected argument')
	end)
	it('cmd1 -f f.txt', function()
		local p1 = fltcmd.process_args(c, { 'cmd1', '-f', 'f.txt' })
		assert.same({ [c.cmd1] = { '-f', 'f.txt' } }, p1)
		assert.same(
			{ ['-f'] = 'f.txt' },
			fltcmd.process_args(c.cmd1, p1[c.cmd1])
		)
	end)
	it('-r cmd2', function()
		assert.no_error(function()
			fltcmd.process_args(c, { '-r', 'cmd2' })
		end)
	end)
	it('cmd2 cmd21 -d a.txt cmd211', function()
		local args = vim.split('cmd2 cmd21 -d a.txt cmd211', ' ')
		local p1 = fltcmd.process_args(c, args)
		assert.is_table(p1[c.cmd2])
		local p2 = fltcmd.process_args(c.cmd2, p1[c.cmd2])
		assert.is_table(p2[c.cmd2.cmd21])
		local p3 = fltcmd.process_args(c.cmd2.cmd21, p2[c.cmd2.cmd21])
		assert.same({ ['-d'] = { 'a.txt', 'cmd211' } }, p3)
	end)
end)

pending('command and options and flags', function() end)

pending('command and options and flags and positionals', function() end)

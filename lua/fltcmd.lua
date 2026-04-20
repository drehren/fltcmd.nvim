local bslash = string.byte('\\')
local space = string.byte(' ')

--- Splits the line by non-escaped space, last item may be empty
---@param line string Line to split
---@param _end? integer End byte to accout for split
---@return string[]
local function split(line, _end)
	_end = _end or #line
	if line:byte(_end) == bslash and line:byte(_end + 1) == space then
		_end = _end + 1
	end
	local p = 1
	do
		local s, e = line:find('%s+')
		if s == 1 then
			p = e + 1
		end
	end
	local l = p - 1
	local ln = {}
	repeat
		l = l + 1
		local s, e = line:find('%s+', l)
		if s then
			if line:byte(s - 1) == bslash then
				s = s + 1
			end
			if s <= e then
				if _end < s then
					ln[#ln + 1] = line:sub(p, _end)
					return ln
				end
				ln[#ln + 1] = line:sub(p, s - 1)
				p = e + 1
			end
		end
		---@diagnostic disable-next-line: cast-local-type
		l = e
	until s == nil or p > _end
	ln[#ln + 1] = line:sub(p, _end)
	return ln
end

--- Represents a single command
---@class fltcmd.command
local C = {}

--- Represents a collection of flags for a command
---@class fltcmd.flags
local F = {}

local function is_def(v)
	if type(v) == 'table' then
		local mt = getmetatable(v)
		while mt and mt ~= C do
			mt = getmetatable(mt)
		end
		return mt == C
	end
	return false
end

local function is_flags(v)
	if type(v) == 'table' then
		local mt = getmetatable(v)
		while mt and mt ~= F do
			mt = getmetatable(mt)
		end
		return mt == F
	end
	return false
end

local M = {}

---@alias fltcmd._comp_std fun(lead: string, arg: any, pos: integer, count: table):string[]
---@alias fltcmd._comp_arg fun(lead:nil, arg:nil, pos:nil, what:true):integer
---@alias fltcmd._comp_flg fun(lead:nil, arg:nil, pos:nil, what:string):boolean

---@alias fltcmd._comp fltcmd._comp_std|fltcmd._comp_arg|fltcmd._comp_flg

local ctxcache = setmetatable({}, { __mode = 'k' })

local function c_count(v)
	if v == '...' then
		return math.huge
	elseif type(v) == 'number' then
		return v
	else
		return 1
	end
end

---@param cmd fltcmd.command
---@return fltcmd._comp
local function new_ctx(cmd)
	if ctxcache[cmd] then
		return ctxcache[cmd]
	end

	local cmdlist = {}
	local compdef = {}
	local maxargs = table.maxn(cmd)

	---@type [integer, string[]][]
	local flags = {}

	for k, v in pairs(cmd) do
		if type(k) == 'string' then
			if k ~= '...' then
				cmdlist[#cmdlist + 1] = k
			else
				compdef[maxargs + 1] = v
			end
		end

		if v == '...' then
			if k > 1 then
				v = cmd[k - 1]
			else
				v = M.any
			end
			k = '...'
			maxargs = math.huge
		end

		local vtype = type(v)
		if vtype == 'function' then
			compdef[k] = v
		elseif vtype == 'table' then
			if is_flags(v) then
				for _, f in ipairs(v) do
					cmdlist[#cmdlist + 1] = f
					compdef[f] = true
				end
				---@cast k integer
				flags[#flags + 1] = { k, v }
			else
				compdef[k] = new_ctx(v)
			end
		elseif vtype ~= 'boolean' and vtype ~= 'number' then
			error('parameter completer is not a function', 3)
		end
	end

	table.sort(flags, function(a, b)
		return a[1] > b[1]
	end)
	for _, fls in ipairs(flags) do
		table.remove(cmd, fls[1])
		for _, f in ipairs(fls[2]) do
			cmd[f] = true
		end
	end

	table.sort(cmdlist)

	---@class fltcmd.completer
	local X = {}
	function X:__call(lead, arg, pos, what)
		-- get max positional arguments
		if what == true then
			return maxargs
		end

		-- checks that given flag is defined
		if type(what) == 'string' then
			if vim.startswith(what, '-') then
				for _, v in ipairs(cmdlist) do
					if vim.startswith(what, v) then
						return true
					end
				end
			end
			return false
		end

		-- normal flow, gets candidates

		local candidates = {}
		---@type boolean|nil
		local addopts = vim.startswith(lead, '-')

		-- positional args only add candidates when previous argument was not an option
		if #self > 0 then
			local posarg = self[pos] or self['...']
			if arg == self and posarg then
				vim.list_extend(candidates, posarg(lead))
				addopts = addopts or (#candidates > 0 and nil)
			end
		elseif pos > 0 then
			return {}
		end

		local count = what

		-- commands or options with completion, add candidates when required
		if type(arg) == 'string' and self[arg] and count[arg] == 1 then
			vim.list_extend(candidates, self[arg](lead))
			addopts = addopts or nil
		end

		if addopts ~= nil then
			addopts = addopts or #candidates == 0
		end

		for _, c in ipairs(cmdlist) do
			if
				(addopts or not vim.startswith(c, '-'))
				and vim.startswith(c, lead)
				and count[c] < c_count(cmd[c])
			then
				candidates[#candidates + 1] = c
			end
		end

		return candidates
	end

	---@overload fun(lead: string, arg: string|table|function, pos:integer):string[]
	---@overload fun(lead: nil, arg: nil, pos:nil, what:true):integer
	---@overload fun(lead: nil, arg: nil, pos:nil, what:string):boolean
	---@diagnostic disable-next-line: assign-type-mismatch
	ctxcache[cmd] = setmetatable(compdef, X)
	return ctxcache[cmd]
end

local CT = {
	__index = function()
		return 0
	end,
}

local completercache = setmetatable({}, { __mode = 'k' })

--- Creates an command completion customlist function from the specified command.
---@param cmd fltcmd.command A command to create the completion from
---@return fltcmd.comp completer Completion function
function M.create_completer(cmd)
	if completercache[cmd] then
		return completercache[cmd]
	end

	local ctx = new_ctx(cmd)

	completercache[cmd] = function(lead, cmdline, cursorpos)
		local cmdargs = split(cmdline, cursorpos)
		cmdargs[#cmdargs] = nil

		local comp = ctx
		local count = setmetatable({}, CT)
		local maxarg = comp(nil, nil, nil, true)
		local posarg = math.min(1, maxarg)
		local lastc
		for i = 1, #cmdargs do
			local p = cmdargs[i]
			local c = comp[p]
			count[p] = count[p] + 1
			if type(c) == 'table' then
				lastc = c
				---@cast c fltcmd._comp
				comp = c
				maxarg = comp(nil, nil, nil, true)
				posarg = math.min(1, maxarg)
			elseif c then
				lastc = p
			elseif not comp(nil, nil, nil, p) then
				if lastc ~= comp then
					lastc = comp
				else
					posarg = posarg + 1
				end
			end
		end

		return comp(lead, lastc, posarg, count)
	end

	return completercache[cmd]
end

---@class fltcmd.injector_result
local IR = {}
IR.__index = {}

--- Updates the command line with the specified values.
---@param values table<string, string> The value map to use.
---@return string[] cmdline This objects cmdline.
---@diagnostic disable-next-line: duplicate-set-field
function IR:inject(values)
	self.existing = vim.tbl_extend('force', self.existing, values or {})

	local injpos = self.missing

	for kv in vim.iter(injpos):rev() do
		local pos, key, opt = unpack(kv)
		if self.existing[key] then
			table.insert(self.cmdline, pos, self.existing[key])
			if opt then
				table.insert(self.cmdline, pos, opt)
			end
		end
	end

	return self.cmdline
end

--- Creates an injector object that can process a command line to extract
--- existing values and inject new ones to the specified options.
---@param cmd fltcmd.command Command to use.
---@param valmap fltcmd.valmap Value map to define option values.
---@return fltcmd.injector injector Injector object.
function M.create_injector(cmd, valmap)
	local ctx = new_ctx(cmd)

	local inj = {}

	---@param cmdline string[]
	---@return fltcmd.injector_result
	function inj.process(cmdline)
		---@type fltcmd.injector_result
		local res = {
			cmdline = cmdline,
			existing = {},
			missing = {},
		}
		setmetatable(res, IR)

		local injcmd = valmap[cmdline[1]]
		if not injcmd then
			return res
		end

		injcmd = vim.deepcopy(injcmd)

		-- seek where to inject the values
		local comp = ctx
		local argi = 1
		local posarg = false
		for i = 1, #cmdline do
			local p = cmdline[i]
			local c = comp[p]
			if type(c) == 'table' then
				---@cast c fltcmd._comp
				comp = c
				argi = 1
				posarg = false
			elseif c then
				posarg = true
				if injcmd[p] then
					table.insert(res.missing, { i + 1, injcmd[p] })
				end
			elseif not comp(nil, nil, nil, p) then
				if posarg then
					posarg = false
					local lastp = cmdline[i - 1]
					if injcmd[lastp] then
						res.existing[injcmd[lastp]] = p
						injcmd[lastp] = nil
					end
					res.missing[#res.missing] = nil
				else
					if injcmd[argi] then
						res.existing[injcmd[argi]] = p
					end
					injcmd[argi] = nil
					argi = argi + 1
				end
			end
		end

		-- put positionals first
		for i = 1, table.maxn(injcmd) do
			if injcmd[i] then
				table.insert(res.missing, { #cmdline + 1, injcmd[i] })
				injcmd[i] = nil
			end
		end
		-- put options last
		for k, v in pairs(injcmd) do
			table.insert(res.missing, { #cmdline + 1, v, k })
		end

		return res
	end

	return inj
end

---@param args string[]
local function dispatch_cmd(self, args)
	vim.validate('args', args, 'table')

	if not args[1] then
		error('no command given')
	end
	local cmd = table.remove(args, 1)
	return assert(self[cmd], 'unknown command "' .. cmd .. '"')(args)
end

--- Creates a new command
---@param fn fun(self: fltcmd.command, args: string[], opts?: vim.api.keyset.create_user_command.command_args)
---@param def? fltcmd.def Command definition
---@overload fun(def: fltcmd.basedef): fltcmd.command
---@return fltcmd.command
function M.new_command(fn, def)
	if not vim.is_callable(fn) and not def then
		if type(fn) == 'table' then
			def = fn
		end

		vim.validate('def', def, 'table')
		---@cast def -?
		for k, v in pairs(def) do
			if type(k) ~= 'string' then
				error('definition: expects string keys only')
			end
			if not is_def(v) then
				error('definition.' .. k .. ': expected command')
			end
		end
		fn = dispatch_cmd
	end

	vim.validate('fn', fn, 'callable')
	def = def or {}
	vim.validate('def', def, 'table')

	local mt = {}
	mt.__call = fn
	setmetatable(mt, C)

	---@cast def table
	return setmetatable(def, mt)
end

--- Processes the argument list for the specfied command and returns a table
--- that maps command option to value or existence.
---
--- If the processing find a subcommand it stops there, and creates a special
--- function that will pass the rest of the argument list.
---@param cmd fltcmd.command
---@param args string[]
---@return table<string|integer, boolean|number|function>
function M.process_args(cmd, args)
	local pargs = {}
	local i = 1
	while i <= #args do
		local v = args[i]
		i = i + 1
		local dvt = type(cmd[v])
		if dvt == 'string' or dvt == 'function' then
			pargs[v] = args[i]
			if pargs[v] then
				i = i + 1
			end
		elseif dvt == 'table' then
			if is_def(cmd[v]) then
				pargs[v] = function(subargs)
					assert(subargs == args)
					subargs = vim.list_slice(subargs, i)
					cmd[v](subargs)
				end
				break
			else
				pargs[v] = cmd[v]
			end
		elseif dvt == 'number' then
			pargs[v] = math.min((pargs[v] or 0) + 1, cmd[v])
		elseif dvt == 'boolean' then
			pargs[v] = true
		elseif cmd[#pargs + 1] or cmd['...'] then
			pargs[#pargs + 1] = v
		end
	end

	return pargs
end

--- Creates an `user-commands` comamnd that calls `cmd`
---@param name string Name of the new command.
---@param cmd fltcmd.command Command to execute.
---@param opts? vim.api.keyset.user_command Optional flags
function M.create_user_command(name, cmd, opts)
	opts = opts or {}
	if next(cmd) then
		opts.nargs = '+'
	else
		opts.nargs = 0
	end
	opts.complete = M.create_completer(cmd)
	vim.api.nvim_create_user_command(name, function(args)
		cmd(args.fargs, args)
	end, opts)
end

--- Completes to an empty list.
--- Useful to mark entries that require unknown input.
---@return table
function M.any()
	return {}
end

--- Creates a completion source from a list of specific values or a function
--- that generates one.
---@param values any[] Available values.
---@overload fun(fn: fun():any[]):fun(lead:string):string[]
---@return fun(lead:string):string[]
function M.choiceof(values)
	vim.validate('values_or_function', values, { 'table', 'callable' })
	if vim.is_callable(values) then
		return function(lead)
			return vim.tbl_filter(function(v)
				return vim.startswith(tostring(v), lead)
			end, values())
		end
	else
		return function(lead)
			return vim.tbl_filter(function(v)
				return vim.startswith(tostring(v), lead)
			end, values)
		end
	end
end

local getcomp = vim.fn.getcompletion

--- Creates a completion source using getcompletion() function.
---@param type fltcmd.getcompletion.type
---@return fun(lead:string):string[]
function M.getcompletion(type)
	return function(lead)
		return getcomp(lead, type, true)
	end
end

--- Defines flags (non-valued options) for command
---@param flags string[]
---@return fltcmd.flags
function M.flags(flags)
	vim.validate('flags', flags, 'table')
	return setmetatable(flags, F)
end

M.splitline = split

return M

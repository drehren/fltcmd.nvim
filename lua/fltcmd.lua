local bslash = string.byte('\\')

---@param cmdline string
---@param _end? integer
local function split(cmdline, _end)
	_end = _end or #cmdline
	cmdline = cmdline:sub(1, _end)
	local p = 1
	do
		local s, e = cmdline:find('%s+')
		if s == 1 then
			p = e + 1
		end
	end
	local l = p - 1
	local ln = {}
	repeat
		l = l + 1
		local s, e = cmdline:find('%s+', l)
		if s then
			if cmdline:byte(s - 1) == bslash then
				s = s + 1
			end
			if s <= e then
				ln[#ln + 1] = cmdline:sub(p, s - 1)
				p = e + 1
			end
		end
		---@diagnostic disable-next-line: cast-local-type
		l = e
	until s == nil or e >= _end
	ln[#ln + 1] = cmdline:sub(p)
	return ln
end

-- Command completion

---@alias fltcmd.comp fun(lead: string, cmdline: string, pos: integer):string[]

---@class fltcmd.basedef
---@field [string] fltcmd.command

---@class fltcmd.def : fltcmd.basedef
---@field [integer] fltcmd.comp|'...'
---@field [string] fltcmd.command|fltcmd.comp|boolean|integer

--- Represents a single command
---@class fltcmd.command
---@operator call(string[]):any
local C = {}
C.__index = C

---@param args string[]
local function dispatch_cmd(self, args)
	vim.validate('args', args, 'table')

	if not args[2] then
		error('no command given')
	end
	local cmd = args[2]
	table.remove(args, 1)
	return assert(self[cmd], 'unknown command "' .. cmd .. '"')(args)
end

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

local M = {}

local ctxcache = setmetatable({}, { __mode = 'k' })
---@param def fltcmd.command
local function new_ctx(def)
	if ctxcache[def] then
		return ctxcache[def]
	end

	local cmdlist = {}
	local compdef = {}

	for k, v in pairs(def) do
		if type(k) == 'string' then
			if k ~= '...' then
				cmdlist[#cmdlist + 1] = k
			else
				compdef[table.maxn(def) + 1] = v
			end
		end
		local vtype = type(v)
		if vtype == 'function' then
			compdef[k] = v
		elseif v == '...' then
			local prek = table.maxn(def)
			if prek == k and k > 1 then
				prek = prek - 1
			end
			v = def[prek]
			if v == '...' then
				compdef[k] = M.any
			elseif type(v) == 'function' then
				compdef[k] = v
			else
				error(
					'variadic parameter completer fail: v is ' .. vim.inspect(v),
					3
				)
			end
		elseif vtype == 'table' then
			if is_def(v) then
				compdef[k] = new_ctx(v)
			else
				error('parameter completer not a definition', 3)
			end
		elseif vtype ~= 'boolean' and vtype ~= 'number' then
			error('parameter completer is not a function', 3)
		end
	end

	table.sort(cmdlist)

	---@class fltcmd.completer
	local _CMP = {}
	function _CMP:__call(lead, arg, pos, what)
		if what == true then
			return #self
		end
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
		-- commands or options with completion, add candidates when required
		if type(arg) == 'string' and self[arg] then
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
			then
				candidates[#candidates + 1] = c
			end
		end

		return candidates
	end

	ctxcache[def] = setmetatable(compdef, _CMP)
	return ctxcache[def]
end

local completercache = setmetatable({}, { __mode = 'k' })

--- Creates an customlist function from the specified command.
---@param def fltcmd.command the command
---@return fun(lead: string, cmdline: string, cursorpos: integer):string[]
function M.create_completer(def)
	if completercache[def] then
		return completercache[def]
	end

	local ctx = new_ctx(def)

	completercache[def] = function(lead, cmdline, cursorpos)
		local cmdargs = split(cmdline, cursorpos)
		cmdargs[#cmdargs] = nil

		local cmd = ctx
		local maxarg = cmd(nil, nil, nil, true)
		local posarg = math.min(1, maxarg)
		local lastc
		for i = 2, #cmdargs do
			local p = cmdargs[i]
			local c = cmd[p]
			if type(c) == 'table' then
				cmd = c
				lastc = c
				maxarg = cmd(nil, nil, nil, true)
				posarg = math.min(1, maxarg)
			elseif c then
				lastc = p
			elseif not cmd(nil, nil, nil, p) then
				if lastc ~= cmd then
					lastc = cmd
				else
					posarg = posarg + 1
				end
			end
		end

		return cmd(lead, lastc, posarg)
	end

	return completercache[def]
end

---@class fltcmd.valmap
---@field [string] table<string|integer, string>

---@class fltcmd.injector
---@field process fun(cmdline:string[]): fltcmd.injector_result

---@class fltcmd.injector_result
---@field cmdline string[]
---@field existing table<string, string>
---@field missing table
local IR = {}
IR.__index = {}

--- Updates the command line with the specified values.
---@param values table<string, string> The value map to use.
---@return string[] cmdline This objects cmdline.
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

---@param def fltcmd.command
---@param valmap fltcmd.valmap
---@return fltcmd.injector
function M.create_injector(def, valmap)
	local ctx = new_ctx(def)

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

		local injcmd = valmap[cmdline[2]]
		if not injcmd then
			return res
		end

		injcmd = vim.deepcopy(injcmd)

		-- seek where to inject the values
		local cmd = ctx
		local argi = 1
		local posarg = false
		for i = 2, #cmdline do
			local p = cmdline[i]
			local c = cmd[p]
			if type(c) == 'table' then
				cmd = c
				argi = 1
				posarg = false
			elseif c then
				posarg = true
				if injcmd[p] then
					table.insert(res.missing, { i + 1, injcmd[p] })
				end
			elseif not cmd(nil, nil, nil, p) then
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

--- Creates a new command
---@param fn fun(self: fltcmd.command, args: string[], opts?: vim.api.keyset.create_user_command.command_args)
---@param def? fltcmd.def
---@overload fun(definition: fltcmd.basedef): fltcmd.command
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
---@param def fltcmd.command
---@param args string[]
---@return table<string|integer, boolean|number|function>
function M.process_args(def, args)
	local pargs = {}
	local i = 2
	while i <= #args do
		local v = args[i]
		i = i + 1
		local dvt = type(def[v])
		if dvt == 'string' or dvt == 'function' then
			pargs[v] = args[i]
			if pargs[v] then
				i = i + 1
			end
		elseif dvt == 'table' then
			if is_def(def[v]) then
				pargs[v] = function(subargs)
					assert(subargs == args)
					subargs = vim.list_slice(subargs, i - 1)
					def[v](subargs)
				end
				break
			else
				pargs[v] = def[v]
			end
		elseif dvt == 'number' then
			pargs[v] = math.min((pargs[v] or 0) + 1, def[v])
		elseif dvt == 'boolean' then
			pargs[v] = true
		else
			pargs[#pargs + 1] = v
		end
	end

	return pargs
end

---@param cmd fltcmd.command
---@param name string
---@param opts? vim.api.keyset.user_command
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

--- Creates a completion source from a list of specific values.
---@param values any[]
---@return fun(lead:string):string[]
function M.choiceof(values)
	return function(lead)
		return vim.tbl_filter(function(v)
			return vim.startswith(tostring(v), lead)
		end, values)
	end
end

---@alias fltcmd.getcompletion.type
--- | 'arglist'
--- | 'augroup'
--- | 'buffer'
--- | 'breakpoint'
--- | 'cmdline'
--- | 'color'
--- | 'command'
--- | 'compiler'
--- | 'diff_buffer'
--- | 'dir'
--- | 'dir_in_path'
--- | 'environment'
--- | 'event'
--- | 'expression'
--- | 'file'
--- | 'file_in_path'
--- | 'filetype'
--- | 'filetypecmd'
--- | 'function'
--- | 'help'
--- | 'highlight'
--- | 'history'
--- | 'keymap'
--- | 'locale'
--- | 'mapclear'
--- | 'mapping'
--- | 'menu'
--- | 'messages'
--- | 'option'
--- | 'packadd'
--- | 'retab'
--- | 'runtime'
--- | 'scriptnames'
--- | 'shellcmd'
--- | 'shellcmdline'
--- | 'sign'
--- | 'syntax'
--- | 'syntime'
--- | 'tag'
--- | 'tag_listfiles'
--- | 'user'
--- | 'var'

local getcomp = vim.fn.getcompletion

--- Creates a completion source using getcompletion() function.
---@param type fltcmd.getcompletion.type
---@return fun(lead:string):string[]
function M.getcompletion(type)
	return function(lead)
		return getcomp(lead, type, true)
	end
end

return M

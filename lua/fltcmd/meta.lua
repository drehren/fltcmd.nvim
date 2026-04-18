---@meta fltcmd

--- Command completion
---@alias fltcmd.comp fun(lead: string, cmdline: string, pos: integer):string[]

--- Defines how an automatic command should complete
---@class fltcmd.basedef
---@field [string] fltcmd.command

--- Defines how a command should complete
---@class fltcmd.def : fltcmd.basedef
---@field [integer] fltcmd.comp|'...'
---@field [string] fltcmd.command|fltcmd.comp|boolean|integer

--- Represents a single command
---@class fltcmd.command
---@operator call(string[]):any
local C = {}

--- Represents a collection of flags for a command
---@class fltcmd.flags
local F = {}

---@class fltcmd.valmap
---@field [string] table<string|integer, string>

--- Allows values for parameters to be injected into command line.
---@class fltcmd.injector
--- Processes the `cmdline` to get parameters to be replaced.
---@field process fun(cmdline:string[]): fltcmd.injector_result

--- Result of processing a `cmdline` against an injector.
---@class fltcmd.injector_result
--- Command line processed.
---@field cmdline string[]
--- Existing named values in the command line.
---@field existing table<string, string>
--- Possible named values
---@field missing table
local IR = {}

--- Updates the command line with the specified values.
---@param values table<string, string> The value map to use.
---@return string[] cmdline This objects cmdline.
function IR:inject(values) end

local M = {}

--- Creates a new command, calls the specified function.
---@param fn fun(self: fltcmd.command, args: string[], opts?: vim.api.keyset.create_user_command.command_args):any
---@param def? fltcmd.def Command definition
---@return fltcmd.command command
function M.new_command(fn, def) end

--- Creates a new command, which calls one of the defined sub commands.
---@param def fltcmd.basedef
---@return fltcmd.command command
function M.new_command(def) end

--- Creates an command completion customlist function from the specified command.
---@param cmd fltcmd.command A command to create the completion from
---@return fltcmd.comp completer Completion function
function M.create_completer(cmd) end

--- Creates an injector object that can process a command line to extract
--- existing values and inject new ones to the specified options.
---@param cmd fltcmd.command Command to use.
---@param valmap fltcmd.valmap Value map to define option values.
---@return fltcmd.injector injector Injector object.
function M.create_injector(cmd, valmap) end

--- Creates an `user-commands` comamnd that calls `cmd`
---@param name string Name of the new command.
---@param cmd fltcmd.command Command to execute.
---@param opts? vim.api.keyset.user_command Optional flags
function M.create_user_command(name, cmd, opts) end

--- Processes the argument list for the specfied command and returns a table
--- that maps command option to value or existence.
---
--- If the processing find a subcommand it stops there, and creates a special
--- function that will pass the rest of the argument list.
---@param cmd fltcmd.command The command.
---@param args string[] The command arguments.
---@return table<string|integer, boolean|number|function>
function M.process_args(cmd, args) end

--- Splits the line by non-escaped space, last item may be empty
---@param line string Line to split
---@param _end? integer End byte to accout for split
---@return string[]
function M.splitline(line, _end) end

--- Completes to an empty list.
--- Useful to mark entries that require unknown input.
---@return table
function M.any() end

--- Creates a completion source from a list of specific values.
---@param values any[] Available values.
---@return fun(lead:string):string[]
function M.choiceof(values) end

--- Creates a completion source from a function that generates a list of values.
---@param fn fun():any[] Values generator function.
---@return fun(lead:string):string[]
function M.choiceof(fn) end

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

--- Creates a completion source using getcompletion() function.
---@param type fltcmd.getcompletion.type
---@return fun(lead:string):string[]
function M.getcompletion(type) end

--- Defines flags (non-valued options) for command.
---@param flags string[] Command flag list.
---@return fltcmd.flags flag_bag
function M.flags(flags) end

return M

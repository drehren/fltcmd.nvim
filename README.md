# fltcmd.nvim

A simple, basic lib to have command-line like comamnds with completion included
for neovim.

The main use case of this library is to create simple vim user commands using
lua functions or doing cli tools mapping to vim user commands. 

## Usage

- Create a command, that can call another command:
```lua
local fltcmd = require('fltcmd')

local function my_subcmd(scmd, args)
    vim.print(args)
end

local function my_command(mycmd, args)
    local params = fltcmd.process_args(args)

    if params['--file'] then
        -- do something with data in file
    end

    if params.subcmd then
        -- can call subcommands directly, these will take care of argument list
        params.subcmd(args)
    end
end

local subcmd = fltcmd.new_command(my_subcmd)

local command1 = fltcmd.new_command(my_command, {
    ['--file'] = fltcmd.getcompletion('file'), -- uses getcompletion() function
    subcmd = subcmd, -- commands can call other commands
})

-- use like cmd command list, argv[1] must be command name
--        argv[1]       argv[2]     argv[3]
command1({'command1', '--file', 'myfile.txt'})

-- argv[1] can be any string, but it must exist
command1({'mycmd', 'subcmd', '1'})
```

- If there is no need to handle the initial command just pass the definition
as the first parameter:
```lua
local fltcmd = require('fltcmd')

local function cmd1(_, args) ... end
local function cmd2(_, args) ... end
local function cmd3(_, args) ... end

local cmdd = fltcmd.new_command({
    cmd1 = fltcmd.new_command(cmd1, ...),
    cmd2 = fltcmd.new_command(cmd2, ...),
    cmd3 = fltcmd.new_command(cmd3, ...),
})

-- call

cmdd({'d', 'cmd1', ...}) -- will end up calling cmd1
cmdd({'d', 'cmd2', ...}) -- will end up calling cmd2
cmdd({'d', 'cmd3', ...}) -- will end up calling cmd3
```

### Creating a user command

This main purpose of this tiny lib is to help create user-commands with proper
complete.

For this just create a command and then call `fltcmd.create_user_command()`

```lua
local fltcmd = require('fltcmd')

local cmd = fltcmd.new_command({ ... })

fltcmd.create_user_command('MyCmd', cmd, { desc = 'my command' })
```

## Requirements

- neovim >= 0.11.0


## Installing

- Use [vim.pack](https://neovim.io/doc/user/pack/#vim.pack) (neovim >= 0.12); or
```lua
vim.pack.add('https://github.com/drehren/fltcmd.nvim')
```

- Use [vim-plug](https://github.com/junegunn/vim-plug); or
```vim
Plug 'drehren/fltcmd.nvim'
```

- Use [packer.nvim](https://github.com/wbthomason/packer.nvim); or
```lua
use "drehren/fltcmd.nvim"
```

- Use [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
    "drehren/fltcmd.nvim",
    opts = {},
}
```



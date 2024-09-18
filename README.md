# incomplete.nvim

![Usage screenshot](./docs/screen1.png).

This small plugin for Neovim allows using `vim.opt.completefunc` to serve, expand and browse snippets.

## Usage

```lua
require("incomplete").setup()
```

After that, try opening your completefunc (`CTRL-X CTRL-U`)

For now, no configuration is possible.

## Adding snippets

Only vscode-like json snippets are supported, they must be placed in a `snippets/` folder at the root of your
runtimepath (e.g. at `$XDG_CONFIG_HOME/nvim/snippets`).

Snippets in a file or folder named `all.json` will be always loaded. Snippets in files or folders named after vim
filetype will be loaded only for that filetype.

## Friendly Snippets

[friendly-snippets](https://github.com/rafamadriz/friendly-snippets) are supported.

Simply install them using your plugin manager, no need to call any lazy load etc. Incomplete.nvim will load snippets for
a given filetype automatically when opening such buffer.

## Reference

For reference usage, snippets etc. see [my neovim config](https://github.com/konradmalik/neovim-flake).

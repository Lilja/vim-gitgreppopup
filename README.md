# vim-gitgreppopup

Let's you see git grep in a popup window and navigate to that file with that line number.

![out.gif](out.gif)

## Install
with vim-plug:
```vim
Plug 'lilja/vim-gitgreppopup'
```

Init the function:

```vim
let g:gitgreppopup_enable = 1
let g:gitgreppopup_disable_syntax = 1
```

## Usage
`:Ggrep let`

I know this term is already used by fugitive. I'm open for changes.


## Performance

It would appear that syntax highlighting makes this popup a bit sluggish. There is a param called `g:gitgreppopup_disable_syntax` that will temporarily disable syntax and will reenable it after the popup is closed. For me it has decreased the amount slowness.

[A ticket has been created for this](https://github.com/vim/vim/issues/6171)

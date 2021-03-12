function! s:RunGitGrep(search)
    let cmd = printf("git grep --line-number '%s'", a:search)
    return substitute(system(cmd), '\n', '\1', '')
endfunction

function! s:echo_failure(message)
  echohl WarningMsg
  echo a:message
  echohl None
endfunction


function! Cb(lines, winid, result)
    call s:SetSyntax("on")

    if a:result != -1
        if &modified
            call s:echo_failure("GitGrepPopup: You have unsaved changes.")
        endif
        let obj = a:lines[a:result-1]
        let vimCmd = ":e +" . obj.lineNr . " " . obj.file
        execute vimCmd
    endif
endfunction

function! FormatAndPropify(str, regex)
    let strCopy = a:str
    let obj = {"originalStr": a:str, "viewStr": "", "props": [], "lineNr": 0, "file": ""}

    " Remove binary file matces
    if len(matchstr(a:str, "Binary file") > 0) && stridx(a:str, "matches") != -1
        return {}
    endif

    " If the line length is really long(>512), substring the text
    let maxLen = 512
    if len(strCopy) > maxLen
        let strCopy = strCopy[0:maxLen]
    endif

    " Match the file name
    let s:fileNameRegex = '^[^:]*\(:\)\=:'
    let s:beginning = match(strCopy, s:fileNameRegex)
    if s:beginning != -1
        let s:match = matchstr(strCopy, s:fileNameRegex)
        let obj.file = s:match[0:-2]
    endif

    " Match the line number
    " (?<=:)\d+(?=:)
    let s:lineNumberRegex = '\(:\)\@<=\d\+\(:\)\@='
    let s:lineNumberMatch = matchstr(strCopy, s:lineNumberRegex)
    if s:lineNumberMatch != -1
        let obj.lineNr = s:lineNumberMatch
    endif

    " body of file
    let s:grepMetaRegex = s:fileNameRegex . '\d\+:'
    let s:match = matchstr(strCopy, s:grepMetaRegex)
    let content = substitute(strCopy, s:match, '', '')
    let obj.viewStr = obj.file . ": " .obj.lineNr . " " . content

    return obj
endfunction

function! FormatGitOutput(lines, search)
    let allLinesProps = []
    for line in a:lines
        let obj = FormatAndPropify(line, a:search)
        if obj != {}
            call add(allLinesProps, obj)
        endif
    endfor
    return allLinesProps
endfunction


function! FormatPretty(lines)
    let formatted_lines = []
    for obj in a:lines
        call add(formatted_lines, { "text": obj.viewStr })
    endfor
    return formatted_lines
endfunction

function! s:SetSyntax(onOrOff)
    if a:onOrOff == "off"
        if exists("g:gitgreppopup_disable_syntax") && g:gitgreppopup_disable_syntax == 1
            syntax off
        endif
    else
        if exists("g:gitgreppopup_disable_syntax") && g:gitgreppopup_disable_syntax == 1
            syntax on
        endif
    endif
endfunction

function s:RenderPopup(lines, searchTerm)
    let windowHeightSize = float2nr(winheight('%') / 2)
    let windowWidthSize = float2nr(winwidth('%') * 0.80)

    let output = FormatGitOutput(a:lines, a:searchTerm)

    let prettyOutput = FormatPretty(output)
    if exists('*popup_menu')
        let winid = popup_menu(prettyOutput, #{
                    \ pos: "center",
                    \ maxheight: windowHeightSize,
                    \ minwidth: windowWidthSize,
                    \ maxwidth: windowWidthSize,
                    \ callback: funcref("Cb", [output]),
            \ })
    else
        call s:echo_failure("GitGrepPopup: Neovim not supported.") | return
    endif
    highlight default link GitGrepPopupFile  Directory
    highlight default link GitGrepPopupMatch IncSearch
    highlight default link GitGrepPopupLineNumber Number

    call matchadd('GitGrepPopupFile', '^[^:]*\ze\(:\)\@=', 10, -1, {'window': winid})
    call matchadd('GitGrepPopupMatch', a:searchTerm, 10, -1, {'window': winid})
    call matchadd('GitGrepPopupLineNumber', '\(: \)\@<=\d\+', 10, -1, {'window': winid})
endfunction

function! s:GitGrepPopupRun(searchTerm)
    call s:SetSyntax("off")
    let g:gitGrepPrevCommand = a:searchTerm
    let gitGrep = s:RunGitGrep(a:searchTerm)
    let lines = split(gitGrep, '\n')
    if len(lines) == 0
        call s:SetSyntax("on")
        call s:echo_failure("GitGrepPopup: Nothing found.")
    else
        call s:RenderPopup(lines, a:searchTerm)
    endif
endfunction

function! s:GitGrepPopupRerun()
    let prev = get(g:, 'gitGrepPrevCommand', "default")
    if prev != "default"
        call s:GitGrepPopupRun(g:gitGrepPrevCommand)
    endif
endfunction

function! s:GitGrepPopupCursorRun()
    let underCursor = expand("<cword>")
    if underCursor != ""
        call s:GitGrepPopupRun(underCursor)
    endif
endfunction

command! -nargs=* GitGrep :call s:GitGrepPopupRun(<f-args>)
command! -nargs=* GitGrepCursor :call s:GitGrepPopupCursorRun(<f-args>)
command! -nargs=* GitGrepRerun :call s:GitGrepPopupRerun()

function! s:RunGitGrep(search)
    let cmd = "git grep --line-number " . a:search
    return substitute(system(cmd), '\n', '\1', '')
endfunction!


function! Cb(lines, winid, result)
    if exists("g:gitgreppopup_disable_syntax") && g:gitgreppopup_disable_syntax == 1
        syntax on
    endif

    if a:result != -1
        let obj = a:lines[a:result-1]
        let vimCmd = ":e +" . obj.lineNr . " " . obj.file
        execute vimCmd
    endif
endfunction

function! FormatAndPropify(str, regex)
    let obj = {"originalStr": a:str, "viewStr": "", "props": [], "lineNr": 0, "file": ""}

    " Remove binary file matces
    if len(matchstr(a:str, "Binary file") > 0) && stridx(a:str, "matches") != -1
        return {}
    endif

    " Match the file name
    let s:fileNameRegex = '^[^:]*\(:\)\=:'
    let s:beginning = match(a:str, s:fileNameRegex)
    if s:beginning != -1
        let s:match = matchstr(a:str, s:fileNameRegex)
        let obj.file = s:match[0:-2]
    endif

    " Match the line number
    " (?<=:)\d+(?=:)
    let s:lineNumberRegex = '\(:\)\@<=\d\+\(:\)\@='
    let s:lineNumberMatch = matchstr(a:str, s:lineNumberRegex)
    if s:lineNumberMatch != -1
        let obj.lineNr = s:lineNumberMatch
    endif

    " body of file
    let s:grepMetaRegex = s:fileNameRegex . '\d\+:'
    let s:match = matchstr(a:str, s:grepMetaRegex)
    let content = substitute(a:str, s:match, '', '')
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

function! s:GitGrepPopupRun(searchTerm)
    if exists("g:gitgreppopup_disable_syntax") && g:gitgreppopup_disable_syntax == 1
        syntax off
    endif
    let gitGrep = s:RunGitGrep(a:searchTerm)
    let lines = split(gitGrep, '\n')
    if len(lines) == 0
        echo "GitGrepPopup: Nothing found."
        return
    endif
    let windowHeightSize = float2nr(winheight('%') / 2)
    let windowWidthSize = float2nr(winwidth('%') * 0.80)

    let output = FormatGitOutput(lines, a:searchTerm)

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
        echo "Neovim not supported."
    endif
    highlight default link GitGrepPopupFile  Directory
    highlight default link GitGrepPopupMatch IncSearch
    highlight default link GitGrepPopupLineNumber Number

    call matchadd('GitGrepPopupFile', '^[^:]*\ze\(:\)\@=', 10, -1, {'window': winid})
    call matchadd('GitGrepPopupMatch', a:searchTerm, 10, -1, {'window': winid})
    call matchadd('GitGrepPopupLineNumber', '\(: \)\@<=\d\+', 10, -1, {'window': winid})
endfunction

command! -nargs=* GitGrep :call s:GitGrepPopupRun(<f-args>)

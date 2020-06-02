function s:RunGitGrep(search)
    let cmd = "git grep --line-number " . a:search
    return substitute(system(cmd), '\n', '\1', '')
endfunction

function Cb(winid, result)
    if exists("g:gitgreppopup_disable_syntax") && g:gitgreppopup_disable_syntax == 1
        syntax on
    endif

    if a:result != -1
        let obj = g:gitgreppopup_all_lines_props[a:result-1]
        let vimCmd = ":e +" . obj.lineNr . " " . obj.file
        echo vimCmd
        execute vimCmd
    endif
    call DeregisterPropsGlobally()
endfunction

function FormatAndPropify(str, regex)
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
        let s:length = len(s:match)
        let s:end = s:beginning + s:length
        let obj.file = s:match[0:-2]
        call add(obj.props, {"length": s:length, "col": s:beginning, "endcol": s:end, "type": "GitGrepPopupFileType"})
    endif

    " body of file
    let s:grepMetaRegex = s:fileNameRegex . '\d\+:'
    let s:match = matchstr(a:str, s:grepMetaRegex)
    let content = substitute(a:str, s:match, '', '')
    let obj.viewStr = obj.file . " " . content

    " Match the term from user input to the output of git grep
    " TODO: figure out why +1 is needed here..
    let s:beginning = match(obj.viewStr, a:regex) + 1
    if s:beginning != -1
        let s:length = len(matchstr(obj.viewStr, a:regex))
        let s:end = s:beginning + s:length
        call add(obj.props, {"length": s:length, "col": s:beginning, "endcol": s:end, "type": "GitGrepPopupMatchType"})
    endif

    " Match the line number
    " (?<=:)\d+(?=:)
    let s:lineNumberRegex = '\(:\)\@<=\d\+\(:\)\@='
    let s:lineNumberMatch = matchstr(a:str, s:lineNumberRegex)
    if s:lineNumberMatch != -1
        let obj.lineNr = s:lineNumberMatch
    endif

    return obj
endfunction

function FormatGitOutput(lines, search)
    let allLinesProps = []
    for line in a:lines
        let obj = FormatAndPropify(line, a:search)
        if obj != {}
            call add(allLinesProps, obj)
        endif
    endfor
    return allLinesProps
endfunction

function RegisterPropsGlobally(allLinesProps)
   let g:gitgreppopup_all_lines_props = a:allLinesProps 
endfunction


function DeregisterPropsGlobally()
   unlet g:gitgreppopup_all_lines_props
endfunction

function FormatPretty(lines)
    let formatted_lines = []
    for obj in a:lines
        if len(obj.props) != 0
            call add(formatted_lines, { "text": obj.viewStr, "props": obj.props })
        else
            call add(formatted_lines, { "text": obj.viewStr })
        endif
    endfor
    return formatted_lines
endfunction

function s:GitGrepPopupRun(searchTerm)
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

    " highlight GitGrepPopupFile term=italic cterm=italic cterm
    " highlight GitGrepPopupMatch term=italic cterm=italic ctermbg=red

    if prop_type_get("GitGrepPopupMatchType") == {}
        call prop_type_add("GitGrepPopupMatchType", {"highlight": "IncSearch"})
    endif

    if prop_type_get("GitGrepPopupFileType") == {}
        call prop_type_add("GitGrepPopupFileType", {"highlight": "Directory"})
    endif
    let output = FormatGitOutput(lines, a:searchTerm)
    call RegisterPropsGlobally(output)

    let prettyOutput = FormatPretty(output)
    let winid = popup_menu(prettyOutput, #{
                \ pos: "center",
                \ maxheight: windowHeightSize,
                \ minwidth: windowWidthSize,
                \ maxwidth: windowWidthSize,
                \ callback: "Cb",
        \ })
endfunction

command -nargs=* GitGrep :call s:GitGrepPopupRun(<f-args>)

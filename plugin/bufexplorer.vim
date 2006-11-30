"=============================================================================
"    Copyright: Copyright (C) 2001-2006 Jeff Lanzarotta
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               bufexplorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
" Name Of File: bufexplorer.vim
"  Description: Buffer Explorer Vim Plugin
"   Maintainer: Jeff Lanzarotta (delux256-vim at yahoo dot com)
" Last Changed: Thursday, 30 November 2006
"      Version: See g:loaded_bufexplorer for version number.
"        Usage: Normally, this file should reside in the plugins
"               directory and be automatically sourced. If not, you must
"               manually source this file using ':source bufexplorer.vim'.
"
"               You may use the default keymappings of
"
"                 <Leader>be  - Opens BufExplorer
"                 <Leader>bs  - Opens split window BufExplorer
"                 <Leader>bv  - Opens vertical split window BufExplorer
"
"               Or you can use
"
"                 ":BufExplorer" - Opens BufExplorer
"                 ":SBufExplorer" - Opens split window BufExplorer
"                 ":VSBufExplorer" - Opens vertical split window BufExplorer
"
"               For more help see supplied documentation.
"      History: See supplied documentation.
"=============================================================================

" Exit quickly when BufExplorer has already been loaded or when 'compatible'
" is set.
if exists("g:loaded_bufexplorer") || &cp
  finish
endif

" Version number.
let g:loaded_bufexplorer = "7.0.12"

" Show default help? If you set this to 0, you're on your own remembering that
" '<F1>' brings up the help and what the sort order is.
" 0 = Don't show, 1 = Do show.
if !exists("g:bufExplorerDefaultHelp")
  let g:bufExplorerDefaultHelp = 1
endif

" Show detailed help by default?
" 0 = Don't show, 1 = Do show.
if !exists("g:bufExplorerDetailedHelp")
  let g:bufExplorerDetailedHelp = 0
endif

" Sort method.
" Can be either 'number', 'name', 'mru', 'fullpath', or 'extension'.
if !exists("g:bufExplorerSortBy")
  let g:bufExplorerSortBy = "mru"
endif

" When opening a new window, split the new windows below or above the
" current window?  1 = below, 0 = above.
if !exists("g:bufExplorerSplitBelow")
  let g:bufExplorerSplitBelow = &splitbelow
endif

" When opening a new window, split the new windows to the right or to the left
" of the current window?  1 = right, 0 = left.
if !exists("g:bufExplorerSplitRight")
  let g:bufExplorerSplitRight = &splitright
endif

" When opening a new window, split the new window horizontally or vertically?
" '' = Horizontal, 'v' = Vertical.
if !exists("g:bufExplorerSplitType")
  let g:bufExplorerSplitType = ""
endif

" When selected buffer is opened, open in current window or open a separate
" one. 1 = use current, 0 = use new.
if !exists("g:bufExplorerOpenMode")
  let g:bufExplorerOpenMode = 0
endif

" When opening a new window vertically, set the width to be this value.
if !exists("g:bufExplorerSplitVertSize")
  let g:bufExplorerSplitVertSize = 0
endif

" When opening a new window horizontally, set the height to be this value.
if !exists("g:bufExplorerSplitHorzSize")
  let g:bufExplorerSplitHorzSize = 0
endif

" Whether to sort in forward or reverse order.
" 1 = forward, -1 = reverse.
if !exists("g:bufExplorerSortDirection")
  let g:bufExplorerSortDirection = 1
endif

if g:bufExplorerSortDirection == 1
  let s:sortDirLabel = ""
elseif g:bufExplorerSortDirection = -1
  let s:sortDirLabel = "reverse "
endif

" Whether to split out the path and file name or not.
" 0 = Don't split, 1 = Do split.
if !exists("g:bufExplorerSplitOutPathName")
  let g:bufExplorerSplitOutPathName = 1
endif

" Whether to show directories in the buffer list or not. Directories
" usually show up in the list from using a command like ":e .".
" 0 = Don't show, 1 = Do show.
if !exists("g:bufExplorerShowDirectories")
  let g:bufExplorerShowDirectories = 1
endif

" Whether to show absolute paths or relative to the current directory.
" 0 = Show absolute paths, 1 = Show relative paths
if !exists("g:bufExplorerShowRelativePath")
  let g:bufExplorerShowRelativePath = 0
endif

" Used to make sure that only one BufExplorer is open at a time.
if !exists("g:bufExplorerRunning")
  let g:bufExplorerRunning = 0
endif

" Check to make sure the Vim version 700 or greater.
if v:version < 700
  echo "Sorry, bufexplorer ".g:loaded_bufexplorer." ONLY runs with Vim 7.0 and greater"
  finish
endif

let s:MRUList = []
let s:sort_by = ["number", "name", "fullpath", "mru", "extension"]

" Setup the autocommands that handle the MRUList and other stuff.
augroup bufexplorer
  autocmd!
  autocmd BufEnter * call <SID>MRUPush()
  autocmd BufEnter * call <SID>SetAltBufName()
  autocmd BufDelete * call <SID>MRUPop()
  autocmd BufWinEnter \[BufExplorer\] call <SID>Initialize()
  autocmd BufWinLeave \[BufExplorer\] call <SID>Cleanup()
  autocmd VimEnter * call <SID>BuildInitialMRU()
augroup End

" Create commands
if !exists(":BufExplorer")
  command BufExplorer :call <SID>StartBufExplorer("drop")
endif

if !exists(":SBufExplorer")
  command SBufExplorer :call <SID>StartBufExplorer("sp")
endif

if !exists(":VSBufExplorer")
  command VSBufExplorer :call <SID>StartBufExplorer("vsp")
endif

" Public Interfaces
map <silent> <unique> <Leader>be :BufExplorer<CR>
map <silent> <unique> <Leader>bs :SBufExplorer<CR>
map <silent> <unique> <Leader>bv :VSBufExplorer<CR>

" Winmanager Integration {{{
let g:BufExplorer_title = "\[Buf\ List\]"

if !exists("g:bufExplorerResize")
  let g:bufExplorerResize = 1
endif

" Function to start display.
" set the mode to 'winmanager' for this buffer. this is to figure out how this
" plugin was called. in a standalone fashion or by winmanager.
function! BufExplorer_Start()
  let b:displayMode = "winmanager"

  call s:StartBufExplorer("e")
endfunction

" Returns whether the display is okay or not.
function! BufExplorer_IsValid()
  return 0
endfunction

" Handles dynamic refreshing of the window.
function! BufExplorer_Refresh()
  let b:displayMode = "winmanager"

  call s:StartBufExplorer("e")
endfunction

" Handles dynamic resizing of the window.
if !exists("g:bufExplorerMaxHeight")
  let g:bufExplorerMaxHeight = 25
endif

" BufExplorer_ReSize.
function! BufExplorer_ReSize()
  if !g:bufExplorerResize
    return
  end

  let nlines = min([line("$"), g:bufExplorerMaxHeight])

  exe nlines." wincmd _"

  " The following lines restore the layout so that the last file line is also
  " the last window line. Sometimes, when a line is deleted, although the
  " window size is exactly equal to the number of lines in the file, some of
  " the lines are pushed up and we see some lagging '~'s.
  let presRow = line(".")
  let presCol = virtcol(".")

  exe $

  let _scr = &scrolloff
  let &scrolloff = 0

  normal! z-

  let &scrolloff = _scr

  exe presRow
  exe "keepjumps normal! ".presCol."|"
endfunction
" --- End Winmanager Integration

" Initialize {{{1
function! s:Initialize()
  let s:_insertmode = &insertmode
  set noinsertmode

  let s:_showcmd = &showcmd
  set noshowcmd

  let s:_cpo = &cpo
  set cpo&vim

  let s:_report = &report
  let &report = 10000

  let s:_list = &list
  set nolist

  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal cursorline
  setlocal nospell

  let g:bufExplorerRunning = 1
endfunction

" Cleanup {{{1
function! s:Cleanup()
  let &insertmode = s:_insertmode
  let &showcmd = s:_showcmd
  let &cpo = s:_cpo
  let &report = s:_report
  let &list = s:_list
  let g:bufExplorerRunning = 0
endfunction

" StartBufExplorer {{{1
function! s:StartBufExplorer(split)
  let name = '[BufExplorer]'

  if !has("win32")
    " On non-Windows boxes, escape the name so that is shows up correctly.
    let name = escape(name, "[]")
  endif

  " Make sure there is only one explorer open at a time.
  if g:bufExplorerRunning == 1
    " Go to the open buffer.
    exec "drop" name
    return
  endif

  silent let s:raw_buffer_listing = s:GetBufferList()

  if s:DoAnyMoreBuffersExist() == 0
    echo "\r"
    echohl WarningMsg | echo "Sorry, there are no more buffers to explore"
    echohl none

    return
  endif

  " Get the alternate buffer number for later, just in case
  let nr = bufnr("#")
  if buflisted(nr)
    let s:altBufNbr = nr
  endif

  let s:numberOfOpenWindows = winnr("$")
  let s:MRUListSaved = copy(s:MRUList)

  if !exists("b:displayMode") || b:displayMode != "winmanager"
    " Do not use keepalt when opening bufexplorer to allow the buffer that we
    " are leaving to become the new alternate buffer
    let [_splitbelow, _splitright] = [&splitbelow, &splitright]
    let [&splitbelow, &splitright] = [g:bufExplorerSplitBelow, g:bufExplorerSplitRight]
    exe "silent!" a:split name
    let [&splitbelow, &splitright] = [_splitbelow, _splitright]

    let s:splitWindow = winnr("$") > s:numberOfOpenWindows

    if s:splitWindow
      " Resize
      let [s, c] = (a:split =~ "v") ? [g:bufExplorerSplitVertSize, "|"] : [g:bufExplorerSplitHorzSize, "_"]
      if (s > 0)
        exe s "wincmd" c
      endif
    endif
  endif

  call s:DisplayBufferList()
endfunction

" DisplayBufferList {{{1
function! s:DisplayBufferList()
  setlocal bufhidden=delete
  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap

  if has("syntax")
    call s:SetupSyntax()
  endif

  call s:MapKeys()
  call s:AddHeader()
  call s:BuildBufferList()
  call cursor(s:firstBufferLine, 1)

  if !g:bufExplorerResize
    normal! zz
  endif

  setlocal nomodifiable
endfunction

" MapKeys {{{1
function! s:MapKeys()
  if exists("b:displayMode") && b:displayMode == "winmanager"
    nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer(1)<cr>
  endif

  nnoremap <buffer> <silent> <F1> :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <silent> <2-leftmouse> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> <cr> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> d :call <SID>DeleteBuffer()<cr>
  nnoremap <buffer> <silent> m :call <SID>MRUListShow()<cr>

  if s:splitWindow == 1
    nnoremap <buffer> <silent> o :call <SID>ToggleOpenMode()<cr>
  endif

  nnoremap <buffer> <silent> p :call <SID>ToggleSplitOutPathName()<cr>
  nnoremap <buffer> <silent> q :call <SID>Close()<cr>
  nnoremap <buffer> <silent> r :call <SID>SortReverse()<cr>
  nnoremap <buffer> <silent> R :call <SID>ToggleShowRelativePath()<cr>
  nnoremap <buffer> <silent> s :call <SID>SortSelect()<cr>
  nnoremap <buffer> <silent> S :call <SID>SelectBuffer(1)<cr>
  nnoremap <buffer> <silent> t :call <SID>ToggleSplitType()<cr>

  for k in ["G", "n", "N", "L", "M", "H"]
    exec "nnoremap <buffer> <silent>" k ":keepjumps normal!" k."<cr>"
  endfor
endfunction

" SetupSyntax {{{1
if has("syntax")
  function! s:SetupSyntax()
    syn match bufExplorerHelp     "^\"[ -].*"
    syn match bufExplorerHelpEnd  "^\"=.*$"
    syn match bufExplorerSortBy   "^\" Sorted by .*$"
    syn match bufExplorerOpenIn   "^\" Open in .*$"
    syn match bufExplorerBufNbr   /^\s*\d\+/

    syn match bufExplorerModBuf    /^\s*\d\+.\{4}+.*$/
    syn match bufExplorerLockedBuf /^\s*\d\+.\{3}[\-=].*$/
    syn match bufExplorerHidBuf    /^\s*\d\+.\{2}h.*$/
    syn match bufExplorerActBuf    /^\s*\d\+.\{2}a.*$/
    syn match bufExplorerCurBuf    /^\s*\d\+.%.*$/
    syn match bufExplorerAltBuf    /^\s*\d\+.#.*$/

    if !exists("g:did_bufexplorer_syntax_inits")
      let g:did_bufexplorer_syntax_inits = 1

      hi def link bufExplorerBufNbr Number
      hi def link bufExplorerHelp Special
      hi def link bufExplorerHelpEnd Special
      hi def link bufExplorerOpenIn String
      hi def link bufExplorerSortBy String

      hi def link bufExpFlagTagged Statement
      hi def link bufExplorerUnlisted Comment
      hi def link bufExplorerHidBuf Constant
      hi def link bufExplorerActBuf Identifier
      hi def link bufExplorerCurBuf Type
      hi def link bufExplorerAltBuf String
      hi def link bufExplorerModBuf Exception
      hi def link bufExplorerLockedBuf Special
    endif
  endfunction
endif

" GetHelpStatus {{{1
function! s:GetHelpStatus()
  let h = '" Sorted by '.s:sortDirLabel.g:bufExplorerSortBy

  if s:splitWindow == 1
    if g:bufExplorerOpenMode == 1
      let h .= ' | Open in Same window'
    else
      let h .= ' | Open in New window'
    endif
  endif

  if empty(g:bufExplorerSplitType)
    let h .= ' | Horizontal split'
  else
    let h .= ' | Vertical split'
  endif

  return h
endfunction

" AddHeader {{{1
function! s:AddHeader()
  if g:bufExplorerDefaultHelp == 0 && g:bufExplorerDetailedHelp == 0
    let s:firstBufferLine = 1
    return
  endif

  let header = []

  if g:bufExplorerDetailedHelp == 1
    call add(header, '" Buffer Explorer ('.g:loaded_bufexplorer.')')
    call add(header, '" --------------------------')
    call add(header, '" <F1> : toggle this help')
    call add(header, '" <enter> or Mouse-Double-Click : open buffer under cursor')
    call add(header, '" S : open buffer under cursor in new split window')
    call add(header, '" d : delete buffer')

    if s:splitWindow == 1
      call add(header, '" o : toggle open mode')
    endif

    call add(header, '" p : toggle spliting of file and path name')
    call add(header, '" R : toggle showing relative or short paths')
    call add(header, '" q : quit the Buffer Explorer')
    call add(header, '" s : select sort field '.string(s:sort_by).'')

    if s:splitWindow == 1
      call add(header, '" t : toggle split type')
    endif

    call add(header, '" r : reverse sort')
  else
    call add(header, '" Press <F1> for Help')
  endif

  let h = s:GetHelpStatus()

  call add(header, h)
  call add(header, '"=')
  let s:firstBufferLine = len(header) + 1
  call setline(1, header)
endfunction

" GetBufferList {{{1
function! s:GetBufferList()
  redir => bufoutput
  buffers
  redir END

  let bufs = split(bufoutput, '\n')
  let all = []
  let bufferNameWidths = []

  for buf in bufs
    let b = {}
    let bufName = matchstr(buf, '"\zs.\+\ze"')
    let nameOnly = fnamemodify(bufName, ":t")

    if (nameOnly =~ '^\[.\+\]')
      let b["fullname"] = nameOnly
      let b["shortname"] = nameOnly
      let b["relativename"] = nameOnly
      let b["path"] = ""
      let b["relativepath"] = ""
    else
      let b["relativename"] = fnamemodify(bufName, ':~:.')
      let b["fullname"] = fnamemodify(bufName, ":p")

      if getftype(b["fullname"]) == "dir" && g:bufExplorerShowDirectories == 1
        let b["shortname"] = "<DIRECTORY>"
      else
        let b["shortname"] = fnamemodify(bufName, ":t")
      end

      let b["relativepath"] = fnamemodify(b["relativename"], ':h')
      let b["path"] = fnamemodify(b["fullname"], ":h")
    endif

    let b["attributes"] = matchstr(buf, '^\zs.\{-1,}\ze"')
    call add(all, b)

    call add(bufferNameWidths, strlen(b["shortname"]))
  endfor

  let s:maxBufferNameWidth = max(bufferNameWidths)

  return all
endfunction

" BuildBufferList {{{1
function! s:BuildBufferList()
  let lines = []

  let pathPad = repeat(' ', s:maxBufferNameWidth)

  " Loop through every buffer.
  for buf in s:raw_buffer_listing
     let line = buf["attributes"]." "

     if g:bufExplorerSplitOutPathName
       let path = (g:bufExplorerShowRelativePath) ? buf["relativepath"] : buf["path"]
       let line .= buf["shortname"].strpart(pathPad.path, strlen(buf["shortname"]) - 1)
     else
       let line .= (g:bufExplorerShowRelativePath) ? buf["relativename"] : buf["fullname"]
     endif

     call add(lines, line)
  endfor

  call setline(s:firstBufferLine, lines)

  call s:SortListing()
endfunction

" SelectBuffer {{{1
function! s:SelectBuffer(split)
  " Sometimes messages are not cleared when we get here so it looks like an
  " error has occurred when it really has not.
  echo ""

  " Are we on a line with a file name?
  if getline('.') =~ '^"'
    return
  endif

  let _bufNbr = s:ExtractBufferNbr(getline('.'))

  if exists("b:displayMode") && b:displayMode == "winmanager"
    let bufname = expand("#"._bufNbr.":p")

    call WinManagerFileEdit(bufname, a:split)

    return
  end

  if bufexists(_bufNbr)
    let ka = "keepalt"

    " bufExplorerOpenMode: 1 == use current, 0 == use new
    if (g:bufExplorerOpenMode && s:splitWindow) || (!s:splitWindow && a:split)
      " we will return to the previous buffer before opening the new one, so
      " be sure to not use the keepalt modifier
      silent bd!
      let ka = ""
    endif

    if bufnr("#") == _bufNbr
      " we are about to set the % # buffers to the same thing, so open the
      " original alt buffer first to restore it. This only happens when
      " selecting the current (%) buffer.
      try
        exe "keepjumps silent! b!" s:altBufNbr
      catch
      endtry

      let ka = ""
    endif

    let cmd = (a:split) ? (g:bufExplorerSplitType == "v") ? "vert sb" : "sb" : "b!"
    let [_splitbelow, _splitright] = [&splitbelow, &splitright]
    let [&splitbelow, &splitright] = [g:bufExplorerSplitBelow, g:bufExplorerSplitRight]
    exe ka "keepjumps silent" cmd _bufNbr
    let [&splitbelow, &splitright] = [_splitbelow, _splitright]
  else
    setlocal modifiable
    keepjumps d _
    setlocal nomodifiable

    echoerr "Sorry, that buffer no longer exists, please select another"
  endif
endfunction

" DeleteBuffer {{{1
function! s:DeleteBuffer()
  if getline('.') =~ '^"'
    return
  endif

  let _bufNbr = s:ExtractBufferNbr(getline('.'))

  " Do not allow this buffer to be deleted if it is the last one.
  if len(s:MRUList) == 1
    echohl ErrorMsg | echo "Sorry, you are not allowed to delete the last buffer"
    echohl none

    return
  endif

  " These commands are to temporarily suspend the activity of winmanager.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerSuspendAUs()
  end

  if getbufvar(_bufNbr, '&modified') == 1
    echohl ErrorMsg | echo "Sorry, no write since last change for buffer "._bufNbr.", unable to delete"
    echohl none
  else
    exe "silent! bw "._bufNbr

    setlocal modifiable
    " Does not move cursor (d _ does)
    keepjumps normal! "_dd
    setlocal nomodifiable

    call s:MRUPop(_bufNbr)

    " Delete the buffer from the raw buffer list
    call filter(s:raw_buffer_listing, 'v:val["attributes"] !~ " '._bufNbr.' "')
  endif

  " Reactivate winmanager autocommand activity.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
    call WinManagerResumeAUs()
  end
endfunction

" Close {{{1
function! s:Close()
  let alt = bufnr("#")

  if (s:numberOfOpenWindows > 1 && !s:splitWindow)
    " if we "bw" in this case, then the previously existing split will be
    " lost, so open the most recent item in the MRU list instead.
    for b in s:MRUListSaved
      try
        exec "silent b" b
        break
      catch
      endtry
    endfor
  else
    " If this is the only window, then let Vim choose the buffer to go to.
    bw!
  endif

  if (alt == bufnr("%"))
    " This condition is true most of the time. The alternate buffer is the one
    " that we just left when we opened the bufexplorer window. Vim will select
    " another buffer for us if we've deleted the current buffer. In that case,
    " we will not need to restore the alternate buffer because it was
    " clobbered anyway.
    try
      " Wrap this into a try/catch block because we do not want "b #" to execute
      " if "b s:altBufNbr" fails
      exec "silent b" s:altBufNbr
      silent b #
    catch
    endtry
  endif
endfunction

" ToggleHelp {{{1
function! s:ToggleHelp()
  let g:bufExplorerDetailedHelp = !g:bufExplorerDetailedHelp

  " Save position
  let orig_size = line("$")
  let [line, col] = [line("."), col('.')]

  " get list of buffers
  let buffs = getline(1, "$")
  call filter(buffs, 'v:val !~ "^\""')

  setlocal modifiable

  " Remove old info
  keepjumps silent! % d _

  call <SID>AddHeader()

  call setline(s:firstBufferLine, buffs)

  setlocal nomodifiable

  let new_size = line("$")
  let line = line + new_size - orig_size

  call cursor(line, col)

  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
  end
endfunction

" ToggleSplitOutPathName {{{1
function! s:ToggleSplitOutPathName()
  let g:bufExplorerSplitOutPathName = !g:bufExplorerSplitOutPathName
  setlocal modifiable

  let curPos = getpos('.')

  call <SID>BuildBufferList()
  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" ToggleShowRelativePath {{{1
function! s:ToggleShowRelativePath()
  let g:bufExplorerShowRelativePath = !g:bufExplorerShowRelativePath
  setlocal modifiable

  let curPos = getpos('.')

  call <SID>BuildBufferList()
  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" ToggleOpenMode {{{1
function! s:ToggleOpenMode()
  let g:bufExplorerOpenMode = !g:bufExplorerOpenMode
  if s:firstBufferLine > 1
    setlocal modifiable

    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)

    setlocal nomodifiable
  endif
endfunction

" ToggleSplitType {{{1
function! s:ToggleSplitType()
  if empty(g:bufExplorerSplitType)
    let g:bufExplorerSplitType = "v"
  else
    let g:bufExplorerSplitType = ""
  endif

  if s:firstBufferLine > 1
    setlocal modifiable

    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)

    setlocal nomodifiable
  endif
endfunction

" ExtractBufferNbr {{{1
function! s:ExtractBufferNbr(line)
  return matchstr(a:line, '\d\+') + 0
endfunction

" MRUCmp {{{1
function! s:MRUCmp(line1, line2)
  return index(s:MRUList, s:ExtractBufferNbr(a:line1)) - index(s:MRUList, s:ExtractBufferNbr(a:line2))
endfunction

" SortReverse {{{1
function! s:SortReverse()
  if g:bufExplorerSortDirection == -1
    let g:bufExplorerSortDirection = 1
    let s:sortDirLabel = ""
  else
    let g:bufExplorerSortDirection = -1
    let s:sortDirLabel = "reverse "
  endif

  setlocal modifiable

  let curPos = getpos('.')

  call <SID>SortListing()

  if s:firstBufferLine > 1
    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)
  endif

  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" SortSelect {{{1
function! s:SortSelect()
  let i = index(s:sort_by, g:bufExplorerSortBy)
  let i += 1
  let g:bufExplorerSortBy = get(s:sort_by, i, s:sort_by[0])

  setlocal modifiable

  let curPos = getpos('.')

  call <SID>SortListing()

  if s:firstBufferLine > 1
    let text = s:GetHelpStatus()
    call setline(s:firstBufferLine - 2, text)
  endif

  call setpos('.', curPos)

  setlocal nomodifiable
endfunction

" SortListing {{{1
function! s:SortListing()
  let start = s:firstBufferLine

  let reverse = (g:bufExplorerSortDirection == 1) ? "": "!"

  if g:bufExplorerSortBy == "number"
    " Easiest case.
    exec start.",$sort".reverse 'n'
  elseif g:bufExplorerSortBy == "name"
    if g:bufExplorerSplitOutPathName
      exec start.",$sort".reverse 'i /^\s*\d\+.\{7}/'
    else
      " Ignore everything in the line until the last path separator.
      exec start.",$sort".reverse 'i /.*[\/\\]/'
    endif
  elseif g:bufExplorerSortBy == "fullpath"
    if g:bufExplorerSplitOutPathName
      " Sort twice ~ first on the file name then on the path.
      exec start.",$sort".reverse 'i /^\s*\d\+.\{7}/'
      exec start.",$sort".reverse 'i /^\s*\d\+.\{8}\S\+\s\+/'
    else
      " No-brainer, just like sort by name.
      exec start.",$sort".reverse 'i /^\s*\d\+.\{7}/'
    endif
  elseif g:bufExplorerSortBy == "extension"
    exec start.",$sort".reverse 'i /^\s*\d\+.\{7}\S*\./'
  elseif g:bufExplorerSortBy == "mru"
    let l = getline(start, "$")

    call sort(l, "<SID>MRUCmp")

    if (!empty(reverse))
      call reverse(l)
    endif

    call setline(start, l)
  endif
endfunction

" SetAltBufName {{{1
function! s:SetAltBufName()
  let b:altFileName = '# '.expand("#:t")
endfunction

" MRUPush {{{1
function! s:MRUPush()
  let bufNbr = bufnr("%")

  " Skip temporary buffer with buftype set.
  if !empty(getbufvar(bufNbr, "&buftype"))
    return
  endif

  if !buflisted(bufNbr)
    return
  end

  " Don't add the BufExplorer window to the list.
  if fnamemodify(bufname(bufNbr), ":t") == "[BufExplorer]"
    return
  end

  call s:MRUPop(bufNbr)
  call insert(s:MRUList,bufNbr)
endfunction

" MRUPop {{{1
function! s:MRUPop(...)
  let _bufNbr = (a:0) ? a:1 : bufnr("%")

  let idx = index(s:MRUList, _bufNbr)

  if (idx != -1)
    call remove(s:MRUList, idx)
  endif
endfunction

" BuildInitialMRU {{{1
function! s:BuildInitialMRU()
  let s:MRUList = range(1, bufnr('$'))
  call filter(s:MRUList, 'buflisted(v:val)')
endfunction

" MRUListShow {{{1
function! s:MRUListShow()
  echomsg "MRUList=".string(s:MRUList)
endfunction

" DoAnyMoreBuffersExist {{{1
function! s:DoAnyMoreBuffersExist()
  return len(s:raw_buffer_listing) > 1
endfunction

" BufExplorerGetAltBuf {{{1
function! BufExplorerGetAltBuf()
  if exists("b:altFileName")
    return b:altFileName
  else
    return ""
endfunction

" vim:ft=vim foldmethod=marker sw=2

"=============================================================================
"    Copyright: Copyright (C) 2001-2003 Jeff Lanzarotta
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               bufexplorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
" Name Of File: bufexplorer.vim
"  Description: Buffer Explorer Vim Plugin
"   Maintainer: Jeff Lanzarotta (jefflanzarotta at yahoo dot com)
"          URL: http://lanzarotta.tripod.com/vim/plugin/6/bufexplorer.vim.zip
"  Last Change: Tuesday, 18 March 2003
"      Version: 6.1.4
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
if exists("loaded_bufexplorer") || &cp
  finish
endif

let loaded_bufexplorer = 1

" Setup the global MRUList.
let g:MRUList = ","

" Setup the autocommands that handle the MRUList and other stuff.
augroup bufexplorer
  autocmd!
  autocmd BufEnter * silent call <SID>MRUPush()
  autocmd BufDelete * silent call <SID>MRUPop()
  autocmd BufEnter \[BufExplorer\] silent call <SID>Initialize()
  autocmd BufLeave \[BufExplorer\] silent call <SID>Cleanup()
augroup End

" Create commands
if !exists(":BufExplorer")
  command BufExplorer :call <SID>StartBufExplorer(0)
endif

if !exists(":SBufExplorer")
  command SBufExplorer :call <SID>StartBufExplorer(1)
endif

if !exists(":VSBufExplorer")
  command VSBufExplorer :call <SID>StartBufExplorer(2)
endif

" Public Interfaces
if !hasmapto("<Plug>StartBufExplorer")
  map <silent> <unique> <Leader>be :BufExplorer<CR>
endif

if !hasmapto("<Plug>SplitBufExplorer")
  map <silent> <unique> <Leader>bs :SBufExplorer<CR>
endif

if !hasmapto("<Plug>VerticalSplitBufExplorer")
  map <silent> <unique> <Leader>bv :VSBufExplorer<CR>
endif

" Show detailed help by default?
" 0 = Don't show, 1 = Do show.
if !exists("g:bufExplorerDetailedHelp")
  let g:bufExplorerDetailedHelp = 0
endif

" Sort method.
" Can be either 'number', 'name' or 'mru'.
if !exists("g:bufExplorerSortBy")
  let g:bufExplorerSortBy = "mru"
endif

" When opening a new window, split the new windows below or above the
" current window?  1 = below, 0 = above.
if !exists("g:bufExplorerSplitBelow")
  let g:bufExplorerSplitBelow = &splitbelow
endif

" When opening a new window, split the new window horzontally or vertically?
" '' = Horizontal, 'v' = Vertical.
if !exists("g:bufExplorerSplitType")
  let g:bufExplorerSplitType = ""
endif

" When selected buffer is opened, open in current window or open a separate
" one. 1 = use current, 0 = use new.
if !exists("g:bufExplorerOpenMode")
  let g:bufExplorerOpenMode = 0
endif

" Whether to sort in forward or reverse order.
" 1 = forward, -1 = reverse.
if !exists("g:bufExplorerSortDirection")
  let g:bufExplorerSortDirection = 1
  let s:sortDirLabel = ""
else
  let s:sortDirLabel = "reverse "
endif

" Whether to split out the path and file name or not.
" 0 = Don't split, 1 = Do split.
if !exists("g:bufExplorerSplitOutPathName")
  let g:bufExplorerSplitOutPathName = 1
endif

" Used to make sure that only one BufExplorer is open at a time.
if !exists("g:bufExplorerRunning")
  let g:bufExplorerRunning = 0
endif

" Characters that must be escaped for a regular expression.
let s:escregexp = "/*^$.~\[]"
let s:hideNames = "\\[[^\\]]*\\]"

" Winmanager Integration {{{
let g:BufExplorer_title = "[Buf List]"

if !exists("g:bufExplorerResize")
  let g:bufExplorerResize = 1
endif

" Function to start display.
" set the mode to 'winmanager' for this buffer. this is to figure out how this
" plugin was called. in a standalone fashion or by winmanager.
function! BufExplorer_Start()
  let b:displayMode = "winmanager"
  let s:bufExplorerSplitWindow = 0
  call s:StartBufExplorer(0)
endfunction

" Returns whether the display is okay or not.
function! BufExplorer_IsValid()
  return 0
endfunction

" Handles dynamic refreshing of the window.
function! BufExplorer_Refresh()
  let b:displayMode = "winmanager"
  call s:StartBufExplorer(0)
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

  let nlines = line("$")

  if nlines > g:bufExplorerMaxHeight
    let nlines = g:bufExplorerMaxHeight
  endif

  exe nlines." wincmd _"

  " The following lines restore the layout so that the last file line is also
  " the last window line. sometimes, when a line is deleted, although the
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
  exe "normal! ".presCol."|"
endfunction
" --- End Winmanager Integration

" Initialize {{{1
function! <SID>Initialize()
  let s:_insertmode = &insertmode
  set noinsertmode

  let s:_showcmd = &showcmd
  set noshowcmd

  let s:_cpo = &cpo
  set cpo&vim

  let s:_report = &report
  let &report = 10000

  setlocal nonumber
  setlocal foldcolumn=0

  let s:_splitType = g:bufExplorerSplitType

  let g:bufExplorerRunning = 1
endfunction

" Cleanup {{{1
function! <SID>Cleanup()
  let &insertmode = s:_insertmode
  let &showcmd = s:_showcmd
  let &cpo = s:_cpo
  let &report = s:_report
  let g:bufExplorerSplitType = s:_splitType

  let g:bufExplorerRunning = 0
endfunction

" StartBufExplorer {{{1
function! <SID>StartBufExplorer(split)
  " Make sure there is only one explorer open at a time.
  if g:bufExplorerRunning == 1
    return
  endif

  if <SID>DoAnyMoreBuffersExist() == 0
    echomsg "Sorry, there are no more buffers to be explored"
    return
  endif

  let _splitbelow = &splitbelow

  if a:split == 2
    let g:bufExplorerSplitType = "v"
  endif

  " Save current and alternate buffer numbers for later.
  let s:curBufNbr = <SID>MRUGet(1)
  let s:altBufNbr = <SID>MRUGet(2)

  let &splitbelow = g:bufExplorerSplitBelow

  if !exists("b:displayMode") || b:displayMode != "winmanager"
    if a:split || (&modified && &hidden == 0)
      if has("win32")
        exe "silent! ".g:bufExplorerSplitType."sp [BufExplorer]"
      else
        exe "silent! ".g:bufExplorerSplitType."sp \[BufExplorer\]"
      endif

      let s:bufExplorerSplitWindow = 1
    else
      if has("win32")
        exe "silent! e [BufExplorer]"
      else
        exe "silent! e \[BufExplorer\]"
      endif

      let s:bufExplorerSplitWindow = 0
    endif
  endif

  call <SID>DisplayBuffers()

  let &splitbelow = _splitbelow
endfunction

" DisplayBuffers {{{1
function! <SID>DisplayBuffers()
  setlocal bufhidden=delete
  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap

  if has("syntax")
    call <SID>SetupSyntax()
  endif

  if exists("b:displayMode") && b:displayMode == "winmanager"
    nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer(1)<cr>
  endif

  nnoremap <buffer> <silent> ? :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <silent> <2-leftmouse> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> <cr> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> d :call <SID>DeleteBuffer()<cr>

  if s:bufExplorerSplitWindow == 1
    nnoremap <buffer> <silent> o :call <SID>ToggleOpenMode()<cr>
    nnoremap <buffer> <silent> t :call <SID>ToggleSplitType()<cr>
  endif

  nnoremap <buffer> <silent> m :call <SID>MRUListShow()<cr>
  nnoremap <buffer> <silent> p :call <SID>ToggleSplitOutPathName()<cr>
  nnoremap <buffer> <silent> q :call <SID>BackToPreviousBuffer()<cr>
  nnoremap <buffer> <silent> <esc> :call <SID>BackToPreviousBuffer()<cr>
  nnoremap <buffer> <silent> r :call <SID>SortReverse()<cr>
  nnoremap <buffer> <silent> s :call <SID>SortSelect()<cr>

  call <SID>ShowBuffers()

  if !g:bufExplorerResize
    normal! zz
  endif

  setlocal nomodifiable
endfunction

" SetupSyntax {{{1
if has("syntax")
  function! <SID>SetupSyntax()
    syn match bufExplorerHelp     "^\"[ -].*"
    syn match bufExplorerHelpEnd  "^\"=.*$"
    syn match bufExplorerSortBy   "^\" Sorted by .*$"
    syn match bufExplorerOpenIn   "^\" Open in .*$"
    syn match bufExplorerBufNbr   /^\s*\d\+/

    syn match bufExplorerBufFlg transparent contains=@bufExpFlags /^\s*\d\+.\{6}/
    syn cluster bufExpFlags contains=bufExplorerBufNbr,bufExpFlagUnlisted,bufExpFlagCurBuf,bufExpFlagAltBuf,bufExpFlagHidBuf,bufExpFlagActBuf,bufExpFlagModBuf,bufExpFlagLockedBuf,bufExpFlagTagged
    syn match bufExpFlagUnlisted contained /u/
    syn match bufExpFlagCurBuf contained /%/
    syn match bufExpFlagAltBuf contained /#/
    syn match bufExpFlagHidBuf contained /h/
    syn match bufExpFlagActBuf contained /a/
    syn match bufExpFlagModBuf contained /+/
    syn match bufExpFlagLockedBuf contained /[\-=]/
    syn match bufExpFlagTagged contained /\*/
    syn match bufExplorerUnlisted contains=bufExplorerBufFlg /^\s*\d\+u.*$/
    syn match bufExplorerHidBuf contains=bufExplorerBufFlg /^\s*\d\+[u ][%# ]h.*$/
    syn match bufExplorerActBuf contains=bufExplorerBufFlg /^\s*\d\+[u ][%# ]a.*$/
    syn match bufExplorerCurBuf contains=bufExplorerBufFlg /^\s*\d\+[u ]%.*$/
    syn match bufExplorerAltBuf contains=bufExplorerBufFlg /^\s*\d\+[u ]#.*$/
    syn match bufExplorerModBuf contains=bufExplorerBufFlg /^\s*\d\+[u ][%# ][ha ][\-= ]+.*$/
    syn match bufExplorerLockedBuf contains=bufExplorerBufFlg /^\s*\d\+[u ][%# ][ha ][\-=].*$/

    if !exists("g:did_bufexplorer_syntax_inits")
      let g:did_bufexplorer_syntax_inits = 1
      hi def link bufExplorerBufNbr Number
      hi def link bufExplorerHelp Special
      hi def link bufExplorerHelpEnd Special
      hi def link bufExplorerOpenIn String
      hi def link bufExplorerSortBy String

      hi def link bufExpFlagUnlisted Comment
      hi def link bufExpFlagHidBuf Constant
      hi def link bufExpFlagActBuf Identifier
      hi def link bufExpFlagCurBuf Type
      hi def link bufExpFlagAltBuf String
      hi def link bufExpFlagModBuf Exception
      hi def link bufExpFlagLockedBuf Special
      hi def link bufExpFlagTagged Statement
      hi def link bufExplorerUnlisted bufExpFlagUnlisted
      hi def link bufExplorerHidBuf bufExpFlagHidBuf
      hi def link bufExplorerActBuf bufExpFlagActBuf
      hi def link bufExplorerCurBuf bufExpFlagCurBuf
      hi def link bufExplorerAltBuf bufExpFlagAltBuf
      hi def link bufExplorerModBuf bufExpFlagModBuf
      hi def link bufExplorerLockedBuf bufExpFlagLockedBuf
    endif
  endfunction
endif

" AddHeader {{{1
function! <SID>AddHeader()
  1
  if g:bufExplorerDetailedHelp == 1
    let header = "\" Buffer Explorer\n"
    let header = header."\" ----------------\n"
    let header = header."\" <enter> or Mouse-Double-Click : open buffer under cursor\n"
    let header = header."\" d : delete buffer\n"

    if s:bufExplorerSplitWindow == 1
      let header = header."\" o : toggle open mode\n"
    endif

    let header = header."\" p : toggle spliting of file and path name\n"
    let header = header."\" q or <esc> : quit the Buffer Explorer\n"
    let header = header."\" s : select sort field\n"

    if s:bufExplorerSplitWindow == 1
      let header = header."\" t : toggle split type\n"
    endif

    let header = header."\" r : reverse sort\n"
    let header = header."\" ? : toggle this help\n"
  else
    let header = "\" Press ? for Help\n"
  endif

  let header = header."\" Sorted by ".s:sortDirLabel.g:bufExplorerSortBy

  if s:bufExplorerSplitWindow == 1
    if g:bufExplorerOpenMode == 1
      let header = header." | Open in Same window"
    else
      let header = header." | Open in New window"
    endif

    if g:bufExplorerSplitType == ""
      let header = header." | Horizontal split\n"
    else
      let header = header." | Vertical split\n"
    endif
  else
    let header = header."\n"
  endif

  let header = header."\"=\n"

  silent! put! =header
endfunction

" ShowBuffers {{{1
function! <SID>ShowBuffers()
  " Delete all lines in buffer.
  silent! 1,$d _

  call <SID>AddHeader()

  $ d _
  " Prevent odd huge indent when first invoked.
  normal! 0

  let a_save = @a

  redir @a
    silent ls
  redir END

  let filenames = @a
  let @a = a_save
  unlet a_save

  " Remove the *line* and double quotes from the lines.
  let filenames = substitute(filenames, "\\(\\s*\\d\\+[^\"]\\{-}\\)\\%(\"\\)\\([^\"]\\+\\)\\%(\"[^\n]*\\)\\(\n\\|$\\)", "\\1\\2\\3", "g")

  " Hide [.*] Buffer names ([No File], [BufExplorer],...)
  let redone = 0
  while match(filenames, "\\%(^\\|\n\\)\\%(\\s*\\d\\+.\\{6}" . s:hideNames . "\\%(\n\\|$\\)\\|\n\n\\|\n$\\|^\n\\)") != -1 && redone < 100
    let filenames = substitute(filenames, "\\%(\\%(\n\\|^\\)[^\n]*" . s:hideNames . "\\)\\(\n\\|$\\)", "\n", "g")
    let filenames = substitute(filenames, "\\%(\n\n\\+\\|^\n\\+\\|\n\\+$\\)", "", "g")
    let redone = redone + 1
  endwhile

  if filenames != ""
    " Mark the current and alternate buffers.
    if match(filenames, "\\%(^\\|\n\\)\\s*" . s:curBufNbr . "[u ]") != -1
      let filenames = substitute(filenames, "\\(\\%(^\\|\n\\)\\s*\\d\\+\\%( \\|u\\)\\)%", "\\1 ", "")
      let filenames = substitute(filenames, "\\(\\%(^\\|\n\\)\\s*" . s:curBufNbr . "\\%( \\|u\\)\\).", "\\1%", "")
    endif

    if match(filenames, "\\%(^\\|\n\\)\\s*" . s:altBufNbr . "[u ]") != -1
      let filenames = substitute(filenames, "\\(\\%(^\\|\n\\)\\s*\\d\\+\\%( \\|u\\)\\)#", "\\1 ", "")
      let filenames = substitute(filenames, "\\(\\%(^\\|\n\\)\\s*" . s:altBufNbr . "\\%( \\|u\\)\\).", "\\1#", "")
    endif
  endif

  " Get the line number of the last line of the header + 1.
  let _lineNbr = line(".") + 1

  put = filenames

  if g:bufExplorerSplitOutPathName
    exe _lineNbr.",$call <SID>SplitOutPathName()"
  endif

  call <SID>SortListing()
endfunction

" SplitOutPathName {{{1
function! <SID>SplitOutPathName() range
  if a:lastline >= a:firstline
    let maxlen = 0
    let scanline = a:firstline
    let leaderlen = strlen(matchstr(getline("."), "^\\s*\\d\\+.\\{6}"))

    while scanline <= a:lastline
      let _cnr = <SID>ExtractBufferNbr(getline(scanline))
      let linelen = strlen(expand("#"._cnr.":p:t"))

      if linelen + leaderlen > maxlen
        let maxlen = linelen + leaderlen
      endif

      let scanline = scanline + 1
    endwhile

    let scanline = a:firstline

    while scanline <= a:lastline
      let _cfile = getline(scanline)
      let _cnr = <SID>ExtractBufferNbr(_cfile)
      let _cfile = matchstr(_cfile, "^\\s*\\d\\+.\\{6}").expand("#"._cnr.":p:t")
      let pad = maxlen - strlen(_cfile)
      let padloop = 0

      while padloop < pad
        let _cfile = _cfile . " "
        let padloop = padloop + 1
      endwhile

      let _cfile = _cfile." ".expand("#"._cnr.":p:h")
      call setline(scanline, _cfile)

      let scanline = scanline + 1
    endwhile
  endif
endfunction

" SelectBuffer {{{1
function! <SID>SelectBuffer(...)
  " Are we on a line with a file name?
  if getline('.') =~ '^"'
    return
  endif

  let _bufNbr = <SID>ExtractBufferNbr(getline('.'))

  if exists("b:displayMode") && b:displayMode == "winmanager"
    let bufname = expand("#"._bufNbr.":p")
    call WinManagerFileEdit(bufname, a:1)
    return
  end

  if bufexists(_bufNbr) != 0
    if g:bufExplorerOpenMode == 1 && s:bufExplorerSplitWindow == 1
      silent! bd!
    endif

    " Switch to the previously open buffer. This sets the alternate file
    " to the correct one, so that when we switch to the new buffer, the
    " alternate buffer is correct.
    exe "silent! b! " . s:curBufNbr
    exe "b! " . _bufNbr

    call <SID>MRUPush()
  else
    setlocal modifiable
    d _
    setlocal nomodifiable
    echoerr "That buffer no longer exists, please select another"
  endif
endfunction

" DeleteBuffer {{{1
function! <SID>DeleteBuffer()
  if getline('.') =~ '^"'
    return
  endif

  setlocal modifiable

  let _bufNbr = <SID>ExtractBufferNbr(getline('.'))

  " These commands are to temporarily suspend the activity of winmanager.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerSuspendAUs()
  end

  exe "silent! bd "._bufNbr
  d _

  " Reactivate winmanager autocommand activity.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
    call WinManagerResumeAUs()
  end

  setlocal nomodifiable
endfunction

" BackToPreviousBuffer {{{1
function! <SID>BackToPreviousBuffer()
  if s:bufExplorerSplitWindow == 1
    exe "silent! close!"
  endif

  let _switched = 0

  if s:altBufNbr > 0
    exe "silent! b! ".s:altBufNbr
    let _switched = 1
  endif

  if s:curBufNbr > 0
    exe "silent! b! ".s:curBufNbr
    let _switched = 1
  endif

  if _switched == 0
    if s:bufExplorerSplitWindow == 1 && bufwinnr("$") > 1
      new
    else
      enew
    endif
  endif
endfunction

" ToggleHelp {{{1
function! <SID>ToggleHelp()
  let g:bufExplorerDetailedHelp = !g:bufExplorerDetailedHelp

  call <SID>UpdateHeader()

  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerForceReSize("BufExplorer")
  end
endfunction

" ToggleSplitOutPathName {{{1
function! <SID>ToggleSplitOutPathName()
  let g:bufExplorerSplitOutPathName = !g:bufExplorerSplitOutPathName
  setlocal modifiable

  call <SID>SaveCursorPosition()
  call <SID>ShowBuffers()
  call <SID>RestoreCursorPosition()

  setlocal nomodifiable
endfunction

" ToggleOpenMode {{{1
function! <SID>ToggleOpenMode()
  let g:bufExplorerOpenMode = !g:bufExplorerOpenMode
  call <SID>UpdateHeader()
endfunction

" ToggleSplitType {{{1
function! <SID>ToggleSplitType()
  if g:bufExplorerSplitType == ""
    let g:bufExplorerSplitType = "v"
  else
    let g:bufExplorerSplitType = ""
  endif
  call <SID>UpdateHeader()
endfunction

" UpdateHeader {{{1
function! <SID>UpdateHeader()
  setlocal modifiable

  " Save position
  normal! mZ

  " Remove old header
  0
  silent! 1,/^"=/ d _

  call <SID>CleanUpHistory()
  call <SID>AddHeader()

  " Go back where we came from if possible.
  0
  if line("'Z") != 0
    normal! `Z
  endif

  setlocal nomodifiable
endfunction

" ExtractFileName {{{1
function! <SID>ExtractFileName(line)
  return strpart(a:line, strlen(matchstr(a:line, "^\\s*\\d\\+")) + 6)
endfunction

" ExtractBufferNbr {{{1
function! <SID>ExtractBufferNbr(line)
  return matchstr(a:line, "\\d\\+") + 0
endfunction

" FileNameCmp {{{1
function! <SID>FileNameCmp(line1, line2, direction)
  let f1 = <SID>ExtractFileName(a:line1)
  let f2 = <SID>ExtractFileName(a:line2)
  return <SID>StrCmp(toupper(f1), toupper(f2), a:direction)
endfunction

" BufferNumberCmp {{{1
function! <SID>BufferNumberCmp(line1, line2, direction)
  let f1 = <SID>ExtractBufferNbr(a:line1)
  let f2 = <SID>ExtractBufferNbr(a:line2)
  return <SID>StrCmp(f1, f2, a:direction)
endfunction

" StrCmp {{{1
function! <SID>StrCmp(line1, line2, direction)
  if a:line1 < a:line2
    return -a:direction
  elseif a:line1 > a:line2
    return a:direction
  else
    return 0
  endif
endfunction

" MRUCmp {{{1
function! <SID>MRUCmp(line1, line2, direction)
  let n1 = <SID>ExtractBufferNbr(a:line1)
  let n2 = <SID>ExtractBufferNbr(a:line2)

  let i1 = stridx(g:MRUList, ','.n1.',')
  let i2 = stridx(g:MRUList, ','.n2.',')

  " Compare the indices only if they are both in the MRU. Ootherwise, if one
  " of the buffer numbers is not in the mru list, define define the other as
  " the 'smaller'. If both buffers are not in the mru list, then compare their
  " buffer numbers.
  let val = a:direction*(i1 - i2)*(i1 != -1 && i2 != -1)
        \ - a:direction*( (i1 != -1 && i2 == -1) - (i1 == -1 && i2 != -1) )
        \ + a:direction*(i1 == -1 && i2 == -1)*(n1 - n2)
  return val
endfunction

" SortR *called recursively* {{{1
function! <SID>SortR(start, end, cmp, direction)
  " Bottom of the recursion if start reaches end
  if a:start >= a:end
    return
  endif

  let partition = a:start - 1
  let middle = partition
  let partStr = getline((a:start + a:end) / 2)

  let i = a:start

  while i <= a:end
    let str = getline(i)

    exe "let result = ".a:cmp."(str, partStr, ".a:direction.")"

    if result <= 0
      " Need to put it before the partition.  Swap lines i and partition.
      let partition = partition + 1

      if result == 0
        let middle = partition
      endif

      if i != partition
        let str2 = getline(partition)
        call setline(i, str2)
        call setline(partition, str)
      endif
    endif

    let i = i + 1
  endwhile

  " Now we have a pointer to the 'middle' element, as far as partitioning
  " goes, which could be anywhere before the partition.  Make sure it is at
  " the end of the partition.
  if middle != partition
    let str = getline(middle)
    let str2 = getline(partition)
    call setline(middle, str2)
    call setline(partition, str)
  endif

  call <SID>SortR(a:start, partition - 1, a:cmp, a:direction)
  call <SID>SortR(partition + 1, a:end, a:cmp, a:direction)
endfunction

" Sort {{{1
function! <SID>Sort(cmp, direction) range
  call <SID>SortR(a:firstline, a:lastline, a:cmp, a:direction)
endfunction

" SortReverse {{{1
function! <SID>SortReverse()
  if g:bufExplorerSortDirection == -1
    let g:bufExplorerSortDirection = 1
    let s:sortDirLabel = ""
  else
    let g:bufExplorerSortDirection = -1
    let s:sortDirLabel = "reverse "
  endif

  call <SID>SaveCursorPosition()
  call <SID>SortListing()
  call <SID>RestoreCursorPosition()
endfunction

" SortSelect {{{1
function! <SID>SortSelect()
  if !exists("g:bufExplorerSortBy")
    let g:bufExplorerSortBy = "number"
  elseif g:bufExplorerSortBy == "number"
    let g:bufExplorerSortBy = "name"
  elseif g:bufExplorerSortBy == "name"
    let g:bufExplorerSortBy = "mru"
  elseif g:bufExplorerSortBy == "mru"
    let g:bufExplorerSortBy = "number"
  endif

  call <SID>SaveCursorPosition()
  call <SID>SortListing()
  call <SID>RestoreCursorPosition()
endfunction

" SortListing {{{1
function! <SID>SortListing()
  let startline = getline(".")

  setlocal modifiable

  0
  if g:bufExplorerSortBy == "number"
    let cmpFunction = "<SID>BufferNumberCmp"
  elseif g:bufExplorerSortBy == "name"
    let cmpFunction = "<SID>FileNameCmp"
  else
    let cmpFunction = "<SID>MRUCmp"
  endif

  /^"=/+1,$call <SID>Sort(cmpFunction, g:bufExplorerSortDirection)

  call <SID>CleanUpHistory()
  call <SID>UpdateHeader()

  setlocal nomodified
  setlocal nomodifiable
endfunction

" SaveCursorPosition {{{1
function! <SID>SaveCursorPosition()
  let s:curLine = winline()
  let s:curColumn = wincol()
endfunction

" RestoreCursorPosition {{{1
function! <SID>RestoreCursorPosition()
  exe s:curLine
  exe "normal! ".s:curColumn."|"
endfunction

" MRUPush {{{1
function! <SID>MRUPush()
  if !buflisted(bufnr("%"))
    return
  end

  let _bufNbr = bufnr("%")
  let _list = substitute(g:MRUList, ','._bufNbr.',', ',', '')
  let g:MRUList = ","._bufNbr._list
endfunction

" MRUPop {{{1
function! <SID>MRUPop()
  let _bufNbr = expand("<abuf>")
  let g:MRUList = substitute(g:MRUList, ''._bufNbr.',', '', '')
endfunction

" MRUGet {{{1
function! <SID>MRUGet(slot)
  let _bufNbr = (matchstr(g:MRUList, '\(\([^,]*,\)\{'.a:slot.'}\)\@<=[^,]*'))

  if _bufNbr == ""
    return -1
  end

  return _bufNbr
endfunction

" MRUListShow {{{1
function! <SID>MRUListShow()
  echomsg "MRUList=[".g:MRUList."]"
endfunction

" DoAnyMoreBuffersExist {{{1
function! <SID>DoAnyMoreBuffersExist()
  let nBuffers = bufnr("$")
  let i = 0
  let x = 0

  while i <= nBuffers
    let i = i + 1

    if getbufvar(i, "&buflisted") == 1
      let x = x + 1

      if x > 1
        return 1
      endif
    endif
  endwhile

  return 0
endfunction

" CleanUpHistory {{{1
function! <SID>CleanUpHistory()
  call histdel("/", -1)
  let @/ = histget("/", -1)
endfunction

" vim:ft=vim foldmethod=marker

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
" Last Changed: Monday, 10 March 2006
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
let g:loaded_bufexplorer = "7.0.11"

" Setup the global MRUList.
let g:MRUList = ","

" Setup the autocommands that handle the MRUList and other stuff.
augroup bufexplorer
  autocmd!
  autocmd BufEnter * silent call <SID>MRUPush()
  autocmd BufDelete * silent call <SID>MRUPop()
  autocmd BufEnter \[BufExplorer\] silent call <SID>Initialize()
  autocmd BufLeave \[BufExplorer\] silent call <SID>Cleanup()
  autocmd VimEnter * silent call <SID>BuildInitialMRU()
augroup End

" Create commands
if !exists(":BufExplorer")
  command BufExplorer keepjumps :call <SID>StartBufExplorer(0)
endif

if !exists(":SBufExplorer")
  command SBufExplorer keepjumps :call <SID>StartBufExplorer(1)
endif

if !exists(":VSBufExplorer")
  command VSBufExplorer keepjumps :call <SID>StartBufExplorer(2)
endif

" Public Interfaces
map <silent> <unique> <Leader>be :BufExplorer<CR>
map <silent> <unique> <Leader>bs :SBufExplorer<CR>
map <silent> <unique> <Leader>bv :VSBufExplorer<CR>

" Show default help? If you set this to 0, you're on your own remembering that
" '?' brings up the help and what the sort order is.
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
" Can be either 'number', 'name', 'mru', or 'fullpath'.
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
  let s:sortDirLabel = ""
else
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

" Used to make sure that only one BufExplorer is open at a time.
if !exists("g:bufExplorerRunning")
  let g:bufExplorerRunning = 0
endif

" Characters that must be escaped for a regular expression.
let s:escregexp = "/*^$.~\[]"
let s:hideNames = "\\[[^\\]]*\\]"

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
  setlocal nofoldenable

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
    echohl WarningMsg | echo "Sorry, there are no more buffers to explore"
    echohl none
    return
  endif

  let _splitbelow = &splitbelow

  if a:split == 2
    let g:bufExplorerSplitType = "v"
  endif

  " Get the current and alternate buffer numbers for later.
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

      call <SID>Resize()
    else
      if has("win32")
        exe "silent! e [BufExplorer]"
      else
        exe "silent! e \[BufExplorer\]"
      endif

      let s:bufExplorerSplitWindow = 0
    endif
  endif

  call <SID>DisplayBufferList()

  let &splitbelow = _splitbelow
endfunction

" DisplayBufferList {{{1
function! <SID>DisplayBufferList()
  setlocal bufhidden=delete
  setlocal buftype=nofile
  setlocal modifiable
  setlocal noswapfile
  setlocal nowrap

  if has("syntax")
    call <SID>SetupSyntax()
  endif

  call <SID>MapKeys()
  call <SID>BuildBufferList()

  if !g:bufExplorerResize
    normal! zz
  endif

  setlocal nomodifiable
endfunction

" MapKeys {{{1
function! <SID>MapKeys()
  if exists("b:displayMode") && b:displayMode == "winmanager"
    nnoremap <buffer> <silent> <tab> :call <SID>SelectBuffer(1)<cr>
  endif

  nnoremap <buffer> <silent> ? :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <silent> <2-leftmouse> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> <cr> :call <SID>SelectBuffer(0)<cr>
  nnoremap <buffer> <silent> S :call <SID>SelectBuffer(1)<cr>
  nnoremap <buffer> <silent> d :call <SID>DeleteBuffer()<cr>

  if s:bufExplorerSplitWindow == 1
    nnoremap <buffer> <silent> o :call <SID>ToggleOpenMode()<cr>
    nnoremap <buffer> <silent> t :call <SID>ToggleSplitType()<cr>
  endif

  nnoremap <buffer> <silent> m :call <SID>MRUListShow()<cr>
  nnoremap <buffer> <silent> p :call <SID>ToggleSplitOutPathName()<cr>
  nnoremap <buffer> <silent> q :call <SID>BackToPreviousBuffer()<cr>
  nnoremap <buffer> <silent> r :call <SID>SortReverse()<cr>
  nnoremap <buffer> <silent> s :call <SID>SortSelect()<cr>
endfunction

" SetupSyntax {{{1
if has("syntax")
  function! <SID>SetupSyntax()
    syn match bufExplorerHelp     "^\"[ -].*"
    syn match bufExplorerHelpEnd  "^\"=.*$"
    syn match bufExplorerSortBy   "^\" Sorted by .*$"
    syn match bufExplorerOpenIn   "^\" Open in .*$"
    syn match bufExplorerBufNbr   /^\s*\d\+/

    syn cluster bufExpFlags contains=bufExplorerBufNbr,bufExpFlagCurBuf,bufExpFlagAltBuf,bufExpFlagActBuf,bufExpFlagModBuf,bufExpFlagLockedBuf,bufExpFlagTagged
    syn match bufExpFlagCurBuf contained /%/
    syn match bufExpFlagAltBuf contained /#/
    syn match bufExpFlagHidBuf contained /h/
    syn match bufExpFlagActBuf contained /a/
    syn match bufExpFlagModBuf contained /+/
    syn match bufExpFlagLockedBuf contained /[\-=]/
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
  if g:bufExplorerDefaultHelp == 0 && g:bufExplorerDetailedHelp == 0
    return
  endif

  1

  if g:bufExplorerDetailedHelp == 1
    let header = "\" Buffer Explorer (".g:loaded_bufexplorer.")\n"
    let header = header."\" --------------------------\n"
    let header = header."\" <enter> or Mouse-Double-Click : open buffer under cursor\n"
    let header = header."\" S : open buffer under cursor in new split window\n"
    let header = header."\" d : delete buffer\n"

    if s:bufExplorerSplitWindow == 1
      let header = header."\" o : toggle open mode\n"
    endif

    let header = header."\" p : toggle spliting of file and path name\n"
    let header = header."\" q : quit the Buffer Explorer\n"
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

  silent! put! = header
endfunction

" BuildBufferList {{{1
function! <SID>BuildBufferList()
  " Delete all lines in buffer.
  silent! 1,$d _

  call <SID>AddHeader()

  $d _

  " Prevent odd huge indent when first invoked.
  normal! 0

  let nBuffers = bufnr('$')     " Get the number of the last buffer.
  let i = 0
  let fileNames = ''
  let maxBufferNameWidth = 0
  let maxBufferNbrWidth = 0

  " Preprocess the list of buffers.
  " Find the max buffer name and buffer number.
  while (i <= nBuffers)
    let i = i + 1

    if (getbufvar(i, '&buflisted') == 1)
      let bufName = bufname(i)

      if (bufName != '[BufExplorer]')
        let length = strlen(i)

        if (maxBufferNbrWidth < length)
          let maxBufferNbrWidth = length
        endif

        let shortBufName = fnamemodify(bufName, ":t")
        let length = strlen(shortBufName)

        if (maxBufferNameWidth < length)
          let maxBufferNameWidth = length
        endif
      endif
    endif
  endwhile

  " Loop through every buffer less than the total number of buffers.
  let i = 0
  while (i <= nBuffers)
    let i = i + 1

    " Make sure the buffer in question is listed.
    if (getbufvar(i, '&buflisted') == 1)
      " Get the name of the buffer.
      let bufName = bufname(i)

      " Only show modifiable buffers (The idea is that we don't 
      " want to show Explorers)
      if (bufName != '[BufExplorer]')
        " Get filename & Remove []'s & ()'s
        let shortBufName = fnamemodify(bufName, ":t")
        let pathName = fnamemodify(bufName, ":p:h")

        if v:version >= 700
          let _ftype = getftype(bufName)

          if _ftype == "dir" && g:bufExplorerShowDirectories == 1
            let shortBufName = "<DIRECTORY>"
          end
        end

        " If the buffer is modified then mark it.
        if (getbufvar(i, '&modified') == 1)
          let modified = "+"
        else
          let modified = " "
        endif

        " Create the pad for the buffer number.
        let diffWidth = maxBufferNbrWidth - strlen(i)
        let nbrPad = "  "

        while (diffWidth)
          let nbrPad = nbrPad." "
          let diffWidth = diffWidth - 1
        endwhile

        " Format the final line and add it to the buffer.
        if g:bufExplorerSplitOutPathName
          " Create the pad for the buffer name if needed.
          let diffWidth = maxBufferNameWidth - strlen(shortBufName)
          let namePad = " "

          while (diffWidth)
            let namePad = namePad." "
            let diffWidth = diffWidth - 1
          endwhile

          let fileNames = fileNames.nbrPad.i."    ".modified." ".shortBufName.namePad.pathName."\n"
        else
          let separator = ""

          if pathName !~ '[/\\]$'
            " Check if we are using shellslash or not?
            if (&ssl == 0) && (has("msdos") || has("os2") || has("win16") || has("win32"))
              let separator = "\\"
            else
              let separator = "/"
            end
          end

          let fileNames = fileNames.nbrPad.i."    ".modified." ".pathName.separator.shortBufName."\n"
        end
      endif
    endif
  endwhile

  if fileNames != ""
    " Mark the current and alternate buffers.
    if match(fileNames, "\\%(^\\|\n\\)\\s*" . s:curBufNbr . "[u ]") != -1
      let fileNames = substitute(fileNames, "\\(\\%(^\\|\n\\)\\s*\\d\\+\\%( \\|u\\)\\)%", "\\1 ", "")
      let fileNames = substitute(fileNames, "\\(\\%(^\\|\n\\)\\s*" . s:curBufNbr . "\\%( \\|u\\)\\).", "\\1%", "")
    endif

    if match(fileNames, "\\%(^\\|\n\\)\\s*" . s:altBufNbr . "[u ]") != -1
      let fileNames = substitute(fileNames, "\\(\\%(^\\|\n\\)\\s*\\d\\+\\%( \\|u\\)\\)#", "\\1 ", "")
      let fileNames = substitute(fileNames, "\\(\\%(^\\|\n\\)\\s*" . s:altBufNbr . "\\%( \\|u\\)\\).", "\\1#", "")
    endif
  endif

  " Get the line number of the last line of the header + 1 if there is
  " actually a header.
  if g:bufExplorerDefaultHelp == 0
    let _lineNbr = 0
  else
    let _lineNbr = line(".") + 1
  endif

  silent! put = fileNames

  call <SID>SortListing()
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
    " alternate buffer is correct. But if switching to current buffer again,
    " restore the alternate one.
    if s:curBufNbr == _bufNbr
      exe "silent! b! " . s:altBufNbr
    else
      exe "silent! b! " . s:curBufNbr
    endif

    " If we are doing a 'normal' SelectBuffer, 0 was passed in. If '1'
    " is passed in, the user has choosen to do a 'Split Select'.
    if a:1 != 1
      exe "b! " . _bufNbr
    else
      exe "silent! ".g:bufExplorerSplitType."sb "._bufNbr
    endif

    call <SID>MRUPush()
  else
    setlocal modifiable
    d _
    setlocal nomodifiable
    echoerr "Sorry, that buffer no longer exists, please select another"
  endif
endfunction

" DeleteBuffer {{{1
function! <SID>DeleteBuffer()
  if getline('.') =~ '^"'
    return
  endif

  let _bufNbr = <SID>ExtractBufferNbr(getline('.'))

  " If there are 2 or less ',' in the MRUList, then this is the last buffer,
  " do not allow this buffer to be deleted.
  if strlen(substitute(g:MRUList, "[^,]", "","g")) <= 2
    echohl ErrorMsg | echo "Sorry, you are not allowed to delete the last buffer"
    return
  endif

  setlocal modifiable

  " These commands are to temporarily suspend the activity of winmanager.
  if exists("b:displayMode") && b:displayMode == "winmanager"
    call WinManagerSuspendAUs()
  end

  if getbufvar(_bufNbr, '&modified') == 1
    echohl ErrorMsg | echo "Sorry, no write since last change for buffer "._bufNbr.", unable to delete"
  else
    exe "silent! bw "._bufNbr
    d _
  endif

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
    let _switched = 1

    try
      exe "silent b! ".s:curBufNbr
    catch /^Vim(\a\+):E86:/
      echohl WarningMsg | echo "Current buffer was deleted, please select a buffer to switch to"
      echohl none
    endtry
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
  call <SID>BuildBufferList()
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

  " Jump back where we came from if possible.
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

  " Compare the indices only if they are both in the MRU. Otherwise, if
  " one of the buffer numbers is not in the mru list, define the other as the
  " 'smaller'. If both buffers are not in the mru list, then compare their
  " buffer numbers.
  let val = a:direction*(i1 - i2)*(i1 != -1 && i2 != -1)
        \ - a:direction*( (i1 != -1 && i2 == -1) - (i1 == -1 && i2 != -1) )
        \ + a:direction*(i1 == -1 && i2 == -1)*(n1 - n2)
  return val
endfunction

" FullPathCmp {{{1
function! <SID>FullPathCmp(line1, line2, direction)
  let d1 = expand("#".<SID>ExtractBufferNbr(a:line1).":p:h")
  let d2 = expand("#".<SID>ExtractBufferNbr(a:line2).":p:h")
  if d1 == d2
    return <SID>FileNameCmp(a:line1, a:line2, a:direction)
  else
    return <SID>StrCmp(d1, d2, a:direction)
  endif
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
    let g:bufExplorerSortBy = "fullpath"
  elseif g:bufExplorerSortBy == "fullpath"
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
  elseif g:bufExplorerSortBy == "mru"
    let cmpFunction = "<SID>MRUCmp"
  else
    let cmpFunction = "<SID>FullPathCmp"
  endif

  if g:bufExplorerDefaultHelp == 0 && g:bufExplorerDetailedHelp == 0
    1,$call <SID>Sort(cmpFunction, g:bufExplorerSortDirection)
  else
    /^"=/+1,$call <SID>Sort(cmpFunction, g:bufExplorerSortDirection)
  endif

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

" MRUPushReversed {{{1
function! <SID>MRUPushReversed(bufNbr)
  " Don't add the BufExplorer window to the list.
  if bufname(a:bufNbr) == "[BufExplorer]"
    return
  end

  let _list = substitute(g:MRUList, ','.a:bufNbr.',', ',', '')
  let g:MRUList = _list.a:bufNbr.","
endfunction

" MRUPush {{{1
function! <SID>MRUPush()
  if !buflisted(bufnr("%"))
    return
  end

  " Don't add the BufExplorer window to the list.
  if bufname("%") == "[BufExplorer]"
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

function! <SID>BuildInitialMRU()
  let nBuffers = bufnr('$')
  let i = 0

  " Preprocess the list of buffers.
  while (i <= nBuffers)
    let i = i + 1

    if (getbufvar(i, '&buflisted') == 1)
      call <SID>MRUPushReversed(i)
    end
  endwhile
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

" Resize {{{1
function! <SID>Resize()
  if g:bufExplorerSplitType == "v"
    if g:bufExplorerSplitVertSize > 0
      exe g:bufExplorerSplitVertSize." wincmd |"
    end
  else
    if g:bufExplorerSplitHorzSize > 0
      exe g:bufExplorerSplitHorzSize." wincmd _"
    end
  endif
endfunction

" vim:ft=vim foldmethod=marker

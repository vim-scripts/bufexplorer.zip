"=============================================================================
"    Copyright: Copyright (C) 2001 Jeff Lanzarotta
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               bufexplorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damamges
"               resulting from the use of this software.
" Name Of File: bufexplorer.vim
"  Description: Buffer Explorer Vim Plugin
"   Maintainer: Jeff Lanzarotta (frizbeefanatic@yahoo.com)
"  Last Change: Friday, August 24, 2001
"      Version: 6.0.6
"        Usage: Normally, this file should reside in the plugins
"               directory and be automatically sourced. If not, you must
"               manually source this file using ':source bufexplorer.vim'.
"
"               Run ':BufExplorer' to launch the explorer and runs the
"               user-specified command in the current window, or
"               ':SBufExplorer' to launch the explorer and run the
"               user-specified command in the the newly split window.
"                 
"               You may use the default keymappings of
"                   
"                 <Leader>be  - Opens BufExplorer
"                 <Leader>bs  - Opens split windows BufExplorer
"
"               or you may want to add something like the following
"               three key mappings to your _vimrc/.vimrc file.
"                   
"                 map <Leader>b :BufExplorer<cr>
"                 map <Leader>B :SBufExplorer<cr>
"                 map <c-leftmouse> :BufExplorer<cr>
"
"               If the current buffer is modified, the current window is
"               always split.
"                  
"               To control where the new split windows goes relative to
"               the current window, use the variable:"
"               
"                 let g:bufExplSplitBelow=0  " Put new window above
"                                            " current.
"                 let g:bufExplSplitBelow=1  " Put new window below
"                                            " current.
"                                            
"               The default for this is to split 'above'.
"
"      History: 6.0.6 - Copyright notice added. Fixed problem with the
"                 SortListing() function failing when there was only one
"                 buffer to display.
"               6.0.5 - Fixed problems reported by David Pascoe, in that
"                 you where unable to hit 'd' on a buffer that belonged to a
"                 files that nolonger existed and that the 'yank' buffer was
"                 being overridden by the help text when the bufexplorer was
"                 opened.
"               6.0.4 - Thanks to Charles Campbell for making this plugin
"                 more plugin *compliant*, adding default keymappings
"                 of <Leader>be and <Leader>bs as well as fixing the
"                 'w:sortDirLabel not being defined' bug.
"               6.0.3 - Added sorting capabilities. Sort taken from
"                 explorer.vim.
"               6.0.2 - Can't remember.
"=============================================================================

" Has this already been loaded?
if exists("loaded_bufexplorer")
  finish
endif

let loaded_bufexplorer = 1

if !hasmapto('<Plug>StartBufExplorer')
  map <unique> <Leader>be <Plug>StartBufExplorer
endif

if !hasmapto('<Plug>SplitBufExplorer')
  map <unique> <Leader>bs <Plug>SplitBufExplorer
endif

map <unique> <script> <Plug>StartBufExplorer :call <SID>StartBufExplorer(0)<CR>
map <unique> <script> <Plug>SplitBufExplorer :call <SID>StartBufExplorer(1)<CR>

" 
" Create commands.
" 
if !exists(':BufExplorer')
  command BufExplorer :call <SID>StartBufExplorer(0)
endif

if !exists(':SBufExplorer')
  command SBufExplorer :call <SID>StartBufExplorer(1)
endif

" 
" Show detailed help?
" 
if !exists("g:bufExplorerDetailedHelp")
  let g:bufExplorerDetailedHelp = 0
endif

" Field to sort by
if !exists("g:bufExplorerSortBy")
  let g:bufExplorerSortBy = 'number'
endif

" When opening a new windows, split the new windows below or above the
" current window?  1 = below, 0 = above.
if !exists("g:bufExplSplitBelow")
  let g:bufExplSplitBelow = &splitbelow
endif

if !exists("g:bufExplorerSortDirection")
  let g:bufExplorerSortDirection = 1
  let s:sortDirLabel = ""
else
  let s:sortDirLabel = "reverse"
endif

" Characters that must be escaped for a regular expression.
let s:escregexp = '/*^$.~\'

" 
" StartBufExplorer
" 
function! <SID>StartBufExplorer(split)
  " Save the user's settings.
  let saveSplitBelow = &splitbelow

  " Save current and alternate buffer numbers for later.
  let s:currentBufferNumber = bufnr("%")
  let s:alternateBufferNumber = bufnr("#")

  let s:maxFileLen = 0
 
  " Set to our new values.
  let &splitbelow = g:bufExplSplitBelow

  if a:split || (&modified && &hidden == 0)
    sp [BufExplorer]
    let s:bufExplorerSplitWindow = 1
  else
    e [BufExplorer]
    let s:bufExplorerSplitWindow = 0
  endif

  call <SID>DisplayBuffers()
  
  " Restore the user's settings.
  let &splitbelow = saveSplitBelow

  unlet saveSplitBelow
endfunction

" 
" DisplayBuffers.
" 
function! <SID>DisplayBuffers()
  " Turn off the swapfile, set the buffer type so that it won't get written,
  " and so that it will get deleted when it gets hidden.
  setlocal modifiable
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nowrap
  
  " Prevent a report of our actions from showing up.
  let oldRep = &report
  let save_sc = &showcmd
  let &report = 10000
  set noshowcmd 
 
  if has("syntax")
    syn match bufExplorerHelp    "^\"[ -].*"
    syn match bufExplorerHelpEnd "^\"=.*$"
    syn match bufExplorerSortBy  "^\" Sorted by .*$"

    if !exists("g:did_bufexplorer_syntax_inits")
      let g:did_bufexplorer_syntax_inits = 1
      hi def link bufExplorerHelp Special
      hi def link bufExplorerHelpEnd Special
      hi def link bufExplorerSortBy String
    endif
  endif
  
  if exists("s:longHelp")
    let w:longHelp = s:longHelp
  else
    let w:longHelp = g:bufExplorerDetailedHelp
  endif

  nnoremap <buffer> <cr> :call <SID>SelectBuffer()<cr>
  nnoremap <buffer> d :call <SID>DeleteBuffer()<cr>
  nnoremap <buffer> q :call <SID>BackToPreviousBuffer()<cr>
  nnoremap <buffer> s :call <SID>SortSelect()<cr>
  nnoremap <buffer> r :call <SID>SortReverse()<cr>
  nnoremap <buffer> ? :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <2-leftmouse> :call <SID>DoubleClick()<cr>
 
  " Delete all lines in buffer.
  1,$d _

  call <SID>AddHeader()
  $ d _
  call <SID>ShowBuffers()
 
  normal! zz

  let &report = oldRep
  let &showcmd = save_sc

  unlet oldRep save_sc
  
  " Prevent the buffer from being modified.
  setlocal nomodifiable
endfunction

" 
" AddHeader.
" 
function! <SID>AddHeader()
  1
  if w:longHelp == 1
    let header = "\" Buffer Explorer\n"
    let header = header."\" ----------------\n"
    let header = header."\" <enter> or Mouse-Double-Click : open buffer under cursor\n"
    let header = header."\" d : delete buffer.\n" 
    let header = header."\" q : quit the Buffer Explorer\n"
    let header = header."\" s : select sort field    r : reverse sort\n"
    let header = header."\" ? : toggle this help\n"
  else
    let header = "\" Press ? for Help\n"
  endif
  
  let header = header."\" Sorted by ".s:sortDirLabel.g:bufExplorerSortBy."\n"
  let header = header."\"=\n"
  
  put! =header

  unlet header
endfunction

" 
" ShowBuffers.
" 
function! <SID>ShowBuffers()
  let oldRep = &report
  let save_sc = &showcmd
  let &report = 10000
  set noshowcmd 
  
  let _NBuffers = bufnr("$")     " Get the number of the last buffer.
  let _i = 0                     " Set the buffer index to zero.

  let fileNames = ""

  " Loop through every buffer less than the total number of buffers.
  while(_i <= _NBuffers)
    let _i = _i + 1
   
    " Make sure the buffer in question is listed.
    if(getbufvar(_i, '&buflisted') == 1)
      " Get the name of the buffer.
      let _BufName = bufname(_i)
     
      " Check to see if the buffer is a blank or not. If the buffer does have
      " a name, process it.
      if(strlen(_BufName))
        if(matchstr(_BufName, "BufExplorer\]") == "")
          let len = strlen(_BufName)
          
          if len > s:maxFileLen
            let s:maxFileLen = len
          endif

          if(bufnr(_BufName) == s:currentBufferNumber)
            let fileNames = fileNames.'%'
          else
            if(bufnr(_BufName) == s:alternateBufferNumber)
              let fileNames = fileNames.'#'
            else
              let fileNames = fileNames.' '
            endif
          endif

          if(getbufvar(_i, '&hidden') == 1)
            let fileNames = fileNames.'h'
          else
            let fileNames = fileNames.' '
          endif
          
          if(getbufvar(_i, '&readonly') == 1)
            let fileNames = fileNames.'='
          else
            if(getbufvar(_i, '&modified') == 1)
              let fileNames = fileNames.'+'
            else
              if(getbufvar(_i, '&modifiable') == 0)
                let fileNames = fileNames.'-'
              else
                let fileNames = fileNames.' '
              endif
            endif
          endif

          let fileNames = fileNames.' '
          let fileNames = fileNames._BufName."\n"
        endif
      endif
    endif
  endwhile

  put =fileNames

  call <SID>SortListing("")
  
  let &report = oldRep
  let &showcmd = save_sc
  
  unlet! fileNames _NBuffers _i oldRep save_sc _BufName
endfunction

" 
" SelectBuffer.
" 
function! <SID>SelectBuffer()
  let save_sc = &showcmd
  set noshowcmd 
  
  let _cfile = getline('.')

  " Are we on a line with a file name?
  if _cfile =~'^"'
    unlet _cfile
    return
  endif
 
  " Skip over the readonly, modified indicators if there is any.
  let _cfile = <SID>ExtractFileName(_cfile)

  if(strlen(_cfile))
    " Get the buffer number associated with this filename.
    let _bufnr = bufnr(_cfile)

    if(_bufnr != -1)             " If the buffer exists.
      " Switch to the previously open buffer. This sets the alternate file
      " to the correct one, so that when we switch to the new buffer, the
      " alternate buffer is correct.
      exec("b! ".s:currentBufferNumber)
      " Open the new buffer.
      exec("b! "._bufnr)
    endif
  else
    if(@# != "" && (getbufvar('#', '&buflisted') == 1))
      exec("e #")
    endif
  endif

  let &showcmd = save_sc
  
  unlet! _cfile _bufnr save_sc
endfunction

" 
" Delete selected buffer from list.
" 
function! <SID>DeleteBuffer()
  let oldRep = &report
  let &report = 10000
  let save_sc = &showcmd
  set noshowcmd 
  
  setlocal modifiable
  
  let _cfile = getline('.')
  
  " Skip over the readonly, modified indicators if there is any.
  let _cfile = strpart(_cfile,4,strlen(_cfile))
  
  " Delete the buffer selected.
  exec("bd ".(bufnr(_cfile)))
  " Delete the buffer's name from the list.
  d _

  setlocal nomodifiable

  let &report = oldRep
  let &showcmd = save_sc

  unlet _cfile oldRep save_sc
endfunction

" 
" Back To Previous Buffer.
"
function! <SID>BackToPreviousBuffer()
  let save_sc = &showcmd
  set noshowcmd 

  if(s:bufExplorerSplitWindow == 1)
    exec("silent! close!")
  endif

  let switched = 0
  
  if(s:alternateBufferNumber != -1)
    if filereadable(bufname(s:alternateBufferNumber))
      exec("b! ".s:alternateBufferNumber)
      let switched = 1
    endif
  endif

  if(s:currentBufferNumber != -1)
    if filereadable(bufname(s:currentBufferNumber))
      exec("b! ".s:currentBufferNumber)
      let switched = 1
    endif
  endif

  if switched == 0
    if s:bufExplorerSplitWindow == 1 && bufwinnr("$") > 1
      new
    else
      enew
    endif
  endif
  
  let &showcmd = save_sc

  unlet save_sc
endfunction

" 
" Toggle between short and long help
" 
function! <SID>ToggleHelp()
  if exists("w:longHelp") && w:longHelp==0
    let w:longHelp=1
    let s:longHelp=1
  else
    let w:longHelp=0
    let s:longHelp=0
  endif
  
  " Allow modification
  setlocal modifiable
  
  call <SID>UpdateHeader()
  
  " Disallow modification
  setlocal nomodifiable
endfunction

" 
" Update the header
" 
function! <SID>UpdateHeader()
  let oldRep = &report
  let save_sc = &showcmd
  let &report = 10000
  set noshowcmd 
  
  " Save position
  normal! mt
  
  " Remove old header
  0
  1,/^"=/ d _
  
  " Add new header
  call <SID>AddHeader()
  
  " Go back where we came from if possible.
  0
  if line("'t") != 0
    normal! `t
  endif

  let &report = oldRep
  let &showcmd = save_sc

  unlet oldRep save_sc
endfunction

"
" ExtractFileName
"
function! <SID>ExtractFileName(line)
  return strpart(a:line, 4, strlen(a:line))
endfunction

"
" FileNameCmp
"
function! <SID>FileNameCmp(line1, line2, direction)
  let f1 = <SID>ExtractFileName(a:line1)
  let f2 = <SID>ExtractFileName(a:line2)
  
  return <SID>StrCmp(f1, f2, a:direction)
endfunction

"
" BufferNumberCmp
"
function! <SID>BufferNumberCmp(line1, line2, direction)
  let f1 = bufnr(<SID>ExtractFileName(a:line1))
  let f2 = bufnr(<SID>ExtractFileName(a:line2))

  return <SID>StrCmp(f1, f2, a:direction)
endfunction

"
" StrCmp - General string comparison function
"
function! <SID>StrCmp(line1, line2, direction)
  if a:line1 < a:line2
    return -a:direction
  elseif a:line1 > a:line2
    return a:direction
  else
    return 0
  endif
endfunction

"
" SortR() is called recursively.
"
function! <SID>SortR(start, end, cmp, direction)
  " Bottom of the recursion if start reaches end
  if a:start >= a:end
    return
  endif
  
  let partition = a:start - 1
  let middle = partition
  let partStr = getline((a:start + a:end) / 2)

  let i = a:start
  
  while (i <= a:end)
    let str = getline(i)

    exec "let result = " . a:cmp . "(str, partStr, " . a:direction . ")"

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

  " Now we have a pointer to the "middle" element, as far as partitioning
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

"
" Sort
"
function! <SID>Sort(cmp, direction) range
  call <SID>SortR(a:firstline, a:lastline, a:cmp, a:direction)
endfunction

"
" SortReverse
"
function! <SID>SortReverse()
  if g:bufExplorerSortDirection == -1
    let g:bufExplorerSortDirection = 1
    let s:sortDirLabel = ""
  else
    let g:bufExplorerSortDirection = -1
    let s:sortDirLabel = "reverse "
  endif
  
  call <SID>SortListing("")
endfunction

"
" SortSelect
"
function! <SID>SortSelect()
  " Select the next sort option
  if !exists("g:bufExplorerSortBy")
    let g:bufExplorerSortBy = "number"
  elseif g:bufExplorerSortBy == "number"
    let g:bufExplorerSortBy = "name"
  elseif g:bufExplorerSortBy == "name"
    let g:bufExplorerSortBy = "number"
  endif
  
  call <SID>SortListing("")
endfunction

"
" SortListing
"
function! <SID>SortListing(msg)
  " Save the line we start on so we can go back there when done sorting.
  let startline = getline(".")
  let col = col(".")
  let lin = line(".")

  " Allow modification
  setlocal modifiable

  " Do the sort.
  0
  if g:bufExplorerSortBy == "number"
    let cmpFunction = "<SID>BufferNumberCmp"
  else
    let cmpFunction = "<SID>FileNameCmp"
  endif

  /^"=/+1,$call <SID>Sort(cmpFunction, g:bufExplorerSortDirection)

  " Replace the header with updated information.
  call <SID>UpdateHeader()
  
  " Return to the position we started at.
  0
  if search('\m^'.escape(startline, s:escregexp), 'W') <= 0
    execute lin
  endif
  
  execute "normal!" col . "|"

  " Disallow modification.
  setlocal nomodified
  setlocal nomodifiable
  
  unlet startline col lin cmpFunction
endfunction

"
" DoubleClick - Double click with the mouse.
"
function s:DoubleClick()
  call <SID>SelectBuffer()
endfun

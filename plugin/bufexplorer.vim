"=============================================================================
"     Name Of File: bufexplorer.vim
"      Description: Buffer Explorer Plugin
"       Maintainer: Jeff Lanzarotta (frizbeefanatic@yahoo.com)
"      Last Change: Thursday, June 28, 2001
"          Version: 6.0.2
"            Usage: Normally, this file should reside in the plugins
"                   directory and be automatically sourced. If not, you must
"                   manually source this file using ':source bufexplorer.vim'.
"
"                   Run ':BufExplorer' to launch the explorer and runs the
"                   user-specified command in the current window, or
"                   ':SBufExplorer' to launch the explorer and run the
"                   user-specified command in the the newly split window.
"                  
"                   You may want to add the following three key mappings to
"                   your _vimrc/.vimrc file.
"                   
"                     map <Leader>b :BufExplorer<cr>
"                     map <Leader>B :SBufExplorer<cr>
"                     map <c-leftmouse> :BufExplorer<cr>
"
"                   If the current buffer is modified, the current window is
"                   always split.
"                  
"                   To control where the new split windows goes relative to
"                   the current window, use the variable:"                   
"                     let g:bufExplSplitBelow=0  " Put new window above
"                                                " current.
"                     let g:bufExplSplitBelow=1  " Put new window below
"                                                " current.
"                   The default for this is to split 'above'.
"=============================================================================

" Has this already been loaded?
if exists("loaded_bufexplorer")
  finish
endif

let loaded_bufexplorer = 1

" 
" Create commands.
" 
if !exists(':BufExplorer')
  command BufExplorer :call s:StartBufExplorer(0)
endif
if !exists(':SBufExplorer')
  command SBufExplorer :call s:StartBufExplorer(1)
endif

" 
" Show detailed help?
" 
if !exists("g:bufExplorerDetailedHelp")
  let g:bufExplorerDetailedHelp = 0
endif

" When opening a new windows, split the new windows below or above the
" current window?  1 = below, 0 = above.
if !exists("g:bufExplSplitBelow")
  let g:bufExplSplitBelow = &splitbelow
endif

" 
" StartBufExplorer
" 
function! s:StartBufExplorer(split)
  " Save the user's settings.
  let saveSplitBelow = &splitbelow

  " Save current and alternate buffer numbers for later.
  let s:currentBufferNumber = bufnr("%")
  let s:alternateBufferNumber = bufnr("#")
  
  " Set to our new values.
  let &splitbelow = g:bufExplSplitBelow

  if a:split || (&modified && &hidden == 0)
    sp [BufExplorer]
    let w:bufExplorerSplitWindow = 1
  else
    e [BufExplorer]
    let w:bufExplorerSplitWindow = 0
  endif

  call s:DisplayBuffers()
  
  " Restore the user's settings.
  let &splitbelow = saveSplitBelow

  unlet saveSplitBelow
endfunction

" 
" DisplayBuffers.
" 
function! s:DisplayBuffers()
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

    if !exists("g:did_bufexplorer_syntax_inits")
      let g:did_bufexplorer_syntax_inits = 1
      hi link bufExplorerHelp Special
      hi link bufExplorerHelpEnd Special
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
  nnoremap <buffer> ? :call <SID>ToggleHelp()<cr>
  nnoremap <buffer> <2-leftmouse> :call <SID>DoubleClick()<cr>
 
  " Delete all lines in buffer.
  1,$d _

  call s:AddHeader()
  $ d
  call s:ShowBuffers()
 
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
function! s:AddHeader()
  1
  if w:longHelp == 1
    let header = "\" Buffer Explorer\n"
    let header = header."\" ----------------\n"
    let header = header."\" <enter> or Mouse-Double-Click : open buffer under cursor\n"
    let header = header."\" d : delete buffer.\n" 
    let header = header."\" q : quit the Buffer Explorer\n"
    let header = header."\" ? : toggle this help\n"
  else
    let header = "\" Press ? for Help\n"
  endif

  let header = header."\"=\n"
  put! =header

  unlet header
endfunction

" 
" ShowBuffers.
" 
function! s:ShowBuffers()
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

  let &report = oldRep
  let &showcmd = save_sc
  
  unlet! fileNames _NBuffers _i oldRep save_sc _BufName
endfunction

" 
" SelectBuffer.
" 
function! s:SelectBuffer()
  let save_sc = &showcmd
  set noshowcmd 
  
  let _cfile = getline('.')

  " Are we on a line with a file name?
  if _cfile =~'^"'
    unlet _cfile
    return
  endif
 
  " Skip over the readonly, modified indicators if there is any.
  let _cfile = strpart(_cfile,4,strlen(_cfile))
  "let _cfile = substitute(_cfile, "\\", "\\\\", "g")

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
function! s:DeleteBuffer()
  let oldRep = &report
  let &report = 10000
  let save_sc = &showcmd
  set noshowcmd 
  
  setlocal modifiable
  
  let _cfile = getline('.')
  " Skip over the readonly, modified indicators if there is any.
  let _cfile = strpart(_cfile,4,strlen(_cfile))
"  let _cfile = substitute(_cfile, "\\", "\\\\", "g")
  
  " Check it the file exists and is readable.
  if filereadable(_cfile)
    " Delete the buffer selected.
    exec("bd ".(bufnr(_cfile)))
    " Delete the buffer's name from the list.
    d _
  endif

  setlocal nomodifiable

  let &report = oldRep
  let &showcmd = save_sc

  unlet _cfile oldRep save_sc
endfunction

" 
" Back To Previous Buffer.
"
function! s:BackToPreviousBuffer()
  let save_sc = &showcmd
  set noshowcmd 

  if(w:bufExplorerSplitWindow == 1)
    exec("close!")
  endif

  if(s:alternateBufferNumber != -1)
    exec("b! ".s:alternateBufferNumber)
  endif

  if(s:currentBufferNumber != -1)
    exec("b! ".s:currentBufferNumber)
  endif
 
  let &showcmd = save_sc

  unlet save_sc
endfunction

" 
" Toggle between short and long help
" 
function! s:ToggleHelp()
  if exists("w:longHelp") && w:longHelp==0
    let w:longHelp=1
    let s:longHelp=1
  else
    let w:longHelp=0
    let s:longHelp=0
  endif
  
  " Allow modification
  setlocal modifiable
  call s:UpdateHeader()
  
  " Disallow modification
  setlocal nomodifiable
endfunction

" 
" Update the header
" 
function! s:UpdateHeader()
  let oldRep = &report
  let save_sc = &showcmd
  let &report = 10000
  set noshowcmd 
  
  " Save position
  normal! mt
  
  " Remove old header
  0
  1,/^"=/ d
  
  " Add new header
  call s:AddHeader()
  
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
" Double click with the mouse
"
function s:DoubleClick()
  call s:SelectBuffer()
endfun

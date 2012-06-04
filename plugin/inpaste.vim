" inpaste.vim - Use curl to login and post text to a webserver
" Maintainer:   Steven Humphrey
" Version:      0.9

" Assuming you have pathogen, install in ~/.vim/bundle/inpaste/plugin
" Alternatively, put it somewhere else and manually source it from your vimrc
" file.
" This script allows you to paste your buffer, visually selected text
" or range to a webserver.
" This script refers to InPaste which is a private web service but the VimL could be
" adapted and made useful to your needs.
"
" The following needs to be added to your vimrc
" let g:inpaste_user = 'username'
" let g:inpaste_pass = 'password'

if exists("g:loaded_inpaste")
  finish
endif
let g:loaded_inpaste = 1

if !exists('g:inpaste_user') || strlen(g:inpaste_user) == 0
    echohl ErrorMsg | echomsg "Please set g:inpaste_user and g:inpaste_pass in your vimrc" | echohl None
endif

" TODO: Make these configurable
let s:cookie_jar = "~/.vim/cookie_jar"
let s:cmd = 'curl --cookie ' . s:cookie_jar . ' --cookie-jar ' . s:cookie_jar
let s:login_url = "http://infra/login"
let s:paste_url = "http://infra/inpaste"

" Submit the actual paste
" Assumes that the paste services has a form with the following fields:
" name, description, language, code
" Also assumes that the cookie_jar contains relevant login info
function! s:paste(name, type, file)
  let command = s:cmd . ' --data "description=VimPost" --data "name=' . a:name . '" --data "language=' . a:type . '" --data-urlencode "code@' . a:file . '" "' . s:paste_url . '" --location'
  let result = system(command)
  return result
endfunction

" Submit the login form
" If we need to login, this will submit a form with the following fields:
" username, password
" It will store the results in the cookie_jar
function! s:login(username, password)
  let command = s:cmd . ' --data "username=' . a:username . '" --data "password=' . a:password . '" --location "'. s:login_url . '"'
  let result = system(command)
  if strlen(matchstr(result, "logged in as")) > 0
    return 1
  endif
  return 0
endfunction

" Try and paste, if we get a login page try and log in
" Then try and paste again
function! s:log_in_and_paste(name, type, lines)
  let filename = "/tmp/inpaste_post"
  call writefile(a:lines, filename)
  let result = s:paste(a:name, a:type, filename)
  if strlen(matchstr(result, '<form action="/login"')) > 0
    if !s:login(g:inpaste_user, g:inpaste_pass)
      echohl Error | echomsg "Failed to login" | echohl None
      return 0
    endif
    let result = s:paste(a:name, a:type, filename)
  endif

  if strlen(matchstr(result, 'InPaste: </span>' . a:name)) > 0
    return 1
  else 
    echohl Error | echomsg "Something went wrong with the InPaste" | echohl None
  endif
  return 0

endfunction

" The main function
" Takes an optional name and posts the range of text supplied to InPaste
" If name is not supplied it will attempt to get the name from the filename
function! Inpaste(name) range
    " Work out the name of the inpaste
    let filename = a:name
    if strlen(filename) == 0
        let filename = expand('%')
    endif
    " Work out the syntax type of the inpaste
    " If we don't have a syntax type, we can't paste
    let type = &filetype
    if strlen(type) == 0
        echohl ErrorMsg | echomsg "Unknown filetype. Please 'set ft=myfiletype'" | echohl None
        return
    endif

    " Get the entire file into an array of lines
    let lines = getline(a:firstline, a:lastline)
    "call writefile(lines, "/tmp/woopwoop")

    " submit inpaste
    if s:log_in_and_paste(filename, type, lines)
      echomsg s:paste_url . "/" . g:inpaste_user . "/" . filename
    else 
      echohl Error | echomsg "Failed to submit to inpaste" |echohl None
    endif

endfunction


" Give the user an :Inpaste command rather than :call Inpaste("name")
" 0 or 1 arguments are allowed,
" autocomplete to the filename,
" range allowed, defaults to whole file
command! -nargs=? -complete=file -range=% Inpaste <line1>,<line2>call Inpaste(<q-args>)

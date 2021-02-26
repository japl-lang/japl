syntax keyword japlTodos TODO XXX FIXME NOTE

syntax keyword japlKeywords
	\ if
	\ var
	\ fun

syntax keyword japlBooleans 
	\ true 
	\ false

syntax match japlNumber "\v<\d+>"
syntax match japlNumber "\v<\d+.\d+>"
syntax match japlComment "//.*$"
syntax match japlBlock "{"
syntax match japlBlock "}"

syntax region japlString start=/"/ end=/"/

highlight default link japlTodos Todo
highlight default link japlComment Comment
highlight default link japlString String
highlight default link japlNumber Number
highlight default link japlBoolean Keyword
highlight default link japlKeywords Keyword
highlight default link japlBlock Keyword

" the following exist too:
" Operator
" PreProc (c macros e.g.)
" Delimeter
" Structure
" Type (user defined types)
" Include

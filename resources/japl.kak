hook global BufCreate .*[.]jpl %{
  set-option buffer filetype japl
}

addhl shared/japl regions
addhl shared/japl/code default-region group
addhl shared/japl/comment-line region '//' '$' fill comment
addhl shared/japl/comment-multiline region '/\*' '\*/' fill comment
addhl shared/japl/string region '"' '"' fill string

addhl shared/japl/code/ regex '\b(?:true|false|nil)\b' 0:keyword
addhl shared/japl/code/ regex '\b(?:if|else|while|for)\b' 0:keyword
addhl shared/japl/code/ regex '\b(?:fun|lambda|return)\b' 0:keyword
addhl shared/japl/code/ regex '\b(?:var)\b' 0:keyword
addhl shared/japl/code/ regex '\b(?:class)\b' 0:keyword

addhl shared/japl/code/num regex '\b[0-9]+(.[0-9]+)?' 0:value

hook -group japl-highlight global WinSetOption filetype=japl %{ add-highlighter window/ ref japl }
hook -group japl-highlight global WinSetOption filetype=(?!japl).* %{ remove-highlighter window/japl }

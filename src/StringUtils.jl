const has_round = contains("(")
const has_square = contains("[")
const has_curl = contains("{")
const has_asterisk = contains("*")
const has_equal = contains("=")
const has_dot = contains(".")
const non_digit_dot_regex =  r"(?<!\d)\.(?!\d)" # regex to check for non-digit dot when parsing string
const digit_dot_regex  = r"(?<=\d)\.(?=\d)"
"""
    has_nondigit_dot(s::AbstractString)

Checks for any dot symbol `.`, which is not decimal digits separator
"""
has_nondigit_dot(s::AbstractString) = begin 
    for mi in eachmatch(non_digit_dot_regex,s)
        isnothing(mi) || return true
    end
    return false
end
"""
    has_digit_dot(s::AbstractString)

Checks for any dot symbol `.`, which is decimal digits separator
"""
has_digit_dot(s::AbstractString) = begin 
    for mi in eachmatch(digit_dot_regex,s)
        isnothing(mi) || return true
    end
    return false
end
"""
Regex to check if string contains braces, non-digital dots and equality symbols
"""
const is_simple_reg = begin
    str ="["
    for c in "{}[]()="
        global str *="\\Q$(c)\\E"
    end
    str *=raw"(?<!\d)\.(?!\d)"
    str *="]"
    Regex(str)
end
"""
    is_simple_pattern(s::AbstractString)

see [`is_simple_reg`](@ref)
"""
is_simple_pattern(s::AbstractString)  = isnothing(match(is_simple_reg,s))

"""
    extract_field(s)

Returns right part of string  separated by non-digit dot `.` 
"""
function extract_field(s)
    m = match(non_digit_dot_regex, s)
    return isnothing(m) ? "" : s[m.offset + 1 : end]
end
"""
    split_tag_and_field_name(s)

Splits  string  into two parts by non-digit dot `.` 
"""
function split_tag_and_field_name(s)
    return map(strstr,eachsplit(s,non_digit_dot_regex))
end
"""
    split_equality(s::AbstractString)

Splits string by first equality symbol `=`
"""
function split_equality(s::AbstractString)
    m = match(Regex("\\Q=\\E"),s)
    return isnothing(m) ? (s,"") : (s[1:m.offset-1],s[m.offset+1 : end])
end
strstr(s) = string(strip(string(s)))
function extract_between(s::AbstractString,pat_left::AbstractString,pat_right::AbstractString;include_pats::Bool=false)
    reg = Regex("\\Q$(pat_left)\\E(.*?)\\Q$(pat_right)\\E")
    m = match(reg, s)
    include_pats || return isnothing(m) ? "" : string(m.captures[1])
    return isnothing(m) ? "" : pat_left*m.captures[1]*pat_right
end
function extract_after(s::AbstractString,pat::AbstractString;include_pats::Bool=false)
    reg = Regex("\\Q$(pat)\\E(.*)")
    m = match(reg, s)
    include_pats || return isnothing(m) ? "" : string(m.captures[1])
    return isnothing(m) ? "" : pat*string(m.captures[1])
end
function extract_before(s::AbstractString,pat::AbstractString;include_pats::Bool=false)
    regex = Regex("^(.*?)\\Q$(pat)\\E")
    m = match(regex, s)
    include_pats || return isnothing(m) ? "" : m.captures[1]
    return isnothing(m) ? "" : string(m.captures[1])*pat
end
function parse_single_string_key_value(s_str)
        spliterator = eachsplit(s_str,"=")
        (val1,state) = iterate(spliterator)
        key = parse_single_string_or_number(val1)
        (val2,) = iterate(spliterator,state)
        value = parse_single_string_or_number(val2)
    return key => value
end
function parse_single_string_or_number(s_str)
    if has_equal(s_str)
        return parse_single_string_key_value(s_str)
    end
    s_parsed = tryparse(Float64,s_str)
    if isnothing(s_parsed)
        !contains(s_str,"::text") || return strstr(extract_before(s_str,"::text"))
        return strstr(s_str);
    else
        return s_parsed
    end
end
function split_delimited_args(s::AbstractString)
    return parse_single_string_or_number.(split(s,","))
end
for (name_str,left_char,right_char) in zip(("_square","_curl","_round"),('[','{','('),(']','}',')'))
    is_embraced_cur = Symbol("is_embraced"*name_str)
    @eval function $is_embraced_cur(s::AbstractString)
        s = strip(s)
        return length(s) > 0 ? s[1]==$left_char && s[end] == $right_char  : false
    end
    extract_embraced_cur = Symbol("extract_embraced"*name_str)
    reg = Regex("\\Q$(left_char)\\E(.*?)\\Q$(right_char)\\E")
    @eval function $extract_embraced_cur(s)
        m = match($reg, s)
        isnothing(m) ? "" : string(m.captures[1])
    end
    extract_embraced_args_cur = Symbol("extract_embraced_args"*name_str)
    @eval function $extract_embraced_args_cur(s)
        return  s |> $extract_embraced_cur |> split_delimited_args 
    end
end
is_embraced(s) = is_embraced_curl(s) || is_embraced_square(s) || is_embraced_round(s)
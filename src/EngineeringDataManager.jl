module EngineeringDataManager
using XML,Sockets,OrderedCollections #,StructTypes,Observables,
using InteractiveUtils
#include("EngineeringDataTCPserver.jl")
const ENG_DATA_FILE = Ref(".\\src\\EngineeringData.xml")
const SymbolOrNothing = Union{Symbol,Nothing}
const VectOrSymbolOrNothing = Union{Symbol,Nothing,Vector{SymbolOrNothing}}
const PatterTypeUnion = Union{String,OrderedDict,Float64}
const has_round = contains("(")
const has_square = contains("[")
const has_curl = contains("{")
const has_asterisk = contains("*")
const has_equal = contains("=")
const has_dot = contains(".")

export find_nodes, find_nodes_chain
abstract type AbstractMatcher{T,P} end

swap_contains(a,b) = contains(b,a)
always_true(_,_) = true
haskey_swapped(k,D) = haskey(D,k)
 # IN ALL FUNCTIONS THE FIRST ARGUMENT IS PATTERN THE SECOND ARGUMENTS IS THE NODE CONTENT OR INPUT ITSELF
 # contains(a,b) search for 
 # MatchesPat -   true if pattern is totally matched
 # PatContains -  true if the pattern contains the input contains(pat,input) = true
 # ContainsPat  - true if the input contains the pattern contains(inout,pat) = true
 # HasAnyKeyPat - true if the input has at least element of pat as a key
 # HasAllKeysPat - true if the inout has all elements of pat as keys
 # ContainsAnyPat - true if tag contains any of patterns
 _itp = NamedTuple{(:fun,:internal,:consumer)}
for (matcher_type,d) in (:MatchesPat  => _itp((:matches_pat,:isequal,:all)),
                         :PatContains =>  _itp((:pat_contains,:contains,:all)),
                         :ContainsPat => _itp((:contains_pat,:swap_contains,:all)),
                         :ContainsAnyPat => _itp((:contains_any_pat,:contains,:any)),
                         :HasAnyKeyPat => _itp((:has_any_key_pat,:haskey_swapped,:any)),
                         :HasAllKeysPat => _itp((:has_all_key_pat,:haskey_swapped,:all)),
                         :AnyPat => _itp((:any_pat, :always_true,:any)))

    @eval struct $matcher_type{T,P} <: AbstractMatcher{T,P}
        pat::P
        $matcher_type(s::P,type::SymbolOrNothing=nothing) where P =  new{type,P}(s)
    end
    @eval $(d.fun)(pat::P,input,T) where P <: Union{String,Number} = !isnothing(T) ?  hasproperty(input,T) && $(d.internal)(pat,getproperty(input,T)) : $(d.internal)(pat,input)
    @eval (tag::$matcher_type{T})(input) where T = $(d.fun)(tag.pat,input,T)
    (iterate_over, look_in, in_checker) = if matcher_type == :PatContains
                                                (:_input, :pat,:in) 
                                            elseif matcher_type == :AnyPat
                                                (:pat, :pat, :in)  
                                            elseif (matcher_type == :HasAnyKeyPat) || (matcher_type == :HasAllKeysPat)
                                                (:pat, :_input, :haskey_swapped)   
                                            else 
                                                (:pat, :_input, :in)
                                            end
    # when ierating over the collection iterate_over is the collection which members we are looking in look_in    
    @eval function $(d.fun)(pat::P,input,T) where  P <: Union{AbstractVector,AbstractDict,NTuple}
        if !isnothing(T)
            hasproperty(input,T) || return false
            _input = getfield(input,T) 
            !isnothing(_input) || return false
        else
            _input  = input
        end
        # @show pat,_input
        return $(d.consumer)(si-> $in_checker(si,$look_in) ,$iterate_over)
    end
end

struct MatchersSet{T,P} <: AbstractMatcher{T,P} # 
    matchers::P
    MatchersSet(matchers_collection::P,type::Symbol) where P = begin
        @assert in(type,(:any,:all))
        return new{type,P}(matchers_collection)
    end
    MatchersSet(type::Symbol) = begin
        matchers_collection = Vector{AllTagMatchersUnion}()
        return MatchersSet(matchers_collection,type)
    end
end
Base.push!(ms::MatchersSet,v::AbstractMatcher) = Base.push!(ms.matchers,v)

function any_matchers(matchers_collection,node)
    for m in matchers_collection
        !m(node) || return true
    end
    return false
end

function all_matchers(matchers_collection,node)
    for m in matchers_collection
        m(node) || return false
    end
    return true
end
(m::MatchersSet{:any})(node) = any_matchers(m.matchers,node)
(m::MatchersSet{:all})(node) = all_matchers(m.matchers,node)


const AllTagMatchersUnion = Union{subtypes(AbstractMatcher)...}

""" Object to match patterns in inputs and input structures fields
    
matcher  = MatchesPat(pat,field_name::Union{Symbol,Nothing}=nothing);

matcher(input):
Returns true if `pat` is matched to the `input`
object field `field_name` if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
 MatchesPat 
 """
    matcher  = PatContains(pat,field_name::Union{Symbol,Nothing}=nothing);
matcher(input) - true if  `pat` contains the `input.field_name` if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
 PatContains 
 """
    matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
matcher(input) true if the `input.field_name` contains the pattern 
if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
 ContainsPat 
"""
    matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
matcher(input) - true if the` input.field_name` has at least one element of `pat` as a key
if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
 HasAnyKeyPat 
 """
    matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
matcher(input) - true if the `input.field_name` has all elements of `pat` as keys
if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
HasAllKeysPat 
"""
matcher  = ContainsAnyPat(pat,field_name::Union{Symbol,Nothing}=nothing);
matcher(input) - true if `input.field_name` contains any of pat elements 
if `field_name` is `nothing` than `input` itself is matched.
The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
for the list of matchers types"""
ContainsAnyPat

# to utils
strstr(s) = string(strip(s))
#=
function is_embraced_square(s::AbstractString) 
    s = strip(s)
    return length(s) > 0 ? s[1]=='[' && s[end] == ']'  : false
end
function is_embraced_curl(s::AbstractString) 
    s = strip(s)
    return length(s) > 0 ? s[1] == '{' && s[end] == '}'  : false
end
function is_embraced_round(s::AbstractString)
    s = strip(s)
    return length(s) > 0 ? s[1] == '(' && s[end]== ')'  : false   
end
=#
for (name_str,left_char,right_char) in zip(("_square","_curl","_round"),('[','{','('),(']','}',')'))
    is_embraced_cur = Symbol("is_ambraced"*name_str)
    @eval function $is_embraced_cur(s::AbstractString)
        s = strip(s)
        return length(s) > 0 ? s[1]==$left_char && s[end] == $right_char  : false
    end
    extract_embraced_cur = Symbol("extract_embraced"*name_str)
    left_reg = Regex("\\$(left_char)")
    right_reg = Regex("\\$(right_char)")
    @eval function $extract_embraced_cur(s)
        !$is_embraced_cur(s) || return extract_between(s,$left_reg,$right_reg)
        return s
    end
end

is_embraced(s) = is_embraced_curl(s) || is_embraced_square(s) || is_embraced_round(s)
#=
extract_embraced_square(s) = is_embraced_square(s) ? extract_between(s,Regex("\\["),Regex("\\]")) : s
extract_embraced_curl(s) = is_embraced_curl(s) ? extract_between(s,Regex("\\{"),Regex("\\}")) : s
extract_embraced_round(s) = is_embraced_round(s) ? extract_between(s,Regex("\\("),Regex("\\)")) : s
=#
#=function extract_embraced(s,embrace) 

    if is_embraced_curl(s)
            extract_between(s,Regex("\\{"),Regex("\\}"))
    elseif is_embraced_square(s)
            extract_between(s,Regex("\\["),Regex("\\]"))
    elseif is_embraced_round(s)
            extract_between(s,Regex("\\("),Regex("\\)"))
    else
        (has_round_f,has_curl_f,has_square_f) = (has_round(s),has_curl(s),has_square(s))
        
    end
end=#
#extract_embraced_square(s) = extract_between(s,Regex("\\["),Regex("\\]"))
extract_between(s::AbstractString,left::AbstractString,right::AbstractString) = extract_between(s,Regex(left),Regex(right))
function extract_between(s::AbstractString,pat_left::Regex,pat_right::Regex)
    ind_left = match(pat_left,s).offset 
    !isnothing(ind_left) || return ""
    ind_right = match(pat_right,s).offset
    !isnothing(ind_right) || return ""
    return (ind_left <= ind_right) && (ind_right >= 3) ? s[ind_left + 1 : ind_right - 1] : ""
end
function extract_after(s::AbstractString,pat::Regex)
    ind_left = match(pat,s).offset 
    !isnothing(ind_left) || return s
    return s[ind_left + 1 : end]
end
function extract_before(s::AbstractString,pat::Regex)
    ind_right = match(pat,s).offset 
    !isnothing(ind_right) || return s
    return s[1 : ind_right - 1]
end
struct ChainMatcher
    pat_vect::Vector{AllTagMatchersUnion}
    state::Int
    ChainMatcher(pat_string::String,field_types::VectOrSymbolOrNothing=nothing) = begin
        pat_vect = parse_chain_data(pat_string, field_types)
        new(pat_vect,1)
    end
end
Base.iterate(t::ChainMatcher) = iterate(t.pat_vect);
Base.iterate(t::ChainMatcher,state) = iterate(t.pat_vect,state);

function get_field_name_from_single_string(s)
    contains(s,".") || return nothing

end
function parse_field_string(s::AbstractString)
    if has_round(s) # field has keys
        field_name = Symbol(extract_before(s,Regex("\\(")))
        args = extract_embraced_round(s)
        
        if has_equal(args) # key-value pairs
            if is_embraced(args)
               # HasAnyKeyPat 
               # HasAllKeysPat
            else # has no {} or []

            end
        else # only keys
            is_embraced(args) || error("set of keys must be embraced in {...} or [...]")
            args = extract_embraced(args)
            args_vect = parse_single_string_or_number.(split(args,","))
             if is_embraced_curl(args)
                return HasAllKeysPat(args_vect,field_name)
             elseif is_embraced_square(args)
                return HasAnyKeysPat(args_vect,field_name)  
             else
                error("incorrect keys set syntax, must be embraced in {...} or [...] ")
             end  
        end
    elseif has_equal(s) # simple field
        splitted = map(strstr,eachsplit(s,"=")) 
        length(splitted) == 2 || error("Incorrect string $(s)")
        field_name = Symbol(splitted[1])
        value_str = splitted[2]
        if !is_embraced_curl(value_str) && !is_embraced_square(value_str) # simple argument
            value = parse_single_string_or_number(value_str)
            if isa(value,AbstractString)
                if !has_asterisk(value) 
                    return MatchesPat(value,field_name)     
                else
                    value = replace(value,"*"=>"")
                    return ContainsPat(value,field_name) 
                end
            else
                return MatchesPat(value,field_name)
            end
        else # embraced!!!
            if is_embraced_curl(s)
                matchers_set = MatchersSet(:all)
            else
                matchers_set = MatchersSet(:any)
            end
            # field_name
            value_str = extract_embraced(value_str)
            for vi in eachsplit(value_str,",")
                vi_cur = join((field_name, strstr(vi)),"=")
                push!(matchers_set,parse_field_string(vi_cur))
            end
            return matchers_set
        end
    else
        error("Incorrect string $(s)")
    end
end
function parse_single_string_or_number(s_str)::Union{String,Float64}
    if isnothing(tryparse(Float64,s_str))
        !contains(s_str,"::text") || (s = extract_before(s_str,Regex("::text")))
        s = strstr(s_str);
    else
        s = parse(Float64,s_str)
    end
    return s
end
function parse_chain_string_token!( s::String)
    
    if !is_embraced(s) 
        if has_asterisk(s) 
            if  s == "*" 
                return AnyPat(s,cur_field)
            else
                if has_dot(s) # contains both dot and asterics
                     splitted = strip.(split(s,"."))   
                     length(splitted) == 2 || error("Incorrect string $(s)")
                else

                end    
            end
        end
    elseif is_embraced(s)
         si_patt = split(extract_embraced(s))
         length(si_patt) > 0 || return nothing
         push!(tag_vect,ContainsAnyPat(strstr.(si_patt),cur_field))
    else
         return MatchesPat(s,cur_field)
    end
end

function parse_chain_data(s::String,field_types::VectOrSymbolOrNothing=nothing)
    tag_vect = Vector{AllTagMatchersUnion}()
    is_single_element_field = isnothing(field_types) || isa(field_types,Symbol)
    counter = 0
    for si in eachsplit(s,"/")
        counter +=1
        s_cur = strstr(si)
        cur_field = is_single_element_field ? field_types : field_types[counter]

    end
    return tag_vect
end
function find_nodes_chain(starting_node::T,xml_chain_string::String,field_types::VectOrSymbolOrNothing=:tag) where T
    node_vector = Vector{T}()
    return find_nodes_chain!(node_vector,starting_node,ChainMatcher(xml_chain_string,field_types))
end
function find_nodes_chain!(node_vector::Vector{T},nd::T,tag_chain::ChainMatcher,state::Int=1,first_node::Bool=true) where T
    (tag,next_state) = iterate(tag_chain,state)
    has_next_state = !isnothing(iterate(tag_chain,next_state))
    if tag(nd) 
        if !has_next_state
            push!(node_vector,nd)
            !first_node || return node_vector
        end
    elseif first_node
        return node_vector
    end
    !isnothing(nd.children) || return node_vector
    for ndi in nd.children
        isa(ndi,T) || continue
        find_nodes_chain!(node_vector,ndi,tag_chain,next_state)
    end
    return node_vector
end



const XML_DOC =  begin 
                        out = Ref{Node}()
                        try    
                            out[] =  XML.read(ENG_DATA_FILE[],Node)
                        catch Exc
                            @show Exc
                            println("Unable to read default file $(ENG_DATA_FILE[])")
                        end 
                        out
                end
const StringFloat = Union{String,Float64}
const ParamIDs = Ref(OrderedDict{String,StringFloat}())
const ParamNames = Ref(OrderedDict{StringFloat,String}())
is_xml_ok() = @assert isassigned(XML_DOC) "No document file assigned, use `read_engineering_data` function to assign the file"
function read_engineering_data(;file_fullname::String = ENG_DATA_FILE[])
    try    
        XML_DOC[] =  XML.read(file_fullname,Node)
        return true
    catch Exc
        @show Exc
        println("Unable to read default file $(file_fullname)")
        return false
    end 
end
function material_nodes(;material_name = "")
    is_xml_ok()
    names = Vector{String}();
    material_nodes_vect = find_nodes("Material")
    !isempty(material_nodes_vect) || return names
    for mi in material_nodes_vect
        name_node = find_nodes_chain(mi,"Material/BulkDetails/Name")
        !isempty(name_node) || continue
        @assert length(name_node) == 1 "Names node vector has multiple elements ???"
        has_single_child(name_node[]) || continue
        nd_cur = name_node[].children[]
        if !isnothing(nd_cur.value) && isa(nd_cur.value,String)
            push!(names,nd_cur.value)
        end
    end
    return (names,material_nodes_vect)
end
function fill_parameters_ids()
    meta_data_node = find_nodes("Metadata")
    D = ParamIDs[]
    D2 = ParamNames[]
    empty!(D)
    !isempty(meta_data_node) || return false
    param_details = find_nodes(meta_data_node[],"ParameterDetails")
    for p_i in param_details
        !isnothing(p_i.attributes) || continue
        haskey(p_i.attributes,"id") || continue
        current_key = p_i.attributes["id"]
        name_node = find_nodes_chain(p_i,"ParameterDetails/Name")
        has_single_element(name_node) || continue
        has_single_child(name_node[]) || continue
        # end_node_type = nodetype(name_node[].children[])
        value  = name_node[].children[].value
        push!(D, current_key => value)
        push!(D2,value => current_key )
    end
end
has_single_child(node) =  !isnothing(node.children) && length(node.children) == 1
has_single_element(node_vect) = isa(node_vect,AbstractVector) && length(node_vect) == 1

function find_nodes(tag::String="EngineeringData", field_type::SymbolOrNothing=:tag) 
    is_xml_ok()
    find_nodes(XML_DOC[],MatchesPat(tag,field_type))
end
find_nodes(starting_node,tag::String,field_type::SymbolOrNothing=:tag) = find_nodes(starting_node,MatchesPat(tag,field_type))


function find_nodes(starting_node::T,tag::AbstractMatcher) where T
    node_vector = Vector{T}()
    find_nodes!(node_vector,starting_node,tag)
    return node_vector
end


function find_nodes!(node_vector::Vector{T},nd::T,tag::AbstractMatcher=MatchesPat("EngineeringData",:tag)) where T
    !tag(nd) || push!(node_vector,nd)
    !isnothing(nd.children) || return node_vector
    for ndi in nd.children
        find_nodes!(node_vector,ndi,tag)
    end
    return node_vector
end
end # module end
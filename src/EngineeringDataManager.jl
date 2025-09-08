module EngineeringDataManager
using XML,Sockets,OrderedCollections #,StructTypes,Observables,
using InteractiveUtils
#include("EngineeringDataTCPserver.jl")
const ENG_DATA_FILE = Ref(".\\src\\EngineeringData.xml")
const SymbolOrNothing = Union{Symbol,Nothing}
const VectOrSymbolOrNothing = Union{Symbol,Nothing,Vector{SymbolOrNothing}}
const PatterTypeUnion = Union{String,OrderedDict,Float64}
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
 # ContainsAnyPat - true if tag contains any of matterns
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
is_embraced(s::AbstractString) = contains(s,"[") && contains(s,"]")
extract_embraced(s) = extract_between(s,Regex("\\["),Regex("\\]"))
extract_between(s::AbstractString,left::AbstractString,right::AbstractString) = extract_between(s,Regex(left),Regex(right))
function extract_between(s::AbstractString,pat_left::Regex,pat_right::Regex)
    ind_left = match(pat_left,s).offset 
    !isnothing(ind_left) || return ""
    ind_right = match(pat_right,s).offset
    !isnothing(ind_right) || return ""
    return (ind_left <= ind_right) && (ind_right >= 3) ? s[ind_left + 1 : ind_right - 1] : ""
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

function parse_chain_data(s::String,field_types::VectOrSymbolOrNothing=nothing)
    tag_vect = Vector{AllTagMatchersUnion}()
    is_single_element_field = isnothing(field_types) || isa(field_types,Symbol)
    counter = 0
    for si in eachsplit(s,"/")
        counter +=1
        s_cur = strstr(si)
        cur_field = is_single_element_field ? field_types : field_types[counter]
       if contains("*",s_cur)  
            push!(tag_vect,AnyPat(s_cur,cur_field))
       elseif is_embraced(s_cur)
            si_patt = split(extract_embraced(s_cur))
            length(si_patt) > 0 || continue
            push!(tag_vect,ContainsAnyPat(strstr.(si_patt),cur_field))
       else
            push!(tag_vect,MatchesPat(s_cur,cur_field))
       end
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
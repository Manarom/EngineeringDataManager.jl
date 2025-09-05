module EngineeringDataManager
using XML,Sockets,OrderedCollections #,StructTypes,Observables,
using InteractiveUtils
#include("EngineeringDataTCPserver.jl")
const SymbolOrNothing = Union{Symbol,Nothing}
const VectOrSymbolOrNothing = Union{Symbol,Nothing,Vector{SymbolOrNothing}}
export find_nodes
abstract type AbstractMatcher{T} end
for matcher_type in (:MatchesPat, :ContainsPat, :PatContains, :AnyPat)
    @eval struct $matcher_type{T} <: AbstractMatcher{T}
        pat::String
        $matcher_type(s::String,type::SymbolOrNothing=nothing) =  new{type}(s)
    end
end
struct AnyPatFixed{T} <: AbstractMatcher{T} # multipatterns matcher
    pat::Vector{String}
    AnyPatFixed(s::Vector{String},type::SymbolOrNothing=nothing) =  new{type}(s)
end
(tag::MatchesPat{T})(input) where T = !isnothing(T) ?  hasproperty(input,T) && tag.pat == getproperty(input,T) : tag.pat == input
(tag::AnyPat{T})(input) where T = !isnothing(T) ?  hasproperty(input,T) : tag.pat == input
#(tag::TagContainsPat)(input) = contains(input,tag.pat)
#(tag::PatContainsTag)(input) = contains(tag.pat,input) 
function (tag::AnyPatFixed{T})(input::Base.String) where T
    for p in tag.pat
        !(!isnothing(T) ?  hasproperty(input,T) && tag.pat == getproperty(input,T) : p == input) || return true
    end
    return false
end

const AllTagMatchersUnion = Union{subtypes(AbstractMatcher)...}
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
            push!(tag_vect,AnyPatFixed(strstr.(si_patt),cur_field))
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
function find_nodes_chain!(node_vector::Vector{T},nd::T,tag_chain::ChainMatcher,state::Int=1) where T
    (tag,next_state) = iterate(tag_chain,state)
    has_next_state = !isnothing(iterate(tag_chain,next_state))
    if tag(nd) 
        if !has_next_state
            push!(node_vector,nd)
            return node_vector
        end
    else
        return node_vector
    end
    !isnothing(nd.children) || return node_vector
    for ndi in nd.children
        isa(ndi,T) || continue
        find_nodes_chain!(node_vector,ndi,tag_chain,next_state)
    end
    return node_vector
end


const ENG_DATA_FILE = Ref(".\\src\\EngineeringData.xml")
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
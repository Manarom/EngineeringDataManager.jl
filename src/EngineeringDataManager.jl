module EngineeringDataManager
using XML,Sockets,JSON3,StructTypes,Observables
#include("EngineeringDataTCPserver.jl")
export find_tag
abstract type AbstractTagMatcher end
struct TagMatchesPat <: AbstractTagMatcher 
    pat
end
struct TagContainsPat <: AbstractTagMatcher 
    pat
end
struct PatContainsTag <: AbstractTagMatcher 
    pat
end
(tag::TagMatchesPat)(input) = tag.pat == input
(tag::TagContainsPat)(input) = contains(input,tag.pat)
(tag::PatContainsTag)(input) = contains(tag.pat,input) 



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
const ParamIDs = Ref(Dict{String,String}())
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
    material_nodes_vect = find_tag("Material")
    !isempty(material_nodes_vect) || return names
    for mi in material_nodes_vect
        name_node = find_tag(mi,"Name")
        !isempty(name_node) || continue
        @assert length(name_node) == 1 "Names node vector has multiple elements ???"
        !isempty(name_node[].children) || continue
        nd_cur = name_node[].children[]
        if !isnothing(nd_cur.value) && isa(nd_cur.value,String)
            push!(names,nd_cur.value)
        end
    end
    return (names,material_nodes_vect)
end
function fill_ids()
    meta_data_node = find_tag("Metadata")
    !isempty(meta_data_node) || return false
    param_details = find_tag(meta_data_node[],"ParameterDetails")
    for p_i in param_details
        !isnothing(p_i.attributes) || continue
        haskey(p_i.attributes,"id") || continue
        current_key = p_i
    end
end
function find_tag(tag::String="EngineeringData") 
    is_xml_ok()
    find_tag(XML_DOC[],TagMatchesPat(tag))
end
find_tag(starting_node,tag::String) = find_tag(starting_node,TagMatchesPat(tag))
function find_tag(starting_node::T,tag::AbstractTagMatcher) where T
    node_vector = Vector{T}()
    find_tag!(node_vector,starting_node,tag)
    return node_vector
end


function find_tag!(node_vector::Vector{T},nd::T,tag::AbstractTagMatcher=TagMatchesPat("EngineeringData")) where T
    !tag(nd.tag) || push!(node_vector,nd)
    !isnothing(nd.children) || return node_vector
    for ndi in nd.children
        find_tag!(node_vector,ndi,tag)
    end
    return node_vector
end
end # module end
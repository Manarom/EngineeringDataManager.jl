using Revise,XML
pwd()
include(raw"EngineeringDataManager.jl")
using .EngineeringDataManager.XMLwalker

using OrderedCollections
global AttrType = Union{OrderedDict,Nothing,String}
mutable struct NodeImitation
    tag::String
    children::Union{Vector{NodeImitation},Nothing}
    attributes::AttrType
    NodeImitation(;tag::String,children=nothing,attributes::AttrType=nothing) = new(tag,children,attributes)
end
begin
   global node11 = NodeImitation(tag="leaf1",attributes = OrderedDict("id"=>"p1","b"=>10))
   global node12 = NodeImitation(tag="leaf2",attributes = OrderedDict("id"=>"p2","c"=>10))
   global node1 = NodeImitation(tag="branch1",children = [node11,node12])
   global  node21 = NodeImitation(tag="leaf1",attributes = "absd")
   global node2 = NodeImitation(tag="branch2",children = [node21])
   global root_node = NodeImitation(tag="root",children = [node1,node2])
end

#m = XMLwalker.chain_string_token_to_matcher("{branch1, leaf1 }")
# find_nodes(root_node,m) 
#XMLwalker.field_string_to_matcher("abltabl([*A,B,C])")

#XMLwalker.chain_string_token_to_matcher("branch1")
#XMLwalker.is_simple_pattern("branch1")
XMLwalker.chain_string_token_to_matcher("[a,b,c]", :tag)
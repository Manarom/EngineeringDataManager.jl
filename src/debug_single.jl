include(raw"EngineeringDataManager.jl")
import .EngineeringDataManager as E
#E.read_engineering_data()
#meta_data_node = E.find_nodes("Metadata")
#param_details = E.find_nodes(meta_data_node[],"ParameterDetails")
#aut = E.find_nodes_chain(param_details[7],"ParameterDetails/Name")
#E.fill_parameters_ids()
#E.ParamIDs[]

#D = E.ParamIDs[]
#E.parse_chain_data("A/B/[C D]/f")


mat_nodes = E.material_nodes()

using OrderedCollections
AttrType = Union{OrderedDict,Nothing}
mutable struct NodeImitation
    tag::String
    children::Union{Vector{NodeImitation},Nothing}
    attributes::AttrType
    NodeImitation(;tag::String,children=nothing,attributes::AttrType=nothing) = new(tag,children,attributes)
end

node11 = NodeImitation(tag="leaf1",attributes = OrderedDict("id"=>"p1","b"=>10))
node12 = NodeImitation(tag="leaf2",attributes = OrderedDict("id"=>"p2","c"=>10))
node1 = NodeImitation(tag="branch1",children = [node11,node12])
node2 = NodeImitation(tag="branch2")
root_node = NodeImitation(tag="root",children = [node1,node2])

E.MatchesPat("branch1",:tag)(node1)
node_branch1 = E.find_nodes(root_node,"branch1")
nodes_branch = E.find_nodes(root_node,E.ContainsPat("branch",:tag))

lef_nodes_branch1 = E.find_nodes(nodes_branch[1],E.ContainsPat("leaf",:tag))
lef_nodes_branch1_2 = E.find_nodes(nodes_branch[1],E.PatContains("leaf1leaf2",:tag))

lef_nodes_branch1 = E.find_nodes(nodes_branch[1],E.ContainsPat("leaf",:tag))

lef_nodes_branch1 = E.find_nodes(root_node,E.ContainsPat(("id"=>"p1",),:attributes))

lef_nodes_branch1 = E.find_nodes(root_node,E.HasAnyKeyPat(("id",),:attributes))
lef_nodes_branch1 = E.find_nodes(root_node,E.HasAllKeysPat(("id","b"),:attributes))
using Revise,XML
pwd()
includet(raw"EngineeringDataManager.jl")
data  = XML.read(EngineeringDataManager.ENG_DATA_FILE[],Node)

EngineeringDataManager.read_engineering_data()
param_details = EngineeringDataManager.find_nodes(EngineeringDataManager.find_nodes("Metadata")[],"ParameterDetails")

(material_names,materials_nodes) = EngineeringDataManager.material_nodes()
prop_node = EngineeringDataManager.find_nodes_chain(materials_nodes[1],"Material/BulkDetails/PropertyData")

XML.attributes(prop_node[1])

meta_data_node = EngineeringDataManager.find_nodes("Metadata")



EngineeringDataManager.extract_between("[A b]",Regex("\\["),Regex("\\]"))

EngineeringDataManager.fill_parameters_ids()
EngineeringDataManager.ParamIDs[]

using OrderedCollections
AttrType = Union{OrderedDict,Nothing,String}
mutable struct NodeImitation
    tag::String
    children::Union{Vector{NodeImitation},Nothing}
    attributes::AttrType
    NodeImitation(;tag::String,children=nothing,attributes::AttrType=nothing) = new(tag,children,attributes)
end
begin
    node11 = NodeImitation(tag="leaf1",attributes = OrderedDict("id"=>"p1","b"=>10))
    node12 = NodeImitation(tag="leaf2",attributes = OrderedDict("id"=>"p2","c"=>10))
    node1 = NodeImitation(tag="branch1",children = [node11,node12])
    node21 = NodeImitation(tag="leaf1",attributes = "absd")
    node2 = NodeImitation(tag="branch2",children = [node21])
    root_node = NodeImitation(tag="root",children = [node1,node2])
end
mm = EngineeringDataManager.parse_field_string("attributes=*sd")
mm(node21)
mm(node12)
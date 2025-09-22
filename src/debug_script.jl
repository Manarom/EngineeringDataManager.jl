#using Revise
include("EngineeringDataManager.jl")


EngineeringDataManager.read_engineering_data()


EngineeringDataManager.IDS[]
EngineeringDataManager.NAMES[]
EngineeringDataManager.NAMES[]["Thermal Conductivity"]
EngineeringDataManager.IDS[]["pa4"]


EngineeringDataManager.material_nodes(material_name = "BAFS")
EngineeringDataManager.MATERIALS_NODES[]

props_and_pars_nodes_for_lam = EngineeringDataManager.get_property_node("Thermal Conductivity","BAFS")

begin
bb = EngineeringDataManager.get_property_node("Thermal Conductivity","BAFS")[]

par_node6 = EngineeringDataManager.ParameterValueNode(bb.children[6])
par_node5 = EngineeringDataManager.ParameterValueNode(bb.children[5])
par_node7 = EngineeringDataManager.ParameterValueNode(bb.children[7])

qual = EngineeringDataManager.get_all_qualifiers(par_node7)

parameter_node_data = EngineeringDataManager.get_node_data(par_node5)
parameter_node_data.qualifiers


prop_node = EngineeringDataManager.PropertyDataNode(bb)

#parameter_node_data = EngineeringDataManager.get_node_data(prop_node)
end

parameter_node_data = EngineeringDataManager.get_node_data(prop_node)
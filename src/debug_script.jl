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



EngineeringDataManager.extractBetween("[A b]",Regex("["),Regex("]"))

EngineeringDataManager.fill_parameters_ids()
EngineeringDataManager.ParamIDs[]
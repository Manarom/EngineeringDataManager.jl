include(raw"EngineeringDataManager.jl")
EngineeringDataManager.read_engineering_data()
meta_data_node = EngineeringDataManager.find_nodes("Metadata")
param_details = EngineeringDataManager.find_nodes(meta_data_node[],"ParameterDetails")
aut = EngineeringDataManager.find_nodes_chain(param_details[7],"ParameterDetails/Name")
EngineeringDataManager.fill_parameters_ids()
EngineeringDataManager.ParamIDs[]

D = EngineeringDataManager.ParamIDs[]
EngineeringDataManager.parse_chain_data("A/B/[C D]/f")


mat_nodes = EngineeringDataManager.material_nodes()
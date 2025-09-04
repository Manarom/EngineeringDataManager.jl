using Revise,XML
pwd()
includet(raw"EngineeringDataManager.jl")
data  = XML.read(EngineeringDataManager.ENG_DATA_FILE[],Node)

EngineeringDataManager.read_engineering_data()
param_details = EngineeringDataManager.find_tag(EngineeringDataManager.find_tag("Metadata")[],"ParameterDetails")

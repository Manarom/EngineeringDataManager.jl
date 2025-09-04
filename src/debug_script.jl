using Revise,XML
pwd()
includet(raw"EngineeringDataManager.jl")
data  = XML.read(EngineeringDataManager.ENG_DATA_FILE[],Node)

EngineeringDataManager.read_engineering_data()

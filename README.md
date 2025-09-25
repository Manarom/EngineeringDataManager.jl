# EngineeringDataManager

[![Build Status](https://github.com/Manarom/EngineeringDataManager.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Manarom/EngineeringDataManager.jl/actions/workflows/CI.yml?query=branch%3Amain)

This package is designed to work with XML files in `MatML_doc` format (for example, material properties exported from `EngineeringData` in `ANSYS Mechanical` are in this format). A sample file is located in the project folder. The module `EngineeringDataManager` is used to load material properties, which automatically loads data from the material library (by default, this is the file [EngineeringData.xml](.//src//EngineeringData.xml)); 


# Quick start
```julia
    include(".//src//EngineeringDataManager.jl")
    EngineeringDataManager.read_engineering_data(xml_file_name) # by default  reads `EngineeringData.xml`
    # in source folder
    data = EngineeringDataManager.get_data(property_name = "Thermal Conductivity",
                            material_name = "Structural Steel",
                            format = "Tabular") # will return the content of data for "Thermal Conductivity"
                            # for "Structural Steel" in tabular format (Polynomial is also possible)

```

To start server on port 2000 call 

$ julia start_server.jl 2000 
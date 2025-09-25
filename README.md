# EngineeringDataManager

[![Build Status](https://github.com/Manarom/EngineeringDataManager.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Manarom/EngineeringDataManager.jl/actions/workflows/CI.yml?query=branch%3Amain)

This package is designed to work with XML files in `MatML_doc` format (for example, material properties exported from `EngineeringData` in `ANSYS Mechanical` are in this format). A sample file is located in the project folder. The module `EngineeringDataManager` is used to load material properties, which automatically loads data from the material library (by default, this is the file [EngineeringData.xml](.//src//EngineeringData.xml)); 

# Installation

Add package to the working environment 

```julia
import Pkg
Pkg.add("https://github.com/Manarom/EngineeringDataManager.jl.git")
```
# Quick start

## From julia

```julia
    using EngineeringDataManager # before `using`, the package must be added to the working environment 
    EngineeringDataManager.read_engineering_data(xml_file_name) # Loads all content of `xml_file_name` in memory
    # without input argument reads `EngineeringData.xml` in src folder
    data = EngineeringDataManager.get_data(property_name = "Thermal Conductivity",
                            material_name = "Structural Steel",
                            format = "Tabular") # will return the content of data for "Thermal Conductivity"
                            # for "Structural Steel" in tabular format (Polynomial is also possible)
    data.x # independent variable (e.g. temperature)
    data.y # dependent varible (property iself)
    data.xname # 
    data.yname # names
    data.type # data type
```

## As a server for external communication

`EngineeringDataManager.jl` also works as a server which can return properties to TCP/IP clients.

To start server on port 2000 from console.
```console
    $ julia start_server_script.jl 2000 
```
When calling from console the package loads [EngineeringData.xml](.//src//EngineeringData.xml) which is located in the source folder, thus this file should be replaced before starting the server. Or the the server from julia REPL:

```julia
    using EngineeringDataManager # before `using`, the package must be added to the working environment 
    EngineeringDataManager.start_server(port = 2000) # starts server on local host
```
In this case `EngineeringDataManager.read_engineering_data(xml_file_name)`  can be utilized to load another file.

After starting the server, data on material properties can be obtained by client through tcp/ip connection.
Interface of server communication using [matlab](.//src//matlab_interface//) and [python]( .//src//python_interface//)

Examples of function for reading data in [matlab](.//src//matlab_interface//get_property_from_server.m) 
and [python]( .//src//python_interface//get_property_from_server.py)

For instance, to read property data for the `density` of `Structural Steel` in a tabular form, 

In MATLAB command line:

``` MATLAB
    addpath('.//src//matlab_interface') %adds to path matlab interface folder  
    data = get_property_from_server("Density","Structural Steel","Tabular") % returns structure with properties
```




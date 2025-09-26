## EngineeringDataManager.jl

This package is designed to work with XML files in `MatML_doc` format (for example,  `ANSYS Mechanical` exports material properties (`EngineeringData`)  in this format). Currently the package allows one to read property data as a table or property polynomial approximation.

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
When calling from console the package loads the default xml-file which is located in the source folder, thus this file should be replaced before starting the server. Or the the server from julia REPL:

```julia
    using EngineeringDataManager # before `using`, the package must be added to the working environment 
    EngineeringDataManager.start_server(port = 2000) # starts server on local host
```
In this case `EngineeringDataManager.read_engineering_data(xml_file_name)`  can be utilized to load another file.

After starting the server, data on material properties can be obtained by client through tcp/ip connection.

Examples of function for reading data are with matlab (..//src//matlab_interface//) and python ( ..//src//python_interface//)

For instance, to read property data for the `density` of `Structural Steel` in a tabular form, in MATLAB command line:
``` MATLAB
    addpath('.//src//matlab_interface') % adds the  location of get_property_from_server function to the MATLAB path  
    data = get_property_from_server("Density","Structural Steel","Tabular") % returns struct with properties
```



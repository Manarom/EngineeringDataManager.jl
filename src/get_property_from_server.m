function get_property_from_server(property_name,material_name,format,port_number)
    arguments
        property_name 
        material_name
        format {mustBeMember(format,["Tabular","Polynomial"])}
        port_number {mustBeInteger,mustBePositive} =2000
    end

    %% establish connection
    tcp_client = tcpclient('127.0.0.1',port_number);
    a = struct("material",material_name,"property",property_name,"format",format)

end


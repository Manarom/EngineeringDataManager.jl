function data = get_property_from_server(property_name,material_name,format,port_number)
    % Function to collect data on property for the material  
    % Input args:
    % property_name  - property for the material_name, e.g. "Thermal Conductivity"
    % material_name  - material name in base like "Structural Steel"
    arguments
        property_name 
        material_name
        format {mustBeMember(format,["Tabular","Polynomial"])} = "Tabular"
        port_number {mustBeInteger,mustBePositive} =2000
    end

    %% establish connection
    try 
        tcp_client = tcpclient('127.0.0.1',port_number);
    catch err
        data = err;
        return 
    end
    on_clean = onCleanup(@()delete(tcp_client));
    a = struct("material",material_name,"property",property_name,"format",format);
    a_json = jsonencode(a);
    writeline(tcp_client,"request_property_data");writeline(tcp_client,a_json);
    pause(1e-2);
    response_json = readline(tcp_client);
    data = jsondecode(response_json);
    %delete(tcp_client); % closing connection after reseawing the response
end


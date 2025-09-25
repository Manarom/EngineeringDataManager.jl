function [is_ok, message] = start_engineering_data_server(port)
    arguments
        port {mustBeInteger} = 2000
    end
    is_ok = false;
    path = fileparts(mfilename('fullpath'));
    try
        jl.call('cd',path);
        jl.include('main.jl');
        pause(1e-1);
        [is_ok,message] = jl.call('EDM.start_server',port);
    catch err
        message = err;
        return 
    end
end
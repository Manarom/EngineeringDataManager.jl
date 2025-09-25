function  stop_engineering_data_server(port)
    arguments
        port {mustBeInteger} = 2000
    end
    try 
        tcp_client = tcpclient('127.0.0.1',port);
    catch err
        return 
    end
    on_clean = onCleanup(@()delete(tcp_client));
    writeline(tcp_client,"stop_server");
end
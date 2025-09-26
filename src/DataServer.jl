module DataServer
    include("TCPcommunication.jl")
    using .TCPcommunication # export start_server,tcp_server,try_write,try_readline,DEFAULT_PORT,read_with_timeout
    using ..DataManager
    using JSON3,Observables,Sockets
    # JSON3 package allows to read to the struct, this struct is to check this
    export start_server, COMMANDS_LIST
    # reference to the obj
    #const inst_state = Ref(InstrumentState())
    const json_string = Ref{JSON3.Object}()
    const SERVER = Ref{TCP_Server}()

    """
    request_port_names(serv::TCP_Server,sock::TCPSocket)

Returns all clients ports names
"""
function request_port_names(serv::TCP_Server,sock::TCPSocket)
        line =reduce(*,"  "*string(i[1]) for i in serv.clients_list)
        try_write(sock,line)
    end
    """
    stop_server(serv::TCP_Server,::TCPSocket)

Server shutting down 
"""
function stop_server(serv::TCP_Server,_)
        serv.shut_down_server=true
    end
    """
    request_property_data(::TCP_Server,socket::TCPSocket)

Client property request callback
"""
function request_property_data(::TCP_Server,socket::TCPSocket)
        try 
            str_out = JSON3.read(read_with_timeout(socket,30.0))     #readline(socket))
            JSON3.pretty(stdout,str_out)
            if !is_correct_property_request(str_out) 
                @info "Incorrect input json format"
                return false
            end
            material_name = getproperty(str_out ,:material)
            property_name = getproperty(str_out ,:property)
            data_format = getproperty(str_out ,:format)
            data_table = DataManager.get_data(property_name = property_name,
                                                        material_name = material_name,
                                                        format = data_format)
            json_string = JSON3.write(data_table)       
            return try_write(socket,json_string) 
        catch err1
            @show err1
            json_string = JSON3.write(err1) 
            return try_write(socket,json_string) 
        end
                                    
    end

    is_correct_property_request(json_obj) = hasproperty(json_obj,:property) && 
                                            hasproperty(json_obj,:material) && 
                                            hasproperty(json_obj,:format)

    const COMMANDS_LIST = Dict( "request_port_names" => request_port_names,
                        "stop_server" => stop_server,
                        "request_property_data" => request_property_data)

    @doc"""
    Dictionary associates tcp client request strings with internal functions, to add a new request - function
pair, one should write code for the callback function and include `request string => function` pair to this dictionary
Callback function must accept two arguments 
"""
COMMANDS_LIST                    
    """
    start_server(port)

Starts localhost server on specified port  
"""
start_server(port) = start_server(port = Int(port))
    """
    start_server(;port = DEFAULT_PORT)

Starts localhost server on specified port  
"""
function start_server(;port = DEFAULT_PORT)
        try
            s = TCPcommunication.start_server(port=port,commands = COMMANDS_LIST)
            SERVER[] = s
            return (true,"started")
        catch ex
            @show ex
            return (false,string(ex))
        end
        
    end
    """
    Module which runs a simple tcp/ip server to elaborate requests from external clients
Requests are configured in [`COMMANDS_LIST`] dictionary. First, client should send a string of
request (key of the `COMMANDS_LIST`), further is should conretize the request according to
the request callback specification.
"""
    DataServer
end
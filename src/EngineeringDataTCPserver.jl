

module EngineeringDataServer
    include("TCPcommunication.jl")
    #using .TCPcommunication
    # JSON3 package allows to read to the struct, this struct is to check this

    # reference to the obj
    #const inst_state = Ref(InstrumentState())
    const json_string = Ref{JSON3.Object}()
    const inst_state = Ref(InstrumentState())
    const new_data_collected = Observable(false)
    # callbacks
    function request_port_names(serv::tcp_server,sock::TCPSocket)
        line =reduce(*,"  "*string(i[1]) for i in serv.clients_list)
        try_write(sock,line)
    end
    function stop_server(serv::tcp_server,::TCPSocket)
        serv.shut_down_server=true
    end
    function read_json(::tcp_server,socket::TCPSocket)
        json_string[] = JSON3.read(readline(socket))
        JSON3.pretty(stdout,json_string[])
    end
    StructTypes.StructType(::Type{InstrumentState}) = StructTypes.Mutable()
    function read_instrument_state(::tcp_server,socket::TCPSocket)
        JSON3.read!(readline(socket), inst_state[])
        @show inst_state[]
        new_data_collected[]=true
    end
    const D = Dict("request_port_names"=>request_port_names,
    "stop_server"=>stop_server,
    "read_json"=>read_json,
    "read_instrument_state"=>read_instrument_state)
    function start_server()
        s = TCPcommunication.start_server(port=DEFAULT_PORT,commands = D)
    end
    
end
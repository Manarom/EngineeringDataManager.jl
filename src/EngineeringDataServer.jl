

module EngineeringDataServer
    include("TCPcommunication.jl")
    using .TCPcommunication
    using ..EngineeringDataManager
    using JSON3,Observables,Sockets
    # JSON3 package allows to read to the struct, this struct is to check this
    export start_server
    # reference to the obj
    #const inst_state = Ref(InstrumentState())
    const json_string = Ref{JSON3.Object}()
    const new_request_recieved = Observable(false)
    const SERVER = Ref{tcp_server}()
    # callbacks
    function request_port_names(serv::tcp_server,sock::TCPSocket)
        line =reduce(*,"  "*string(i[1]) for i in serv.clients_list)
        try_write(sock,line)
    end
    function stop_server(serv::tcp_server,::TCPSocket)
        serv.shut_down_server=true
    end
    function request_property_data(serv::tcp_server,socket::TCPSocket)
        try 
            str_out = JSON3.read(readline(socket))
            JSON3.pretty(stdout,str_out)
            if !is_correct_property_request(str_out) 
                @info "Incorrect input json format"
                return false
            end
            material_name = getproperty(str_out ,:material)
            property_name = getproperty(str_out ,:property)
            data_format = getproperty(str_out ,:format)
            data_table = EngineeringDataManager.get_data(property_name = property_name,
                                                        material_name = material_name,
                                                        format = data_format)
            json_string = JSON3.write(data_table)       
            return try_write(socket,json_string) 
        catch err1
            @show err1
            println("Incorrect json")
            json_string = JSON3.write(err1) 
            return try_write(socket,json_string) 
        end
                                    
    end
    function new_request_recieved_callback(val)
        val && isassigned(json_string) || return nothing
        json_obj = json_string[]
        if !is_correct_property_request(json_obj)
            @info "Incorrect property request json"
            return false
        end
    end
    is_correct_property_request(json_obj) = hasproperty(json_obj,:property) && 
                                            hasproperty(json_obj,:material) && 
                                            hasproperty(json_obj,:format)
    #StructTypes.StructType(::Type{InstrumentState}) = StructTypes.Mutable()
    const D = Dict("request_port_names"=>request_port_names,
                    "stop_server"=>stop_server,
                    "request_property_data"=>request_property_data)
    start_server(port) = start_server(port = Int(port))
    function start_server(;port = DEFAULT_PORT)
        try
            s = TCPcommunication.start_server(port=port,commands = D)
            SERVER[] = s
            return (true,"")
        catch ex
            @show ex
            return (false,string(ex))
        end
        
    end

end
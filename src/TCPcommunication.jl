# simple module to study the TCP communication
# after running this script is starts the servet at localhost (by default - on DEFAULT_PORT) 
module TCPcommunication
    const DEFAULT_PORT = 2000
    export start_server,tcp_server,try_write,try_readline,DEFAULT_PORT,read_with_timeout
    using Sockets
    const ForN   = Union{Function,Nothing} # function or nothing type for server starting function call
    Base.@kwdef mutable struct tcp_port
        # basic port object connects ip address and port in one structure
        ip::IPAddr=getaddrinfo("localhost", IPv4)
        port::Int=-1
    end
    # external constructor for the port 
    tcp_port(;port::Int,ip::AbstractString="localhost") = tcp_port(getaddrinfo(ip, IPv4),port) 

    # Thing common for both server and client
    Base.@kwdef mutable struct tcp_connection
        port::tcp_port # port properties
        on_connection::ForN # on client connection callback 
        commands::Dict{String,Function} # this dictionary stores special keywords to be called when message recieving
        on_reading::ForN # every reading callback
    end
    """
    Structure to store the server object
    fields:
                connection - tcp connection settings
                server - TCPserver object
                clients_streams - clients io Streams

    """
    Base.@kwdef mutable struct tcp_server
        connection::tcp_connection
        server::Sockets.TCPServer
        task::Task=Task([]) # @async task created right after port connection
        shut_down_server::Bool =false# flag to shut down the server
        clients_list::Dict{Int,TCPSocket}=Dict{Int,TCPSocket}()
        room_lock=ReentrantLock()
    end
    """
    tcp_server(connection::tcp_connection)

Creates server and starts listening
"""
function tcp_server(connection::tcp_connection)
        
        serv = tcp_server(connection=connection,
                            server=listen(connection.port.ip,connection.port.port)
        )
        serv.task=errormonitor(@async accept_client_loop(serv))
        @info "Server started listening" connection.port.ip connection.port.port
        return serv
    end
    """
    accept_client_loop(serv::tcp_server)


Main server loop
"""
    function accept_client_loop(serv::tcp_server)
        # new client connection
        while !serv.shut_down_server
            client = accept(serv.server)# accept function waits for  connection of  client returns TCPsocket
            peername = Sockets.getpeername(client) # returns clients ip and port address
            client_ip_address = peername[1]
            client_port_number = Int(peername[2])
            @info "Socket accepted" client_ip_address client_port_number
            add_client(serv,client)   
            errormonitor(@async client_message_handler(serv,client))
        end
        tcp_server_shutdown(serv)
    end
    # server shutting down function
    """
    tcp_server_shutdown(serv::tcp_server)

"""
function tcp_server_shutdown(serv::tcp_server)
        # remove all connections!
        list_of_clients = keys(serv.clients_list)
        for c in list_of_clients
            remove_client(serv,c)
        end
        close(serv.server) # should be replaced with shutting down task
    end
    """
    start_server(;port::Int,
        ip::String="localhost",
        on_connection::ForN=nothing,
        on_reading::ForN=nothing,
        commands::Dict{String,Function}=Dict{String,Function}())


Starts new server and returns its handle. Commands contains functions in dictionary, here 
key (String) is the special string which if read from a connected client invokes the value (Function)
This function must support two arguments, first is the server handle [`tcp_server`](@ref), the second is 
the client TCPSocket object.     
"""
    function start_server(;port::Int,
        ip::String="localhost",
        on_connection::ForN=nothing,
        on_reading::ForN=nothing,
        commands::Dict{String,Function}=Dict{String,Function}())
        port_obj = tcp_port(port=port,ip = ip) # creating tcp port object
        port_con=tcp_connection(port=port_obj,
                    on_connection=on_connection,
                    on_reading=on_reading,
                    commands=commands)    
        return tcp_server(port_con)
    end
#-------------------------------------
#=
EXAMPLE from HTTP package Servers module
    elseif reuseaddr
        if !supportsreuseaddr()
            @warn "reuseaddr=true not supported on this platform: $(Sys.KERNEL)"
            @goto fallback
        end
        server = Sockets.TCPServer(delay = false)
        rc = ccall(:jl_tcp_reuseport, Int32, (Ptr{Cvoid},), server.handle)
        if rc < 0
            close(server)
            @warn "reuseaddr=true failed; falling back to regular listen: $(Sys.KERNEL)"
            @goto fallback
        end
        Sockets.bind(server, addr.host, addr.port; reuseaddr=true)
        Sockets.listen(server; backlog=backlog)
=#
#-------------------------------------
        """
    Function to elaborate the client message (must be started as async task from the 
    main server  workflow after getting client socket through the accept function)

        """
    function client_message_handler(serv::tcp_server,socket::TCPSocket)
        # function to handle client message
        # tcp_server - object
        # socket - client connection 
        while !serv.shut_down_server && isopen(socket) && isreadable(socket)
            (is_ok, line) = try_readline(socket)
            if !is_ok
                break
            end
            @info "Client writes" Sockets.getpeername(socket)  line
            if haskey(serv.connection.commands,line)
                @info "Operation command recieved" line
                serv.connection.commands[line](serv,socket)
                continue
            end
            if !try_write(socket ,"server echoes "*line)
                break
            end 
        end
        port = findfirst(s->s==socket,serv.clients_list)
        if !isnothing(port)
            remove_client(serv,port)
            @info "Client closed" port socket.status
        end
        
    end
    function try_readline(socket)
        try
            return (true,readline(socket,keep=false))
        catch 
            return (false, "unable to read")
        end
    end
    """
    add_client(serv::tcp_server,client::TCPSocket)

Adds client to the servers client base
"""
    function add_client(serv::tcp_server,client::TCPSocket)
        (port,) = get_socket_port(client)
        lock(serv.room_lock) do # need to lock the client base
            serv.clients_list[port]=client
        end
        @info "client added to the clientbase with " port
    end
    """
    remove_client(serv,client::TCPSocket)

Removes client
"""
function remove_client(serv,client::TCPSocket)
        remove_client(serv,get_socket_port(client)[1])
    end
    function remove_client(serv::tcp_server,client_port::Int)
        
        if !haskey(serv.clients_list,client_port)
            return
        end
        lock(serv.room_lock) do # need to lock the client base
            client= pop!(serv.clients_list,client_port)
            if isopen(client) || !isreadable(client)
                close(client)
            end
        end
        @info "client removed from server clientbase " client_port
    end
    """
    Returns the tuple of integer  port number and ip address string

"""
    function get_socket_port(socket::TCPSocket)
        (socket_ip_address, socket_port_number)= Sockets.getpeername(socket) # returns clients ip and port address
         return (Int(socket_port_number),socket_ip_address)
    end
    
    function try_write(socket, message)
        try
            println(socket, message)
            return true
        catch error
            #@error error
            close(socket)
            return false
        end
    
        return true
    end
    """
    read_with_timeout(io::IO, timeout)

This function may be useful when one needs a response from the client to prevent
"""
function read_with_timeout(io::IO, timeout)
        channel = Channel{Union{String, Nothing}}(1)
        task =  @async put!(channel, try 
                                        readline(io) 
                                     catch; 
                                        nothing 
                                    end)
        timer = @async begin
            sleep(timeout)
            put!(channel, nothing)
        end
        result = take!(channel) # if nothing than there is an error in readline or timeout
        if result === nothing
            throw(TimeoutException("Readline timed out after $timeout seconds"))
            Base.throwto(task, InterruptException())
        else
            # Base.throwto(timer, InterruptException())
            return result
        end
    end
    struct TimeoutException <: Exception
        msg::String
    end
end

#server = Sockets.TCPServer(delay = false)
#server.handle

#rc = ccall(:jl_tcp_reuseport, Int32, (Ptr{Cvoid},), server.handle)
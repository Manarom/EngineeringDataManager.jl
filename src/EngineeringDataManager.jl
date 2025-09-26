module EngineeringDataManager
    export main
    include("DataManager.jl")
    include("DataServer.jl")
    using .DataManager
    using .DataServer
    export read_engineering_data, get_data

    """
    (@main)(args)

Module entry point to start the material server 
"""
(@main)(args) = begin
        length(args) > 0 || return 1
        port = Base.parse(Int,args[1])
        (is_ok, message) = start_server(port)
        sleep(1e-2)
        isassigned(DataServer.SERVER) || return -1
        println(DataServer.SERVER[].connection.port.ip)
        println("Press Enter to exit...")
        readline()
        return 1
    end
end
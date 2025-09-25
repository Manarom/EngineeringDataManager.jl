module EDM
    export main
    const _dir = @__DIR__
    include(joinpath(_dir,"EngineeringDataManager.jl"))
    include(joinpath(_dir,"EngineeringDataServer.jl"))
    using .EngineeringDataServer
    (@main)(args) = begin
        length(args) > 0 || return 1
        port = Base.parse(Int,args[1])
        (is_ok, message) = start_server(port)
        sleep(1e-2)
        isassigned(EngineeringDataServer.SERVER) || return -1
        println(EngineeringDataServer.SERVER[].connection.port.ip)
        println("Press Enter to exit...")
        readline()
        return 1
    end

end
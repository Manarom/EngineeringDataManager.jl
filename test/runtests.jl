using EngineeringDataManager
using Test,Sockets,JSON3

pwd()
@testset "matchers_tests" begin
    
    for m_i in EngineeringDataManager.DataManager.all_materials_names()
        for p_i in EngineeringDataManager.DataManager.all_properties_names()
            print("property $(p_i) for material $(m_i) : ")
            try
                data = EngineeringDataManager.get_data(property_name = p_i,material_name = m_i,format = "Tabular")
                if isa(data,NamedTuple)
                    println(string(data))
                else
                    println(" does not exist")
                end
                @test true
            catch err
                @show err
                @test false
            end
        end
    end

    data = EngineeringDataManager.get_data(property_name = "Specific Heat",material_name = "BAFS",format = "Tabular")
    @test all(data.x .== Float64.([20,50,100,150,200,250,300,350,400,450,500,550,600,700,800]))
    @test all(data.y .== Float64.([700,730,800,870,920,965,1000,1028,1050,1067,1080,1087,1090,1090,1090]))
    @test data.yname == "Specific Heat"
    @test data.xname == "Temperature"
    # imitation client-server communication
    try
        port = rand(2000:1:3000) # random port number generation to prevent port reuse errors on subsequent calls
        @show port
        EngineeringDataManager.start_server(port)
        sleep(1e-1)
        client = connect(port)
        sleep(1e-1)
        println(client,"request_property_data")
        sleep(1e-1)
        println(client, JSON3.write((material = "BAFS",property = "Specific Heat", format = "Tabular")))
        sleep(1e-1)
        json_str = EngineeringDataManager.DataServer.read_with_timeout(client,0.2)
        sleep(1e-1)
        println(client,"stop_server")
        sleep(1e-1)
        data = JSON3.read(json_str)
        @test all(Float64.(data.x) .== Float64.([20,50,100,150,200,250,300,350,400,450,500,550,600,700,800]))
        @test all( Float64.(data.y) .== Float64.([700,730,800,870,920,965,1000,1028,1050,1067,1080,1087,1090,1090,1090]))
    catch err
        @show err
        @test false
        EngineeringDataManager.DataServer.stop_server(EngineeringDataManager.DataServer.SERVER[],nothing)
        sleep(1e-1)
    end

end
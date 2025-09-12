module EngineeringDataManager
    using XML,Sockets,OrderedCollections #,StructTypes,Observables,

    include("XMLwalker.jl")
    using .XMLwalker

    const SymbolOrNothing = Union{Symbol,Nothing}
    const ENG_DATA_FILE = Ref(".\\src\\EngineeringData.xml")
    const XML_DOC =  begin 
                            out = Ref{Node}()
                            try    
                                out[] =  XML.read(ENG_DATA_FILE[],Node)
                            catch Exc
                                @show Exc
                                println("Unable to read default file $(ENG_DATA_FILE[])")
                            end 
                            out
                    end
    const StringFloat = Union{String,Float64}
    const ParamIDs = Ref(OrderedDict{String,StringFloat}())
    const ParamNames = Ref(OrderedDict{StringFloat,String}())
    is_xml_ok() = @assert isassigned(XML_DOC) "No document file assigned, use `read_engineering_data` function to assign the file"
    function read_engineering_data(;file_fullname::String = ENG_DATA_FILE[])
        try    
            XML_DOC[] =  XML.read(file_fullname,Node)
            return true
        catch Exc
            @show Exc
            println("Unable to read default file $(file_fullname)")
            return false
        end 
    end

    function material_nodes(;material_name = "")
        is_xml_ok()
        names = Vector{String}();
        material_nodes_vect = find_nodes("Material")
        !isempty(material_nodes_vect) || return names
        for mi in material_nodes_vect
            name_node = find_nodes_chain(mi,"Material/BulkDetails/Name")
            !isempty(name_node) || continue
            @assert length(name_node) == 1 "Names node vector has multiple elements ???"
            has_single_child(name_node[]) || continue
            nd_cur = name_node[].children[]
            if !isnothing(nd_cur.value) && isa(nd_cur.value,String)
                push!(names,nd_cur.value)
            end
        end
        return (names,material_nodes_vect)
    end
    function fill_parameters_ids()
        meta_data_node = find_nodes("Metadata")
        D = ParamIDs[]
        D2 = ParamNames[]
        empty!(D)
        !isempty(meta_data_node) || return false
        param_details = find_nodes(meta_data_node[],"ParameterDetails")
        for p_i in param_details
            !isnothing(p_i.attributes) || continue
            haskey(p_i.attributes,"id") || continue
            current_key = p_i.attributes["id"]
            name_node = find_nodes_chain(p_i,"ParameterDetails/Name")
            has_single_element(name_node) || continue
            has_single_child(name_node[]) || continue
            # end_node_type = nodetype(name_node[].children[])
            value  = name_node[].children[].value
            push!(D, current_key => value)
            push!(D2,value => current_key )
        end
    end
    has_single_child(node) =  !isnothing(node.children) && length(node.children) == 1
    has_single_element(node_vect) = isa(node_vect,AbstractVector) && length(node_vect) == 1

    #=function find_nodes(tag::String="EngineeringData", field_type::SymbolOrNothing=:tag) 
        is_xml_ok()
        find_nodes(XML_DOC[],MatchesPat(tag,field_type))
    end=#
    #find_nodes(starting_node,tag::String,field_type::SymbolOrNothing=:tag) = find_nodes(starting_node,MatchesPat(tag,field_type))

end # module end
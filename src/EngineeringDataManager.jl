module EngineeringDataManager
    using XML,Sockets,OrderedCollections #,StructTypes,Observables,
    using XMLWalker
    const SymbolOrNothing = Union{Symbol,Nothing}
    const ENG_DATA_FILE = Ref(joinpath(@__DIR__, "EngineeringData.xml"))
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
    """
    Dictionary to store parameters id => name pairs
    IDS[]["param_id"] returns parameter name
"""
    const IDS = Ref(OrderedDict{String,StringFloat}())
    const NAMES = Ref(OrderedDict{StringFloat,Vector{StringFloat}}())
    #const PROP_IDS = Ref(OrderedDict{String,StringFloat}())
    const MATERIALS_NODES = Ref(OrderedDict{String,Node}())
    is_xml_ok() = @assert isassigned(XML_DOC) "No document file assigned, use `read_engineering_data` function to assign the file"
    function read_engineering_data(;file_fullname::String = ENG_DATA_FILE[])
        try    
            XML_DOC[] =  XML.read(file_fullname,Node)
            fill_materials_nodes()
            fill_ids()
            return true
        catch Exc
            @show Exc
            println("Unable to read default file $(file_fullname)")
            return false
        end 
    end
    function get_root_node()
        (isassigned(XML_DOC) && !isempty(XML_DOC)) || read_engineering_data()
        return XML_DOC[]
    end
    """
    material_nodes(;material_name::String = "")

Returns a tuple of two vectors, first - materials names, second one - nodes for material `material_name`, if `material_name = ""` returns 
nodes for all materials
"""
function material_nodes(;material_name::String = "")
        is_xml_ok()
        names = Vector{String}()
        material_nodes_vect = find_nodes(XML_DOC[],"Material")
        !isempty(material_nodes_vect) || return names
        is_single_material = !isempty(material_name)
        for mi in material_nodes_vect
            name_node = find_nodes(mi,"Material/BulkDetails/Name")
            !isempty(name_node) || continue
            @assert length(name_node) == 1 "Names node vector has multiple elements ???"
            has_single_child(name_node[]) || continue
            nd_cur = name_node[].children[]
            if !isnothing(nd_cur.value) && isa(nd_cur.value,String)
                if is_single_material 
                    if nd_cur.value == material_name
                        return ([material_name],[mi])
                    else
                        continue 
                    end
                end
                push!(names,nd_cur.value)
            end
        end
        return (names , material_nodes_vect)
    end
    """
    fill_materials_nodes()

Fills materials nodes dictionary
"""
function fill_materials_nodes()
        (names,material_nodes_vect) = material_nodes()
        mnd = MATERIALS_NODES[]
        for (n,v) in zip(names,material_nodes_vect)
            push!(mnd,n => v)
        end
    end
    function all_materials()
        !isempty(MATERIALS_NODES[]) || fill_materials_nodes()
        return keys(MATERIALS_NODES[])
    end
    function all_names()
        !isempty(NAMES[]) || fill_ids()
        return keys(NAMES[])
    end
    function all_ids()
        !isempty(IDS[]) || fill_ids()
        return keys(IDS[])
    end
    all_parameters_ids() = filter(k->contains(k,"pa") , all_ids())
    all_properties_ids() = filter(k->contains(k,"pr") , all_ids())
    all_properties_names() = [IDS[][p] for p in all_properties_ids()]

    
    """
    fill_ids()

Fills `ID` => `name` dictionary IDS[] and NAMES[] dictionary for `name` => `ID`
Name can contain several ids thus NAMES[] dictionary elements are the vectors of strings

"""
function fill_ids()
        meta_data_node = find_nodes(XML_DOC[],"Metadata")
        D_ids = IDS[]
        D_names = NAMES[]
        empty!(D_ids)
        empty!(D_names)
        !isempty(meta_data_node) || return false
        p_details = find_nodes(meta_data_node[],"ParameterDetails")
        append!(p_details, find_nodes(meta_data_node[],"PropertyDetails"))
        for p_i in p_details
            !isnothing(p_i.attributes) || continue
            haskey(p_i.attributes,"id") || continue
            current_key = p_i.attributes["id"]
            name_node = find_nodes(p_i,"*/Name")
            value  = name_node[].children[].value
            push!(D_ids, current_key => value)
            name_exist = haskey(D_names, value)
            name_exist ? push!(D_names[value],current_key) : push!(D_names,value => [current_key])
        end
    end
    has_single_child(node) =  !isnothing(node.children) && length(node.children) == 1
    has_single_element(node_vect) = isa(node_vect,AbstractVector) && length(node_vect) == 1

    """
    get_property_node(property_id_or_name,material_name::Union{String,Nothing}=nothing)

Returns node of property by ID or by its name, for material `material_name` or for all
materials if nothing
"""
function get_property_node(property_id_or_name::String,material_name::String)
        (_ , material_node) = get_material_node(material_name) 
        prop_id = get_prop_id_by_prop_name(property_id_or_name)
        return search_by_id(material_node, prop_id)
    end
    """
    get_prop_id_by_prop_name(property_name)

As far as NAMES dictionary stores both properties and parameters associated to the property name,
this function is used to get property id `pr*` from the property name (otherwise it returns error)
"""
function get_prop_id_by_prop_name(property_name)
        D_ids = IDS[]
        D_names = NAMES[]
        (!isempty(D_ids) && !isempty(D_names)) || fill_ids()
        is_by_id = haskey(D_ids,property_name)
        is_by_name = haskey(D_names,property_name)
        if is_by_id 
            !contains(property_name,"pr") ? error("Wrong property $(property_name)") : return property_name 
        elseif !is_by_name
            error("Wrong property  `$(property_name)` value must be a member of $(join(all_properties_names(),','))")
        end
        for v in D_names[property_name]
            !contains(v,"pr") || return v
        end
        return first(D_names[property_name])
    end
    """
    search_by_id(starting_node,id::String)

Returns nodes vector by parameter ID
"""
function search_by_id(starting_node,id::String)
        (type_string ,  keystr) =  contains(id,"pa") ? ("ParameterValue" , "parameter") : ("PropertyData","property")
        search_string = "$type_string.attributes([ $keystr = $id ])"
        return find_nodes(starting_node,search_string)
    end
    """
    search_by_id(starting_node,id::AbstractVector)

Returns property nodes vector by IDs of parameters
"""
function search_by_id(starting_node,id::AbstractVector)
        nodes = Vector{Node}()
        for i in id
            append!(nodes,search_by_id(starting_node,i))
        end
        return nodes
    end
    """
    get_material_node(material_name)

Material node by name, returns Tuple (material_name,material_node)
"""
function get_material_node(material_name)
        !isempty(MATERIALS_NODES[]) || fill_materials_nodes()
        haskey(MATERIALS_NODES[],material_name) || error("Unknown material $(material_name)")
        return (material_name, MATERIALS_NODES[][material_name])
    end
abstract type  AbstractNodeWrapper end
struct ParameterValueNode <: AbstractNodeWrapper
    node
    ParameterValueNode(node) = is_parameter_value_node(node) ? new(node) : error("This node type is not correct")
end
struct PropertyDataNode <: AbstractNodeWrapper
    node
    PropertyDataNode(node) = is_property_data_node(node) ?  new(node) : error("This node type is not correct")
end
struct SomeNode <: AbstractNodeWrapper
    node
end
    """
    is_property_data(node)

Checks if the node can be wrapped to PropertyData data type

"""
is_property_data_node(node) = hasproperty(node,:tag) && !isnothing(node.tag) && node.tag == "PropertyData"
is_parameter_value_node(node) = hasproperty(node,:tag) && !isnothing(node.tag) && node.tag == "ParameterValue"
function wrap_node(node)
    is_property_data_node(node) || return PropertyData(node)
    is_parameter_value_node(node) || return ParameterValue(node)
    return SomeNode(Node)
end
    """
    get_node_data(w_node::ParameterValueNode)

Returns nodes data field content for a single node of ParameterValueNode type

Returns named tuple:
    (name = param_name,  - the name of the parameter 
    id = id,  - paramater/property id
    data = data, - data (parsed to vector)
    qualifier = qual - qualifier 
    )

"""
function get_node_data(w_node::ParameterValueNode)
        format  = w_node.node.attributes["format"]
        id  =  w_node.node.attributes["parameter"]
        dat_node =find_nodes(w_node.node,"*/Data")[]
        qual = get_all_qualifiers(w_node)
        data_val = get_root_node_value(dat_node) # data value as a string
        data = convert_data_vector(data_val,format)
        param_name = get(IDS[],id,"unknown")
        return ParameterValueContent(name = param_name, id = id, data = data, qualifiers = qual)
    end

function get_node_data(w_node::PropertyDataNode)
    
    id  =  w_node.node.attributes["property"]
    dat_node =find_nodes(w_node.node,"*/Data")[]
    format  = dat_node.attributes["format"]


    qual = get_all_qualifiers(w_node)
    data_val = get_root_node_value(dat_node) # data value as a string
    data = convert_data_vector(data_val,format)

    property_name = get(IDS[],id,"unknown")
    property_data = PropertyDataContent(name = property_name,id=id,
                                            data=data,qualifiers=qual,
                                            parameters=Vector{ParameterValueContent}())

    param_subnodes_vector = find_nodes(w_node.node,"*/ParameterValue")
    !isempty(param_subnodes_vector) || return property_data

    for par_i in param_subnodes_vector
        ith_data = get_node_data(ParameterValueNode(par_i))
        push!(property_data.parameters,ith_data)
    end
    return property_data
end

@kwdef struct ParameterValueContent
    name::String
    id::String
    data::Union{Vector{String},Vector{Float64},String}
    qualifiers::OrderedDict{String,String}
end
@kwdef struct PropertyDataContent
    name::String
    id::String
    data::Union{Vector{String},Vector{Float64},String}
    qualifiers::OrderedDict{String,String}
    parameters::Vector{ParameterValueContent}
end
    """
    get_all_qualifiers(w_node::Union{ParameterValueNode,PropertyDataNode})

Gets all qualifiers from the node and puts them to the OrderedDict with qualifier name as a 
key and qualifier string as a value.
"""
function get_all_qualifiers(w_node::Union{ParameterValueNode,PropertyDataNode})
        out_dict = OrderedDict{String,String}()
        for (i,qual) in enumerate(find_nodes(w_node.node,"*/Qualifier"))
            !isnothing(qual.attributes) || continue
            cur_name = get(qual.attributes,"name","name_$(i)")
            push!(out_dict, cur_name => get_root_node_value(qual))
        end
        return out_dict
    end
    function get_root_node_value(node::Node)
        return node.children[].value
    end

    function convert_data_vector(data::AbstractString,format::AbstractString="")
        if contains(format,"float") || contains(format,"double") || contains(format,"Float")
            return  [Base.Fix1(Base.parse,Float64)(strstr(s)) for s in  eachsplit(data,",")]
        else
            return  [strstr(s) for s in  eachsplit(data,",")]
        end
    end
    strstr(s::AbstractString) = ( string ∘ strip)(s)

    function get_property_data(;property_name,material_name)
        prop_node = get_property_node(property_name , material_name)[]
        wrapped_prop_node = PropertyDataNode(prop_node)
        return get_node_data(wrapped_prop_node)
    end
    function get_dependent_parameter_data(pdc::PropertyDataContent)
        for p_i in pdc.parameters
            !is_dependent_variable(p_i) || return (p_i.name, p_i.data)
        end
        return nothing
    end
    function get_independent_parameter_data(pdc::PropertyDataContent)
        for p_i in pdc.parameters
            !is_independent_variable(p_i) || return (p_i.name, p_i.data)
        end
        return nothing
    end
    function get_optional_variable(pdc::PropertyDataContent)
        for p_i in pdc.parameters
            !is_independent_variable(p_i) || return (p_i.name, p_i.data)
        end
        return nothing
    end
    is_dependent_variable(par::ParameterValueContent) = haskey(par.qualifiers,"Variable Type") && all(s-> strstr(s) == "Dependent"   ,eachsplit(par.qualifiers["Variable Type"],","))
    is_independent_variable(par::ParameterValueContent) = haskey(par.qualifiers,"Variable Type") && all(s-> strstr(s) == "Independent"   ,eachsplit(par.qualifiers["Variable Type"],","))
    is_optional_variable(par::ParameterValueContent) = par.name == "Options Variable"

end # module end
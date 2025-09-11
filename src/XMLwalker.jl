module XMLwalker
    using OrderedCollections,InteractiveUtils

    const SymbolOrNothing = Union{Symbol,Nothing}
    const VectOrSymbolOrNothing = Union{Symbol,Nothing,Vector{SymbolOrNothing}}
    const PatterTypeUnion = Union{String,OrderedDict,Float64}
    const TOKENS_SEPARATOR = "/"

    export find_nodes, find_nodes_chain
    
    abstract type AbstractMatcher{T,P} end

    include("StringUtils.jl")
    is_matched(pat::AbstractPattern,s::AbstractString) = !isnothing(match(pat,s))
    internal_isequal(a,b) = isequal(a,b)
    internal_isequal(a::AbstractPattern,b::AbstractString) = is_matched(a,b)
    internal_isequal(a::AbstractString,b::AbstractPattern) = is_matched(b,a)


    internal_contains(collection,b) = contains(collection,b) 
    internal_contains(a::AbstractPattern, b) = any(bi->internal_isequal(a,bi),b)
    internal_contains(::Nothing,b) = false
    internal_contains(collection,::Nothing) = false
    swap_contains(a,b) = internal_contains(b,a)



    always_true(_,_) = true
    haskey_swapped(k,D) = haskey(D,k)
    internal_in(k,itr) = in(k,itr)
    internal_in(a::AbstractString,b::AbstractString) = internal_isequal(a,b)
    internal_in(pat::AbstractPattern,s::AbstractString) = internal_isequal(pat,s) 
    internal_in(pat::AbstractString ,s::AbstractPattern) = internal_isequal(pat,s) 
    function internal_in(pat::AbstractPattern,itr) 
        for i_i in itr 
            !is_matched(pat,i_i) || return true
        end
        return false
    end
    function internal_in(pat::AbstractPattern,itr::AbstractDict) 
        for i_i in keys(itr) 
            !is_matched(pat,i_i) || return true
        end
        return false
    end
    function internal_in(pat::AbstractString,itr::Vector{Regex}) 
        for p_i in itr 
            !is_matched(p_i,pat) || return true
        end
        return false
    end
    function internal_in(pat::Pair,itr::Vector{Regex}) 
        for p_i in itr[1] 
            !is_matched(p_i,pat) || return true
        end
        return false
    end
    # IN ALL FUNCTIONS THE FIRST ARGUMENT IS PATTERN THE SECOND ARGUMENTS IS THE NODE CONTENT OR INPUT ITSELF
    # contains(a,b) search for 
    # MatchesPat -   true if pattern is totally matched
    # PatContains -  true if the pattern contains the input contains(pat,input) = true
    # ContainsPat  - true if the input contains the pattern contains(inout,pat) = true
    # HasAnyKeyPat - true if the input has at least element of pat as a key
    # HasAllKeysPat - true if the inout has all elements of pat as keys
    # ContainsAnyPat - true if tag contains any of patterns

    _itp = NamedTuple{(:fun,:internal,:consumer)}
    for (matcher_type,d) in (:MatchesPat  => _itp((:matches_pat,:internal_isequal,:all)),
                            :PatContains =>  _itp((:pat_contains,:internal_contains,:all)),
                            :ContainsPat => _itp((:contains_pat,:swap_contains,:all)),
                            :ContainsAnyPat => _itp((:contains_any_pat,:internal_contains,:any)),
                            :ContainsAllPats => _itp((:contains_all_pats,:internal_contains,:all)),
                            :HasAnyKeyPat => _itp((:has_any_key_pat,:haskey_swapped,:any)),
                            :HasAllKeysPat => _itp((:has_all_key_pat,:haskey_swapped,:all)),
                            :AnyPat => _itp((:any_pat, :always_true,:any)))

        @eval struct $matcher_type{T,P} <: AbstractMatcher{T,P}
            pat::P
            $matcher_type(s::P,type::SymbolOrNothing=nothing) where P =  new{type,P}(s)
        end
        @eval $(d.fun)(pat::P,input,::Nothing) where P <: Union{AbstractPattern,AbstractString,Number} =  $(d.internal)(pat,input)
        @eval $(d.fun)(pat::P,input,T::Symbol) where P <: Union{AbstractPattern, AbstractString,Number} = hasproperty(input,T) && $(d.internal)(pat,getproperty(input,T))
        @eval (tag::$matcher_type{T})(input) where T = $(d.fun)(tag.pat,input,T)
        (iterate_over, look_in, in_checker) = if matcher_type == :PatContains
                                                    (:_input, :pat, :internal_in) 
                                                elseif matcher_type == :AnyPat
                                                    (:pat, :pat, :internal_in)  
                                                elseif (matcher_type == :HasAnyKeyPat) || (matcher_type == :HasAllKeysPat)
                                                    (:pat, :_input, :haskey_swapped)   
                                                else 
                                                    (:pat, :_input, :internal_in)
                                                end
        # when ierating over the collection iterate_over is the collection which members we are looking in look_in    
        @eval function $(d.fun)(pat::P,input,T) where  P <: Union{AbstractVector,AbstractDict,NTuple}
            if !isnothing(T)
                hasproperty(input,T) || return false
                _input = getfield(input,T) 
                !isnothing(_input) || return false
            else
                _input  = input
            end
            if isa($iterate_over,AbstractString) # string iterates over chars 
                return $in_checker($iterate_over,$look_in)
            else
                return $(d.consumer)(si-> $in_checker(si,$look_in) ,$iterate_over)
            end
        end
    end

    struct MatchersSet{T,P} <: AbstractMatcher{T,P} # 
        matchers::P
        MatchersSet(matchers_collection::P,type::Symbol) where P = begin
            @assert in(type,(:any,:all))
            return new{type,P}(matchers_collection)
        end
        MatchersSet(type::Symbol) = begin
            matchers_collection = Vector{AllTagMatchersUnion}()
            return MatchersSet(matchers_collection,type)
        end
    end
    Base.push!(ms::MatchersSet,v::AbstractMatcher) = Base.push!(ms.matchers,v)

    function any_matchers(matchers_collection,node)
        for m in matchers_collection
            !m(node) || return true
        end
        return false
    end

    function all_matchers(matchers_collection,node)
        for m in matchers_collection
            m(node) || return false
        end
        return true
    end
    (m::MatchersSet{:any})(node) = any_matchers(m.matchers,node)
    (m::MatchersSet{:all})(node) = all_matchers(m.matchers,node)


    const AllTagMatchersUnion = Union{subtypes(AbstractMatcher)...}

    """ Object to match patterns in inputs and input structures fields
        
    matcher  = MatchesPat(pat,field_name::Union{Symbol,Nothing}=nothing);

    matcher(input):
    Returns true if `pat` is matched to the `input`
    object field `field_name` if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    MatchesPat 
    """
        matcher  = PatContains(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) - true if  `pat` contains the `input.field_name` if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    PatContains 
    """
        matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) true if the `input.field_name` contains the pattern 
    if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    ContainsPat 
    """
        matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) - true if the` input.field_name` has at least one element of `pat` as a key
    if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    HasAnyKeyPat 
    """
        matcher  = ContainsPat(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) - true if the `input.field_name` has all elements of `pat` as keys
    if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    HasAllKeysPat 
    """
    matcher  = ContainsAnyPat(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) - true if `input.field_name` contains any of pat elements 
    if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    ContainsAnyPat
    """
    matcher  = ContainsAllPats(pat,field_name::Union{Symbol,Nothing}=nothing);
    matcher(input) - true if `input.field_name` contains all of pat elements 
    if `field_name` is `nothing` than `input` itself is matched.
    The syntax is the same for all other matchers, see [`AllTagMatchersUnion`](@ref) = $(AllTagMatchersUnion)
    for the list of matchers types"""
    ContainsAllPats
    # to utils

    struct ChainMatcher
        pat_vect::Vector{AllTagMatchersUnion}
        state::Int
        ChainMatcher(pat_string::String,field_types::VectOrSymbolOrNothing=nothing) = begin
            pat_vect = chain_string_to_matchers(pat_string, field_types)
            new(pat_vect,1)
        end
    end
    Base.iterate(t::ChainMatcher) = iterate(t.pat_vect);
    Base.iterate(t::ChainMatcher,state) = iterate(t.pat_vect,state);
    function chain_string_to_matchers(s::AbstractString,root_field_name::SymbolOrNothing=:tag)
        tag_vect = Vector{AllTagMatchersUnion}()
        counter = 0
        for si in eachsplit(s,TOKENS_SEPARATOR)
            counter +=1
            push!(tag_vect,chain_string_token_to_matcher(strstr(si),root_field_name))
        end
        return tag_vect
    end
    function field_string_to_matcher(s::AbstractString)
        #@show s
        if has_round(s) # field_name(....) syntax for checking the arguments
            field_name = Symbol(extract_before(s,"("))
            args = extract_embraced_round(s)
            is_embraced(args) || error("set of keys must be embraced in {...} or [...]")
            is_only_keys = !has_equal(args) # field has keys but not key-value pairs
            is_contains_regex = has_regex(args) # check if arguments string contains ::regex
            if is_embraced_curl(args)
                #args = extract_embraced_round(s) # extracting specified field arguments
                args_vect = extract_embraced_args_curl(args)
                return (is_only_keys && !is_contains_regex) ? HasAllKeysPat(args_vect,field_name) : ContainsAllPats(args_vect,field_name)
            elseif is_embraced_square(args)
                args_vect = extract_embraced_args_square(args)
                return (is_only_keys && !is_contains_regex) ? HasAnyKeyPat(args_vect,field_name) : ContainsAnyPat(args_vect,field_name)
            else
                error("Unsupported field_name = $(field_name) and arguments = $(args)")
            end
        elseif has_equal(s)
            (field_name_string,value) = split_equality(s) # parses as key-value pair
            # @show (field_name_string,value)
            length(value) > 0 || error("Incorrect string format $(s)")
            field_name = Symbol(field_name_string)
            try_parse = tryparse(Float64,value)
            isnothing(try_parse) || return simple_string_or_number_to_matcher(try_parse,field_name)
            if !is_embraced_curl(value) && !is_embraced_square(value) # simple argument has equalities but no round or squares
                return simple_string_or_number_to_matcher(value,field_name)
            else # embraced!!! thus it is a collection of key-value pairs
                #@show value
                if is_embraced_curl(value)
                    matchers_set = MatchersSet(:all)
                    values_vect = extract_embraced_args_curl(value)
                else
                    matchers_set = MatchersSet(:any)
                    values_vect = extract_embraced_args_square(value)
                end
                for vi in values_vect
                    push!(matchers_set, simple_string_or_number_to_matcher(vi,field_name))
                end
                return matchers_set
            end
        else
            error("Incorrect string format $(s)")
        end
    end
    function simple_string_or_number_to_matcher(value::AbstractString,field_name::SymbolOrNothing=:tag)
        if has_regex(value) 
            value_str = remove_regex(value)
            return  MatchesPat(Regex(value_str),field_name) 
        elseif !has_asterisk(value) 
            return MatchesPat(value,field_name)
        elseif has_asterisk(value)
            value != "*" || return AnyPat(value,field_name)
            value = replace(value,"*"=>"")
            return ContainsPat(value,field_name) 
        else
            error("Unsupported string $(value)")
        end
    end
    simple_string_or_number_to_matcher(value::Number,field_name::Symbol=:tag) = MatchesPat(value,field_name)
    """
        chain_string_token_to_matcher(s::String)

    Function to convert single expression into the matcher object
    """
    function chain_string_token_to_matcher(s::String,field_name::SymbolOrNothing=:tag)
        if is_simple_pattern(s) 
            return simple_string_or_number_to_matcher(s,field_name)
        elseif !has_nondigit_dot(s) && is_embraced_square(s)
            si_patt = extract_embraced_args_square(s)
            length(si_patt) > 0 || error("Incorrect syntax $(s)")
            any(x->isa(x,Number),si_patt) || return ContainsAnyPat(si_patt,field_name)
            return ContainsAnyPat(string.(si_patt),field_name)
        elseif has_nondigit_dot(s)
            splitted = split_tag_and_field_name(s)
            tag_matcher = chain_string_token_to_matcher(splitted[1],:tag)
            field_matcher = field_string_to_matcher(splitted[2])
            return MatchersSet((tag_matcher,field_matcher),:all)
        else
            return MatchesPat(s,field_name)
        end
    end

    # nodes searching functions
    function find_nodes!(node_vector::Vector{T},node::T,matcher::AbstractMatcher) where T
        !matcher(node) || push!(node_vector,node)
        !isnothing(getfield(node,:children)) || return node_vector
        for ndi in getfield(node,:children)
            find_nodes!(node_vector,ndi,matcher)
        end
        return node_vector
    end
    function find_nodes(starting_node,search_string::AbstractString,field_name::SymbolOrNothing=:tag)
        return find_nodes(starting_node,chain_string_token_to_matcher(search_string,field_name))
    end
    function find_nodes(starting_node::T,matcher::AbstractMatcher) where T
        node_vector = Vector{T}()
        find_nodes!(node_vector,starting_node,matcher)
        return node_vector
    end
    function find_nodes_chain(starting_node::T,xml_chain_string::String) where T
        node_vector = Vector{T}()
        return find_nodes_chain!(node_vector,starting_node,ChainMatcher(xml_chain_string))
    end
    function find_nodes_chain!(node_vector::Vector{T},node::T,tag_chain::ChainMatcher,state::Int=1,first_node::Bool=true) where T
        (matcher,next_state) = iterate(tag_chain,state)
        has_next_state = !isnothing(iterate(tag_chain,next_state))
        if matcher(node) 
            if !has_next_state
                push!(node_vector,node)
                !first_node || return node_vector
            end
        elseif first_node
            return node_vector
        end
        !isnothing(node.children) || return node_vector
        for ndi in node.children
            isa(ndi,T) || continue
            find_nodes_chain!(node_vector,ndi,tag_chain,next_state)
        end
        return node_vector
    end
end
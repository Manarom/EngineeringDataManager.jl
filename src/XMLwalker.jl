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
    is_matched(pat::AbstractString,s::AbstractPattern) = !isnothing(match(s,pat))
    is_matched(pat) = Base.Fix1(is_matched,pat)

    internal_isequal(a,b) = isequal(a,b)
    internal_isequal(a::AbstractPattern,b::AbstractString) = is_matched(a,b)
    internal_isequal(a::AbstractString,b::AbstractPattern) = is_matched(b,a)
    internal_isequal(a::Pair,b::AbstractPattern) = isa(a[1],AbstractString) && is_matched(b,a[1])
    internal_isequal(b::AbstractPattern,a::Pair) = isa(a[1],AbstractString) && is_matched(b,a[1])
    internal_isequal(pat) = Base.Fix1(internal_isequal,pat)

    internal_contains(collection,pattern) = contains(collection,pattern) 
    internal_contains(collection, a::AbstractPattern) = any(bi->internal_isequal(a,bi),collection)
    internal_contains(collection::AbstractString, pattern::AbstractPattern) = is_matched(collection,pattern)
    internal_contains(collection::AbstractPattern , pattern::AbstractString) = is_matched(collection,pattern)

    internal_contains(::Nothing,b) = false
    internal_contains(collection,::Nothing) = false
    internal_contains(pat) = Base.Fix2(internal_contains,pat) # can be applied to collection


    swap_contains(pattern,collection) = internal_contains(collection,pattern)
    swap_contains(pattern) = Base.Fix1(swap_contains,pattern)


    always_true(_,_) = true
    haskey_swapped(k,D) = haskey(D,k)
    internal_in(k,itr) = in(k,itr)
    internal_in(a::AbstractString,b::AbstractString) = internal_isequal(a,b)
    internal_in(pat::AbstractPattern,s::AbstractString) = internal_isequal(pat,s) 
    internal_in(pat::AbstractString ,s::AbstractPattern) = internal_isequal(pat,s) 
    internal_in(pat) = Base.Fix1(internal_in,pat)

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
        @eval $(d.fun)(pat::P,input,::Nothing) where P <: Union{AbstractPattern,AbstractString,Number} =  $(d.consumer)($(d.internal)(pat),input)
        @eval $(d.fun)(pat::P,input::AbstractString,::Nothing) where P <: Union{AbstractPattern,AbstractString,Number} =  $(d.internal)(pat,input)
        @eval $(d.fun)(pat::P,input,T::Symbol) where P <: Union{AbstractPattern, AbstractString,Number} = hasproperty(input,T) && $(d.internal)(pat, getproperty(input,T))
        @eval $(d.fun)(pat,input) = $(d.fun)(pat,input,nothing)


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
    """
    chain_string_to_matchers(s::AbstractString,root_field_name::SymbolOrNothing=:tag)

Converts chain string with multiple tokens to Matchers vector
"""
function chain_string_to_matchers(s::AbstractString,root_field_name::SymbolOrNothing=:tag)
        tag_vect = Vector{AllTagMatchersUnion}()
        counter = 0
        for si in eachsplit(s,TOKENS_SEPARATOR)
            counter +=1
            push!(tag_vect,chain_string_token_to_matcher(strstr(si),root_field_name))
        end
        return tag_vect
    end



    """
    field_string_to_matcher(s::AbstractString)


Converts field string to a single `<:AbstractMatcher` object, field string can be `"field_name = args1"` or `"field_name(args2)"`
In the first case, `args1` can be a single value number or string or regex-style object viz [a,b,c] or {a,b,c}, where `{}` or `[]`   
braces tell that `all` or `any` args values viz "a", "b" and "c" should be in `field_name` field. All `args1`  elements must be separated 
by the comma  `,`.

In the second case `"field_name(args1)"`, the content of `(...)` is interpreted as arguments which are the members of AbstractDict
stored in `field_name`, args2 must be embraced in `{}` or `[]`. E.g. `"field_name([a,b,c] )"` is interpreted as `any of keys "a","b"
 and "c" must be among keys of `field_name` dictionary, when args1 also contains `=`, e.g. `args1 = [a=1,b=2,c=3]` this means
key-value pairs specification, field_name({a=1,b=2,c=3}) means that `field_name` dictionary must contain the following 
key-value pairs: `"a"=>1,"b"=>2,"c"=>3` 

"""
function field_string_to_matcher(s::AbstractString)
        #@show s
        if has_round(s) # field_name(....) syntax for checking the arguments
            field_name = Symbol(strstr(extract_before(s,"(")))
            args = extract_embraced_round(strstr(s))
            is_embraced(args) || error("set of keys must be embraced in {...} or [...]")
            convert_braced_arguments_to_matcher(args,field_name,as_keys=true)
        elseif has_equal(s)
            (field_name_string,value) = split_equality(s) # parses as key-value pair
            length(value) > 0 || error("Incorrect string format $(s)")
            field_name = Symbol(field_name_string)
            try_parse = tryparse(Float64,value)
            isnothing(try_parse) || return single_string_or_number_to_matcher(try_parse,field_name)
            return convert_braced_arguments_to_matcher(value,field_name,as_keys=false)
        else
            error("Incorrect string format $(s)")
        end
    end

    function extract_embraced_args_square_or_curl(s;convert_to_regex::Bool=false) 
        if !convert_to_regex
            return  is_embraced_square(s) ? (extract_embraced_args_square(s),:any) : (extract_embraced_args_curl(s),:all)
        else
            if  is_embraced_square(s) 
                return ((extract_embraced_args_square ∘ convert_args_vector_to_regex_vector)(s),:any)
            else 
                return ((extract_embraced_args_curl ∘ convert_args_vector_to_regex_vector)(s),:all) 
            end 
        end
    end

    """
    convert_args_vector_to_regex_vector(input::AbstractVector)

Converts the vector of args to regex, removes `*` and `::regex` if any

"""
function convert_args_vector_to_regex_vector(input::AbstractVector)
        out_vect = Vector{Regex}(undef,length(input))
        for (i,vi) in enumerate(input) 
            vi_type = typeof(vi)             
            if vi_type <: Pair
                out_vect[i] = vi[1] |> remove_asterisk |> remove_regex |>  Regex
            else
                out_vect[i] =  vi |> strstr |> remove_asterisk |> remove_regex |>  Regex
            end   
        end
        return out_vect
    end
    function convert_braced_arguments_to_matcher(args::AbstractString,field_name::SymbolOrNothing; as_keys::Bool=false)
        if !has_asterisk(args) 
            is_only_keys = as_keys && !has_equal(args) # field has keys but not key-value pairs
            is_contains_regex = has_regex(args) # check if arguments string contains ::regex
            (args_vect, set_type) = extract_embraced_args_square_or_curl(args, convert_to_regex = is_contains_regex)
            if set_type == :all 
                return (is_only_keys && !is_contains_regex) ? HasAllKeysPat(args_vect,field_name) : ContainsAllPats(args_vect,field_name)
            elseif set_type == :any
                return (is_only_keys && !is_contains_regex) ? HasAnyKeyPat(args_vect,field_name) : ContainsAnyPat(args_vect,field_name)
            else
                error("Unsupported field_name = $(field_name) and arguments = $(args)")
            end
        else
            if !is_embraced_curl(args) && !is_embraced_square(args) # simple argument has equalities but no braces
                return single_string_or_number_to_matcher(args,field_name)
            else # embraced!!! 
                (values_vect,set_type) = extract_embraced_args_square_or_curl(args,convert_to_regex = as_key)
                if as_keys # 
                    if set_type == :all
                       return ContainsAllPats(values_vect_converted,field_name)   
                    elseif set_type == :any
                        return ContainsAnyPat(values_vect_converted,field_name) 
                    else
                        error("Unsupported field_name = $(field_name) and arguments = $(args)")
                    end
                end
                matchers_set = MatchersSet(set_type)
                for vi in values_vect
                    push!(matchers_set, single_string_or_number_to_matcher(vi,field_name))
                end
                return matchers_set
            end
        end
    end    

    function single_string_or_number_to_matcher(value::AbstractString,field_name::SymbolOrNothing=:tag)
        if has_regex(value) 
            value_str = remove_regex(value)
            return  MatchesPat(Regex(value_str),field_name) 
        elseif !has_asterisk(value) 
            return MatchesPat(value,field_name)
        elseif has_asterisk(value)
            value != "*" || return AnyPat(value,field_name)
            value = remove_asterisk(value)
            return ContainsPat(value,field_name) 
        else
            error("Unsupported string $(value)")
        end
    end
    single_string_or_number_to_matcher(value::Number,field_name::Symbol=:tag) = MatchesPat(value,field_name)
    """
        chain_string_token_to_matcher(s::String)

    Function to convert single string expression into the matcher object 
    """
    function chain_string_token_to_matcher(s::String,field_name::SymbolOrNothing=:tag)
        if is_simple_pattern(s) # does not contain any special symbols like braces, 
            # dots and equal sighns, but can contain regex ::regex 
            return single_string_or_number_to_matcher(s,field_name)
        elseif !has_nondigit_dot(s) # has no encoded field, but has 
            if !has_asterisk(s) && !has_regex(s) # arguments like 
                if is_embraced_square(s) 
                    si_patt = extract_embraced_args_square(s)
                    length(si_patt) > 0 || error("Incorrect syntax $(s)")
                    any(x->isa(x,Number),si_patt) || return ContainsAnyPat(si_patt,field_name)
                    return ContainsAnyPat(string.(si_patt),field_name)
                else


                end
            else

            end
        elseif has_nondigit_dot(s)
            splitted = split_tag_and_field_name(s)
            tag_matcher = chain_string_token_to_matcher(splitted[1],:tag)
            field_matcher = field_string_to_matcher(splitted[2])
            return MatchersSet((tag_matcher,field_matcher),:all)
        else
            return error("Incorrect syntax $(s)")
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
        if contains(search_string,TOKENS_SEPARATOR) # string contains several tokens
            find_nodes_chain(starting_node,search_string)
        else
             find_nodes(starting_node,chain_string_token_to_matcher(search_string,field_name))
        end
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
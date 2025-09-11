using EngineeringDataManager
using EngineeringDataManager.XMLwalker
using Test

pwd()
@testset "matchers_tests" begin
    # Write your tests here.
    # MatchesPat - true if pattern is totally matched

    
    @test !XMLwalker.MatchesPat("abc")("asdfg")
    @test XMLwalker.MatchesPat("abc")("abc")
    @test XMLwalker.MatchesPat(("aaa","bbb"))(("aaa","bbb"))
    @test XMLwalker.MatchesPat(["aaa","bbb"])(("aaa","bbb"))
    @test !XMLwalker.MatchesPat(["aaa","bbb"])(("ccc","bbb"))
    @test XMLwalker.MatchesPat(Dict("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>2))
    @test !XMLwalker.MatchesPat(Dict("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>3))

    struct A 
        tag
    end
    a1 = A("bbb")
    @test XMLwalker.MatchesPat("bbb",:tag)(a1)
    @test !XMLwalker.MatchesPat("ccc",:tag)(a1)


    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    @test (XMLwalker.MatchesPat(("a"=>1,"b"=>2),:tag)(a2))
    
    # ContainsPat  - true if the input contains the pattern
    @test XMLwalker.ContainsPat("ab")("abc")
    @test !XMLwalker.ContainsPat("ab")("acb")
    @test XMLwalker.ContainsPat(("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>2, "ccc"=>10))
    @test !XMLwalker.ContainsPat(("aaa"=>1,"bbb"=>999))(("aaa"=>1,"bbb"=>2, "ccc"=>10))

    a2 = A("abba") # struct with field :tag
    @test XMLwalker.ContainsPat("ab",:tag)(a2)
    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    
    @test XMLwalker.ContainsPat(("a"=>1,"b"=>2),:tag)(a2)
    @test !XMLwalker.ContainsPat(("a"=>11,"b"=>2),:tag)(a2)
    @test XMLwalker.ContainsPat(Dict("a"=>1),:tag)(a2)


    # PatContains true if the pattern contains the input
    @test XMLwalker.PatContains("abc")("ab")
    @test !XMLwalker.PatContains("ab")("abc")
    @test XMLwalker.PatContains(("aaa"=>1,"bbb"=>999))(("aaa"=>1,))
    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    @test XMLwalker.PatContains(("a"=>1,"b"=>2,"c"=>10),:tag)(a2)
    @test XMLwalker.PatContains(("a"=>1,"b"=>2),:tag)(a2)
    @test !XMLwalker.PatContains(Dict("a"=>1),:tag)(a2)

    # ContainsAnyPat - true if tag contains any of the pattern content
    @test XMLwalker.ContainsAnyPat(["a" , "b" ,"c"])(["a"])
    @test XMLwalker.ContainsAnyPat(("a"=>1 , "a"=>2 ,"c"=>2))(("a"=>1,))
    a2 = A(("a"=>3, "a"=>2 ,"a"=> 5)) # struct with field :tag
    @test !XMLwalker.ContainsAnyPat(("a"=>1 ,),:tag)(a2)
    
     # HasAnyKeyPat - true if the input has at least element of pat as a key
    a2 = A(Dict("a"=>3, "b"=>2 ,"c"=> 5)) # struct with field :tag
    @test XMLwalker.HasAnyKeyPat(["a" ],:tag)(a2)
    @test !XMLwalker.HasAnyKeyPat(["f","d" ],:tag)(a2)

    # HasAllKeysPat - true if the inout has all elements of pat as keys
    a2 = A(Dict("a"=>3, "b"=>2 ,"c"=> 5)) # struct with field :tag
    @test XMLwalker.HasAllKeysPat(["a" ],:tag)(a2)
    @test !XMLwalker.HasAllKeysPat(["a","c","f" ],:tag)(a2)

    # AnyPat  - must match all patterns
    @test XMLwalker.AnyPat(["a" , "b" ,"c"])(["a"])
    @test XMLwalker.AnyPat(("a"=>1 , "a"=>2 ,"c"=>2))(("a"=>1,))
    @test XMLwalker.AnyPat(("a" => 1 ,),:tag)(a2)

    # testing node chains 
end

# test data for the next set 
using OrderedCollections
AttrType = Union{OrderedDict,Nothing}
mutable struct NodeImitation
    tag::String
    children::Union{Vector{NodeImitation},Nothing}
    attributes::AttrType
    NodeImitation(;tag::String,children=nothing,attributes::AttrType=nothing) = new(tag,children,attributes)
end

node11 = NodeImitation(tag="leaf1",attributes = OrderedDict("id"=>"p1","b"=>10, "d"=>10))
node12 = NodeImitation(tag="leaf2",attributes = OrderedDict("id"=>"p2","c"=>10 , "d"=>11))
node1 = NodeImitation(tag="branch1",children = [node11,node12])
node2 = NodeImitation(tag="branch2")
root_node = NodeImitation(tag="root",children = [node1,node2])
@testset "matchers_on_structs" begin

    m1 = XMLwalker.ContainsPat("leaf",:tag)
    m2 = XMLwalker.HasAnyKeyPat(["id"],:attributes)
    mat_set = XMLwalker.MatchersSet((m1,m2),:all)
    @test mat_set(node11)
    # testing find_nodes function using matchers

    @test node1 == find_nodes(root_node,"branch1")[]
    @test node1 == find_nodes(root_node,XMLwalker.ContainsPat("branch",:tag))[1]
    @test node2 == find_nodes(root_node,XMLwalker.ContainsPat("branch",:tag))[2]
    @test node11 == find_nodes(node1,XMLwalker.PatContains("leaf1leaf2",:tag))[1]
    @test node11 == find_nodes(root_node,XMLwalker.ContainsPat("leaf",:tag))[1]
    @test node11 == find_nodes(root_node,XMLwalker.ContainsPat(("id"=>"p1",),:attributes))[]
    leaf_nodes_branches = find_nodes(root_node,XMLwalker.HasAnyKeyPat(("id",),:attributes))
    @test node11 == leaf_nodes_branches[1]
    @test node12 == leaf_nodes_branches[2]
    #@test 

end

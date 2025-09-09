using EngineeringDataManager
using Test
using OrderedCollections
AttrType = Union{OrderedDict,Nothing}
mutable struct NodeImitation
    tag::String
    children::Union{Vector{NodeImitation},Nothing}
    attributes::AttrType
    NodeImitation(;tag::String,children=nothing,attributes::AttrType=nothing) = new(tag,children,attributes)
end

node11 = NodeImitation(tag="leaf1",attributes = OrderedDict("id"=>"p1","b"=>10))
node12 = NodeImitation(tag="leaf2",attributes = OrderedDict("id"=>"p2","c"=>10))
node1 = NodeImitation(tag="branch1",children = [node11,node12])
node2 = NodeImitation(tag="branch2")
root_node = NodeImitation(tag="root",children = [node1,node2])




pwd()
@testset "EngineeringDataManager.jl" begin
    # Write your tests here.
    # MatchesPat - true if pattern is totally matched

    
    @test !EngineeringDataManager.MatchesPat("abc")("asdfg")
    @test EngineeringDataManager.MatchesPat("abc")("abc")
    @test EngineeringDataManager.MatchesPat(("aaa","bbb"))(("aaa","bbb"))
    @test EngineeringDataManager.MatchesPat(["aaa","bbb"])(("aaa","bbb"))
    @test !EngineeringDataManager.MatchesPat(["aaa","bbb"])(("ccc","bbb"))
    @test EngineeringDataManager.MatchesPat(Dict("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>2))
    @test !EngineeringDataManager.MatchesPat(Dict("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>3))

    struct A 
        tag
    end
    a1 = A("bbb")
    @test EngineeringDataManager.MatchesPat("bbb",:tag)(a1)
    @test !EngineeringDataManager.MatchesPat("ccc",:tag)(a1)


    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    @test (EngineeringDataManager.MatchesPat(("a"=>1,"b"=>2),:tag)(a2))
    
    # ContainsPat  - true if the input contains the pattern
    @test EngineeringDataManager.ContainsPat("ab")("abc")
    @test !EngineeringDataManager.ContainsPat("ab")("acb")
    @test EngineeringDataManager.ContainsPat(("aaa"=>1,"bbb"=>2))(("aaa"=>1,"bbb"=>2, "ccc"=>10))
    @test !EngineeringDataManager.ContainsPat(("aaa"=>1,"bbb"=>999))(("aaa"=>1,"bbb"=>2, "ccc"=>10))

    a2 = A("abba") # struct with field :tag
    @test EngineeringDataManager.ContainsPat("ab",:tag)(a2)
    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    
    @test EngineeringDataManager.ContainsPat(("a"=>1,"b"=>2),:tag)(a2)
    @test !EngineeringDataManager.ContainsPat(("a"=>11,"b"=>2),:tag)(a2)
    @test EngineeringDataManager.ContainsPat(Dict("a"=>1),:tag)(a2)


    # PatContains true if the pattern contains the input
    @test EngineeringDataManager.PatContains("abc")("ab")
    @test !EngineeringDataManager.PatContains("ab")("abc")
    @test EngineeringDataManager.PatContains(("aaa"=>1,"bbb"=>999))(("aaa"=>1,))
    a2 = A(Dict("a"=>1,"b"=>2)) # struct with field :tag
    @test EngineeringDataManager.PatContains(("a"=>1,"b"=>2,"c"=>10),:tag)(a2)
    @test EngineeringDataManager.PatContains(("a"=>1,"b"=>2),:tag)(a2)
    @test !EngineeringDataManager.PatContains(Dict("a"=>1),:tag)(a2)

    # ContainsAnyPat - true if tag contains any of the pattern content
    @test EngineeringDataManager.ContainsAnyPat(["a" , "b" ,"c"])(["a"])
    @test EngineeringDataManager.ContainsAnyPat(("a"=>1 , "a"=>2 ,"c"=>2))(("a"=>1,))
    a2 = A(("a"=>3, "a"=>2 ,"a"=> 5)) # struct with field :tag
    @test !EngineeringDataManager.ContainsAnyPat(("a"=>1 ,),:tag)(a2)
    
     # HasAnyKeyPat - true if the input has at least element of pat as a key
    a2 = A(Dict("a"=>3, "b"=>2 ,"c"=> 5)) # struct with field :tag
    @test EngineeringDataManager.HasAnyKeyPat(["a" ],:tag)(a2)
    @test !EngineeringDataManager.HasAnyKeyPat(["f","d" ],:tag)(a2)

    # HasAllKeysPat - true if the inout has all elements of pat as keys
    a2 = A(Dict("a"=>3, "b"=>2 ,"c"=> 5)) # struct with field :tag
    @test EngineeringDataManager.HasAllKeysPat(["a" ],:tag)(a2)
    @test !EngineeringDataManager.HasAllKeysPat(["a","c","f" ],:tag)(a2)

    # AnyPat  - must match all patterns
    @test EngineeringDataManager.AnyPat(["a" , "b" ,"c"])(["a"])
    @test EngineeringDataManager.AnyPat(("a"=>1 , "a"=>2 ,"c"=>2))(("a"=>1,))
    @test EngineeringDataManager.AnyPat(("a" => 1 ,),:tag)(a2)

    m1 = EngineeringDataManager.ContainsPat("leaf",:tag)
    m2 = EngineeringDataManager.HasAnyKeyPat(["id"],:attributes)
    mat_set = EngineeringDataManager.MatchersSet((m1,m2),:all)
    @test mat_set(node11)
    # testing find_nodes function using matchers

    @test node1 == find_nodes(root_node,"branch1")[]
    @test node1 == find_nodes(root_node,EngineeringDataManager.ContainsPat("branch",:tag))[1]
    @test node2 == find_nodes(root_node,EngineeringDataManager.ContainsPat("branch",:tag))[2]
    @test node11 == find_nodes(node1,EngineeringDataManager.PatContains("leaf1leaf2",:tag))[1]
    @test node11 == find_nodes(root_node,EngineeringDataManager.ContainsPat("leaf",:tag))[1]
    @test node11 == find_nodes(root_node,EngineeringDataManager.ContainsPat(("id"=>"p1",),:attributes))[]
    leaf_nodes_branches = find_nodes(root_node,EngineeringDataManager.HasAnyKeyPat(("id",),:attributes))
    @test node11 == leaf_nodes_branches[1]
    @test node12 == leaf_nodes_branches[2]

    # testing node chains 

end

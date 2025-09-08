using EngineeringDataManager
using Test
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




end

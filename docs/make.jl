push!(LOAD_PATH,"../src/")
using Documenter, EngineeringDataManager
mathengine = Documenter.MathJax3()
makedocs(
        sitename = "EngineeringDataManager.jl",
        repo="https://github.com/Manarom/EngineeringDataManager.jl/blob/{commit}{path}#{line}",
        highlightsig = false,
        checkdocs = :none,
        format=Documenter.HTML(size_threshold = 2000 * 2^10),
        pages=[
                "Home" => "index.md",
                "API" =>[
                        "DataManager"=>"DataManager.md"
                        "DataServer"=>"DataServer.md"
                        ]
                ]
)
deploydocs(;
                repo="https://github.com/Manarom/EngineeringDataManager.jl/blob/{commit}{path}#{line}", 
                devbranch = "main",
                devurl="dev",
                target = "build",
                branch = "gh-pages",
                versions = ["stable" => "v^", "v#.#" ]
        )
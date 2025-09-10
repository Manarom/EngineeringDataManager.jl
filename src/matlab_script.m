jleval 2+2
jleval ENV
[s, c] = jl.eval('sin(pi/3), cos(pi/3)');
% jl.eval('Pkg.add("JSON3")') crashes matlab
jl.call('pwd')
%jleval import Pkg
jl.include(".//src//EngineeringDataManager.jl") 

%[names,nodes] = jl.call('EngineeringDataManager.material_nodes');

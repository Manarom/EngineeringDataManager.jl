jleval 2+2
jleval ENV
[s, c] = jl.eval('sin(pi/3), cos(pi/3)');
% jl.eval('Pkg.add("JSON3")') crashes matlab
jl.call('pwd')
path = fileparts(mfilename('fullpath'));
%path = string(replace(path,"\","\\"));
%j_path =char( "new_path = " + path);
%l.eval(char(j_path))
%jl.eval('cd(new_path)')
jl.call('cd',path)
jl.include("main.jl") 
%jleval import Pkg
%jl.include(".//src//EngineeringDataManager.jl") 
%jl.include(".//src//EngineeringDataServer.jl") 

%names = jl.call('EngineeringDataServer.start_server',2001);

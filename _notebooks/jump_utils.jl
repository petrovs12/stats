# jump_utils
using GraphPlot, LightGraphs,MetaGraphs,DataFrames,DataFramesMeta,JuMP
using MetaGraphs,Colors

function vertexCover(g::Graph)
	m= Model(GLPK.Optimizer)
	@variable(m, 0<=x[i=vertices(g)]<=1,Bin)
	@constraint(m,meh[e = edges(g)], x[e.src]+x[e.dst]>=1)
	@objective(m,Min,sum(x))
	m
end

function edgeCover(g::Graph)
	m=Model(GLPK.Optimizer)
	@variable(m,ed[e = edges(g)],Bin)
	@constraint(m,NodeCovered[v = vertices(g)],
	  sum([ed[e] for e in edges(g) if v in [e.src,e.dst]])>=1 
	)
	@objective(m,Min, sum(ed))
	m
end

# function create
function facilityLocationSimpleModel(;m,n,Xc,Yc,Xf,Yf,f,c,facilityCapacities,customerDemands)
	mod= Model(GLPK.Optimizer)
	@variable(mod,openFacilities[i=1:n],Bin)
	@variable(mod,0<=serviceFromFacilities[i = 1:n , j = 1:m]<=1.0)
	#constraint- everything is covered
	@constraint(mod,coverDemands[j=1:m],sum(serviceFromFacilities[:,j])==1)
	@constraint(mod,facilityCapacities[i=1:n],
        sum(customerDemands[j]*serviceFromFacilities[i,j] for j in 1:m)<=facilityCapacities[i]*openFacilities[i])

	@objective(mod,Min,sum([f[i]*openFacilities[i] for i in 1:n])+0.2*sum([c[j,i]*serviceFromFacilities[i,j] for i=1:n,j=1:m]))
	mod
end


function CreateFacilityLocationGraph(m,n,model,Xc,Yc,Xf,Yf)
	gr = MetaGraphs.MetaGraph()
	i = 1
	for v in 1:m
		add_vertex!(gr)
		set_props!(gr,i,Dict(:type=>"client",:number=>v,:X=>Xc[v],:Y=>Yc[v]))
		i+=1
	end

	for v in 1:n
		add_vertex!(gr)
		set_props!(gr,i,Dict(:type=>"facility",:number=>v,:present=>value(
            variable_by_name(model,"openFacilities[$v]")
        ),:X=>Xf[v],:Y=>Yf[v]))
		i+=1
	end

	for i = 1:n,j=1:m
		add_edge!(gr,m+i,j)
        # println( 
        #     value(variable_by_name(model,"serviceFromFacilities[$i,$j]"))
        # )
        set_props!(gr,m+i,j,Dict(:prop=>value(variable_by_name(model,"serviceFromFacilities[$i,$j]"))))
	end
    # color clients as red
    for v in filter_vertices(gr,(gr,x)->(has_prop(gr,x,:type)&&get_prop(gr,x,:type)=="client"))
        set_props!(gr,v,Dict(:color=>colorant"red"))
    end
    # color open facilities as green
    for v in filter_vertices(gr,(gr,x)->(has_prop(gr,x,:type)&&
              get_prop(gr,x,:type)=="facility"&&
              get_prop(gr,x,:present)>=1 ))
        set_prop!(gr,v,:color,colorant"green")
    end

    # color edges with flow with red
    for e in filter_edges(gr,(gr,e)->(has_prop(gr,e,:prop)&&(get_prop(gr,e,:prop)>0.0)))
        set_prop!(gr,e,:color,colorant"blue")
    end


    
	gr
end


function plotFacLocGraph(gr)
gplot(SimpleGraph(gr),
    [get_prop(gr,v,:X) for v in vertices(gr)],
    [get_prop(gr,v,:Y) for v in vertices(gr)],
    nodefillc =[has_prop(gr,v,:color) ? get_prop(gr,v,:color) : nothing for v in vertices(gr)],
    edgestrokec=[has_prop(gr,e,:color) ? get_prop(gr,e,:color) : nothing for e in edges(gr)],
    edgelinewidth = [get_prop(gr,e,:prop)>0 ? get_prop(gr,e,:prop) : 0.0  for e in edges(gr)]
    )
end
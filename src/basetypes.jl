abstract type AbstractNode end

struct Component{N} <: AbstractNode
    type::Symbol
    name::AbstractString
    freeports::MVector{N,Bool}
    vertex::RefValue{Int}
    parameters::Vector{Num}
    state_vars::Vector{Num}
    equations::Vector{Equation}
    function Component{N}(m::Symbol, n::AbstractString, np::Int, v::Int,
         p::Vector, x::Vector, eq::Vector) where N
        new(m, n, ones(MVector{np,Bool}), Ref(v), p, x, eq)
    end
end
function Component(type::Symbol, name::String=string(type);
    numports::Int=1, vertex::Int=0, parameters::Vector=[], state_vars::Vector=[],
    equations::Vector=[])
    Component{numports}(type, name, numports, vertex, parameters, state_vars, equations)
end

abstract type Junction <: AbstractNode end

mutable struct EqualEffort <: Junction
    name::AbstractString
    degree::Int
    vertex::RefValue{Int}
    EqualEffort(; name::AbstractString="0", v::Int=0) = new(name, 0, Ref(v))
end

mutable struct EqualFlow <: Junction
    name::AbstractString
    degree::Int
    weights::Vector{Int}
    vertex::RefValue{Int}
    EqualFlow(; name::AbstractString="1", v::Int=0) = new(name, 0, Vector{Int}[], Ref(v))
end

struct Port 
    node::AbstractNode
    index::Int
    function Port(node::AbstractNode, index)
        ports = freeports(node)
        any(ports) || error("Node $node has no free ports")
        ports[index] || error("Port $index in node $node is already connected")
        new(node, index)
    end
    Port(node::Junction, index) = new(node, index)
end
Port(node::AbstractNode) = Port(node, nextfreeport(node))

struct Bond <: lg.AbstractSimpleEdge{Int}
    src::Port
    dst::Port
end
function Bond(srcnode::AbstractNode, dstnode::AbstractNode)
    Bond(Port(srcnode), Port(dstnode))
end

struct BondGraph <: lg.AbstractGraph{Int64}
    type::Symbol
    name::AbstractString
    nodes::Vector{T} where T <: AbstractNode
    bonds::Vector{Bond}
end
BondGraph(type::Symbol=:BG, name::AbstractString=string(type)) = BondGraph(type, name, AbstractNode[], Bond[])
BondGraph(name::AbstractString) = BondGraph(:BG, name)

# New component
function new(type,name::String=string(type);library=standard_library)
    d = library[type]
    p = collect(keys(d[:parameters]))
    if haskey(d,:state_vars)
        x = collect(keys(d[:state_vars]))
    else
        x = Vector{Num}([])
    end
    Component(type, name; numports=d[:numports], parameters=p, state_vars=x, equations=d[:equations])
end

# All models
Model = Union{AbstractNode,BondGraph}

# Component type
type(n) = n.type
type(n::EqualEffort) = Symbol("0")
type(n::EqualFlow) = Symbol("1")

# Vertex
vertex(n::AbstractNode) = n.vertex[]
set_vertex!(n::AbstractNode, v::Int) = n.vertex[] = v

# Ports
freeports(n::Component) = n.freeports
freeports(n::Junction) = [true]
numports(n::Component) = length(n.freeports)
numports(n::Junction) = Inf
updateport!(n::AbstractNode, idx::Int) = freeports(n)[idx] = !freeports(n)[idx]
updateport!(n::Junction, idx::Int) = freeports(n)

nextfreeport(n::AbstractNode) = findfirst(freeports(n))
function nextfreeport(j::Junction)
    j.degree += 1
    j.degree
end
function nextfreeport(j::EqualFlow)
    append!(j.weights,0)
    j.degree += 1
    j.degree
end

nextsrcport(n::AbstractNode) = nextfreeport(n)
function nextsrcport(n::EqualFlow)
    i = nextfreeport(n)
    n.weights[i] = -1
    i
end

nextdstport(n::AbstractNode) = nextfreeport(n)
function nextdstport(n::EqualFlow)
    i = nextfreeport(n)
    n.weights[i] = 1
    i
end

# Nodes in Bonds
srcnode(b::Bond) = b.src.node
dstnode(b::Bond) = b.dst.node
in(n::AbstractNode, b::Bond) = n == srcnode(b) || n == dstnode(b)
Base.iterate(b::Bond) = (b.src,true)
function Base.iterate(b::Bond,state)
    if state
        return (b.dst,false)
    else
        return nothing
    end
end

# Parameters
params(n::Component) = n.parameters
params(j::Junction) = Vector{Num}([])

# Components
components(bg::BondGraph) = bg.nodes

# State variables
state_vars(n::Component) = n.state_vars
state_vars(j::Junction) = Vector{Num}([])
function state_vars(m::BondGraph)
    i = 0
    dict_states = OrderedDict{Num,Tuple{Model,Num}}()
    for c in components(m)
        for x in state_vars(c)
            i += 1
            dict_states[internal_state(i)] = (c,x)
        end
    end
    return dict_states
end

# Bonds
bonds(m::BondGraph) = m.bonds

# I/O
show(io::IO, node::AbstractNode) = print(io, "$(type(node)):$(node.name)")
#show(io::IO, node::Junction) = print(io, "$(type(node))")
show(io::IO, port::Port) = print(io, "Port $(port.node) ($(port.index))")
show(io::IO, b::Bond) = print(io, "Bond $(srcnode(b)) ⇀ $(dstnode(b))")
show(io::IO, bg::BondGraph) = print(io, "BondGraph $(type(bg)):$(bg.name) ($(lg.nv(bg)) Nodes, $(lg.ne(bg)) Bonds)")

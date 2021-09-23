abstract type AbstractNode end

struct Component{N} <: AbstractNode
    type::Symbol
    name::AbstractString
    freeports::MVector{N,Bool}
    vertex::RefValue{Int}
    function Component{N}(m::Symbol, n::AbstractString, np::Int, v::Int) where N
        new(m, n, ones(MVector{np,Bool}), Ref(v))
    end
end
Component(type::Symbol, name::String=string(type); numports::Int=1, vertex::Int=0) = 
    Component{numports}(type, name, numports, vertex)

struct Junction <: AbstractNode
    type::Symbol
    name::AbstractString
    vertex::RefValue{Int}
    Junction(m::Symbol; n::AbstractString=string(m), v::Int=0) = new(m, n, Ref(v))
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
    comp_dict = library[type]
    Component(type, name; numports=comp_dict[:numports])
end

# Vertex
vertex(n::AbstractNode) = n.vertex[]
set_vertex!(n::AbstractNode, v::Int) = n.vertex[] = v

# Ports
freeports(n::Component) = n.freeports
freeports(n::Junction) = [true]
numports(n::Component) = length(n.freeports)
numports(n::Junction) = Inf
updateport!(n::AbstractNode, idx::Int) = freeports(n)[idx] = !freeports(n)[idx]
nextfreeport(n::AbstractNode) = findfirst(freeports(n))

# Nodes in Bonds
srcnode(b::Bond) = b.src.node
dstnode(b::Bond) = b.dst.node
in(n::AbstractNode, b::Bond) = n == srcnode(b) || n == dstnode(b)

# I/O
show(io::IO, node::Component) = print(io, "$(node.type):$(node.name)")
show(io::IO, node::Junction) = print(io, "$(node.type)")
show(io::IO, port::Port) = print(io, "Port $(port.node) ($(port.index))")
show(io::IO, b::Bond) = print(io, "Bond $(srcnode(b)) ⇀ $(dstnode(b))")
show(io::IO, bg::BondGraph) = print(io, "BondGraph $(bg.type):$(bg.name) ($(lg.nv(bg)) Nodes, $(lg.ne(bg)) Bonds)")

abstract type AbstractNode end

# COMPONENT
struct Component{N} <: AbstractNode
    type::Symbol
    name::Symbol
    freeports::MVector{N,Bool}
    vertex::RefValue{Int}
    parameters::Dict{Num,Number}
    states::Dict{Num,Number}
    controls::Dict{Num,Function}
    equations::Vector{Equation}
    function Component{N}(t, n, v, p, x, c, eq) where {N}
        new(Symbol(t), Symbol(n), ones(MVector{N,Bool}), Ref(v), p, x, c, eq)
    end
end

function Component(type, name=type; vertex::Int=0, library=BondGraphs.DEFAULT_LIBRARY,
    comp_dict=haskey(library, type) ? library[type] : Dict(),
    numports::Int=haskey(comp_dict, :numports) ? comp_dict[:numports] : 1,
    parameters=haskey(comp_dict, :parameters) ? comp_dict[:parameters] : Dict(),
    states=haskey(comp_dict, :states) ? comp_dict[:states] : Dict(),
    controls=haskey(comp_dict, :controls) ? comp_dict[:controls] : Dict(),
    equations=haskey(comp_dict, :equations) ? comp_dict[:equations] : Equation[])

    Component{numports}(type, name, vertex, copy(parameters), copy(states), copy(controls), equations)
end

# Source-sensor
struct SourceSensor <: AbstractNode
    name::Symbol
    freeports::MVector{1,Bool}
    vertex::RefValue{Int}
    SourceSensor(; name=:SS, v::Int=0) = new(Symbol(name), ones(MVector{1,Bool}), Ref(v))
end


# JUNCTION
abstract type Junction <: AbstractNode end

struct EqualEffort <: Junction
    name::Symbol
    freeports::Vector{Bool}
    weights::Vector{Int}
    vertex::RefValue{Int}
    EqualEffort(; name=Symbol("0"), v::Int=0) = new(Symbol(name), [true], [0], Ref(v))
end

struct EqualFlow <: Junction
    name::Symbol
    freeports::Vector{Bool}
    weights::Vector{Int}
    vertex::RefValue{Int}
    EqualFlow(; name=Symbol("1"), v::Int=0) = new(Symbol(name), [true], [0], Ref(v))
end


# PROPERTIES
# Type
type(n::AbstractNode) = n.type
type(j::Junction) = typeof(j)
type(::SourceSensor) = :SS

# Name
name(n::AbstractNode) = n.name

# Ports
freeports(n::AbstractNode) = n.freeports
numports(n::AbstractNode) = length(n.freeports)
updateport!(n::AbstractNode, idx::Int) = freeports(n)[idx] = !freeports(n)[idx]

# Weights
weights(j::Junction) = j.weights
set_weight!(j::Junction, idx::Int, w::Int) = j.weights[idx] = w

nextfreeport(n::AbstractNode) = findfirst(freeports(n))
function nextfreeport(j::Junction)
    freeport = findfirst(freeports(j))
    if isnothing(freeport)
        push!(j.freeports, true)
        push!(j.weights, 0)
        return length(j.freeports)
    else
        return freeport
    end
end

# Vertex
vertex(n::AbstractNode) = n.vertex[]
set_vertex!(n::AbstractNode, v::Int) = n.vertex[] = v

# Parameters
parameters(n::AbstractNode) = collect(keys(n.parameters))
parameters(::Junction) = Num[]
parameters(::SourceSensor) = Num[]

# State variables
states(n::AbstractNode) = collect(keys(n.states))
states(::Junction) = Num[]
states(::SourceSensor) = Num[]

# Control variables
controls(n::AbstractNode) = collect(keys(n.controls))
controls(::Junction) = Num[]
controls(::SourceSensor) = Num[]

# Equations
equations(n::AbstractNode) = n.equations
equations(::Junction) = Equation[]
equations(::SourceSensor) = Equation[]

# Defaults
defaults(n::AbstractNode) = merge(n.parameters, n.states, n.controls)
defaults(::Junction) = Dict{Num,Any}()
defaults(::SourceSensor) = Dict{Num,Any}()

function get_default(n::AbstractNode, var)
    default_dict, _var = _find_var(n, var)
    default_dict[_var]
end
function set_default!(n::AbstractNode, var, val)
    default_dict, _var = _find_var(n, var)
    default_dict[_var] = val
end

function _find_var(n::AbstractNode, var)
    # Try both parameters and state/control vars
    p, = @parameters $var
    _, x = @variables t, $var(t)
    if string(p) in string.(parameters(n))
        return n.parameters, p
    elseif string(x) in string.(states(n))
        return n.states, x
    elseif string(x) in string.(controls(n))
        return n.controls, x
    else
        error("Component does not have variable $var")
    end
end

# BASE FUNCTIONS
# This definition will need to expand when equations etc. are added
==(n1::AbstractNode, n2::AbstractNode) = type(n1) == type(n2) && n1.name == n2.name

show(io::IO, node::AbstractNode) = print(io, "$(type(node)):$(node.name)")
show(io::IO, node::Junction) = print(io, "$(node.name)")

using Revise
using BondGraphs
using LightGraphs
using ModelingToolkit
using Test

@testset "BondGraphs.jl" begin
    @testset "Graph functions" begin include("graphfunctions_tests.jl") end
    @testset "Construction" begin include("construction_tests.jl") end
    @testset "Equations" begin include("equation_tests.jl") end
end
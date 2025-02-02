t = ModelingToolkit.t_nounits
D = ModelingToolkit.D_nounits

function find_subsys(sys, s)
    subsys = ModelingToolkit.get_systems(sys)
    return filter(x -> nameof(x) == s, subsys)[1]
end

@testset "SS component system" begin
    SS = SourceSensor(name=:SS)

    @test length(freeports(SS)) == 1
    @test numports(SS) == 1
    @test length(parameters(SS)) == 0
    @test length(states(SS)) == 0
    @test length(equations(SS)) == 0
    @test length(constitutive_relations(SS)) == 0

    sys = ODESystem(SS)
    @test length(sys.systems) == 1
    @test sys.p1.E isa Num
    @test sys.p1.F isa Num
end

@testset "Expose models" begin
    r = Component(:R)
    kcl = EqualFlow(name=:kcl)
    SSA = SourceSensor(name=:A)
    SSB = SourceSensor(name=:B)

    bg = BondGraph()
    add_node!(bg, [r, kcl, SSA, SSB])
    connect!(bg, kcl, r)
    connect!(bg, SSA, kcl)
    connect!(bg, kcl, SSB)

    bgn = BondGraphNode(bg)
    @test numports(bgn) == 2

    sys = ODESystem(bgn)
    expanded_sys = expand_connections(sys) # Note that the equations shouldn't simplify by default
    eqns = equations(expanded_sys)

    p1 = find_subsys(sys, :p1)
    p2 = find_subsys(sys, :p2)
    (E1, F1, E2, F2) = (p1.E, p1.F, p2.E, p2.F)

    Asys = find_subsys(sys, :A)
    Bsys = find_subsys(sys, :B)
    (AE, AF, BE, BF) = (Asys.p1.E, Asys.p1.F, Bsys.p1.E, Bsys.p1.F)

    @test (0 ~ E1 - AE) in eqns
    @test (0 ~ F1 + AF) in eqns
    @test (0 ~ E2 - BE) in eqns
    @test (0 ~ F2 + BF) in eqns
end

@testset "Modular RLC circuit" begin
    r = Component(:R)
    l = Component(:I)
    c = Component(:C)
    kvl = EqualEffort(name=:kvl)
    SS1 = SourceSensor(name=:SS1)
    SS2 = SourceSensor(name=:SS2)

    bg1 = BondGraph(:RC)
    add_node!(bg1, [r, c, kvl, SS1])
    connect!(bg1, r, kvl)
    connect!(bg1, c, kvl)
    connect!(bg1, SS1, kvl)
    bgn1 = BondGraphNode(bg1)

    bg2 = BondGraph(:L)
    add_node!(bg2, [l, SS2])
    connect!(bg2, l, SS2)
    bgn2 = BondGraphNode(bg2)

    bg = BondGraph()
    add_node!(bg, [bgn1, bgn2])
    connect!(bg, bgn1, bgn2)

    eqs = constitutive_relations(bg)
    @test length(eqs) == 2

    sys = ODESystem(bg)
    (R, C, L) = (sys.RC.R.R, sys.RC.C.C, sys.L.I.L)
    (qC, pL) = (sys.RC.C.q, sys.L.I.p)
    e1 = D(qC) ~ -pL / L + (-qC / C / R)
    e2 = D(pL) ~ qC / C

    @test isequal(eqs[1].lhs, e1.lhs)
    @test isequal(simplify(eqs[1].rhs - e1.rhs), 0)
    @test isequal(eqs[2].lhs, e2.lhs)
    @test isequal(eqs[2].rhs, e2.rhs)
end

@testset "Modular reaction" begin
    bg1 = BondGraph(:R)
    re = Component(:re, :r)
    SSA = SourceSensor(name=:A)
    SSB = SourceSensor(name=:B)
    add_node!(bg1, [SSA, SSB, re])
    connect!(bg1, SSA, (re, 1))
    connect!(bg1, (re, 2), SSB)
    bgn1 = BondGraphNode(bg1)

    bg = BondGraph()
    A = Component(:ce, :A)
    B = Component(:ce, :B)
    add_node!(bg, [A, B, bgn1])
    connect!(bg, A, (bgn1, 1))
    connect!(bg, (bgn1, 2), B)

    sys = ODESystem(bg)
    eqs = constitutive_relations(bg)
    
    (xA, xB) = (sys.A.q, sys.B.q)
    (KA, KB, r) = (sys.A.K, sys.B.K, sys.R.r.r)
    e1 = D(xA) ~ r * (-KA * xA + KB * xB)
    e2 = D(xB) ~ r * (KA * xA - KB * xB)
    
    @test isequal(eqs[1].lhs, e1.lhs)
    @test isequal(eqs[1].rhs, e1.rhs)
    @test isequal(eqs[2].lhs, e2.lhs)
    @test isequal(eqs[2].rhs, e2.rhs)
end

@testset "Named ports" begin
    bg1 = BondGraph(:R)
    re = Component(:re, :r)
    SSA = SourceSensor(name=:A)
    SSB = SourceSensor(name=:B)
    add_node!(bg1, [SSA, SSB, re])
    connect!(bg1, SSA, (re, 1))
    connect!(bg1, (re, 2), SSB)
    bgn1 = BondGraphNode(bg1)

    bg = BondGraph()
    A = Component(:ce, :A)
    B = Component(:ce, :B)
    add_node!(bg, [A, B, bgn1])
    connect!(bg, A, (bgn1, :A))
    connect!(bg, (bgn1, :B), B)

    sys = ODESystem(bg)
    eqs = constitutive_relations(bg)
    
    (xA, xB) = (sys.A.q, sys.B.q)
    (KA, KB, r) = (sys.A.K, sys.B.K, sys.R.r.r)
    e1 = D(xA) ~ r * (-KA * xA + KB * xB)
    e2 = D(xB) ~ r * (KA * xA - KB * xB)
    
    @test isequal(eqs[1].lhs, e1.lhs)
    @test isequal(eqs[1].rhs, e1.rhs)
    @test isequal(eqs[2].lhs, e2.lhs)
    @test isequal(eqs[2].rhs, e2.rhs)
end

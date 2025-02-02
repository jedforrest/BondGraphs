t = ModelingToolkit.t_nounits
D = ModelingToolkit.D_nounits

function RLC()
    r = Component(:R)
    l = Component(:I)
    c = Component(:C)
    kvl = EqualEffort(name=:kvl)

    bg = BondGraph()
    add_node!(bg, [c, l, kvl, r])

    connect!(bg, r, kvl)
    connect!(bg, l, kvl)
    connect!(bg, c, kvl)
    return bg
end

# cannot use standard notation "var in array" for MTK vars
var_in(var, dict) = any(iszero.(var .- keys(dict)))

# sort equations in lex order to make testing equations easier
sorted_eqs(sys) = sort(equations(sys), by=string)

@testset "Equations" begin
    c = Component(:C)
    @parameters C
    @variables E(t)[1] F(t)[1] q(t) C₊q(t)
    cr = [
        0 ~ q / C - E[1],
        D(q) ~ F[1]
    ]

    @test isequal(equations(c), cr)
    @test isequal(constitutive_relations(c), cr)

    j = EqualEffort()
    @test isequal(equations(j), Equation[])

    bg = BondGraph()
    @test equations(bg) == Equation[]
    add_node!(bg, c)
    @test equations(bg) == [D(C₊q) ~ -0.0] # Equation produces -ve zero
end

@testset "Parameters" begin
    tf = Component(:TF)
    @parameters n
    @test var_in(n, parameters(tf))

    Ce = Component(:Ce)
    @parameters K
    @test var_in(K, parameters(Ce))

    bg = RLC()
    @parameters C L R
    all_params = merge(values(parameters(bg))...)
    for var in [C L R]
        @test var_in(var, all_params)
    end
end

@testset "Globals" begin
    re = Component(:Re)
    c = Component(:C)
    @parameters R T

    @test var_in(T, globals(re))
    @test var_in(R, globals(re))
    @test globals(c) == Dict()

    bg = BondGraph()
    add_node!(bg, re)
    all_globals = merge(values(globals(bg))...)
    @test var_in(T, all_globals)
    @test var_in(R, all_globals)
end

@testset "State variables" begin
    r = Component(:R)
    @test isempty(states(r))

    @variables q(t)
    c = Component(:C)
    @test var_in(q, states(c))

    ce = Component(:ce)
    @test var_in(q, states(ce))

    bg = RLC()
    @variables q(t) p(t)
    all_states = merge(values(states(bg))...)
    @test var_in(q, all_states)
    @test var_in(p, all_states)
end

@testset "Controls" begin
    se = Component(:Se)
    sf = Component(:Sf)
    c = Component(:C)
    @parameters fs es

    @test var_in(es, controls(se))
    @test var_in(fs, controls(sf))
    @test controls(c) == Dict()

    bg = RLC()
    @test !has_controls(bg)

    add_node!(bg, [se, sf])
    @test has_controls(bg)

    all_controls = merge(values(controls(bg))...)
    @test var_in(es, all_controls) && var_in(fs, all_controls)
end

@testset "All variables" begin
    bg = RLC()
    re = Component(:Re)
    add_node!(bg, re)

    for (comp, var_dict) in all_variables(bg)
        @test all_variables(comp) == var_dict
    end
end

@testset "Constitutive relations" begin
    eqE = EqualEffort()
    eqF = EqualFlow()
    @test constitutive_relations(eqE) == Equation[]
    @test constitutive_relations(eqF) == Equation[]

    bg = RLC()
    cr_bg = constitutive_relations(bg)
    sys = ODESystem(bg)

    C, L, R = (sys.C.C, sys.I.L, sys.R.R)
    q, p = sys.C.q, sys.I.p
    cr1 = D(q) ~ -(q / C) / R + (-p) / L
    cr2 = D(p) ~ q / C

    # Constitutive relations
    @test isequal(cr_bg[1].lhs, cr1.lhs)
    @test isequal(simplify(cr_bg[1].rhs - cr1.rhs), 0)
    @test isequal(cr_bg[2], cr2)

    # BondGraphNode CR
    cr_bgn = constitutive_relations(BondGraphNode(bg))
    @test isequal(cr_bgn[1].lhs, cr1.lhs)
    @test isequal(simplify(cr_bgn[1].rhs - cr1.rhs), 0)
    @test isequal(cr_bgn[2], cr2)

    # CR with sub_defaults=true
    subbed_eqs = [
        D(q) ~ -q - p,
        D(p) ~ q
    ]
    @test BondGraphs._sub_defaults([cr1, cr2], all_variables(bg)) == subbed_eqs
    @test constitutive_relations(bg; sub_defaults=true) == subbed_eqs
end

@testset "0-junction equations" begin
    model = BondGraph(:RC)
    C = Component(:C)
    R = Component(:R)
    zero_law = EqualEffort()

    add_node!(model, [R, C, zero_law])
    connect!(model, R, zero_law)
    connect!(model, zero_law, C)

    @test numports(zero_law) == 2

    @variables E(t)[1:2] F(t)[1:2]
    @test isequal(constitutive_relations(zero_law), [
        0 ~ F[1] + F[2],
        0 ~ E[1] - E[2]
    ])
end

@testset "1-junction equations" begin
    c1 = Component(:C, :C1)
    c2 = Component(:R, :R1)
    c3 = Component(:I, :I1)
    j = EqualFlow()

    bg = BondGraph()
    add_node!(bg, [c1, c2, c3, j])
    connect!(bg, c1, j)
    connect!(bg, j, c2)
    connect!(bg, j, c3)

    @test numports(j) == 3
    @test length(ports(j)) == 3
    @test ports(j) == [1, -1, -1]

    @variables E(t)[1:3] F(t)[1:3]
    @test isequal(constitutive_relations(j), [
        0 ~ E[1] - E[2] - E[3],
        0 ~ F[1] + F[2],
        0 ~ F[1] + F[3],
    ])
end

@testset "RC circuit" begin
    r = Component(:R)
    c = Component(:C)
    bg = BondGraph(:RC)
    add_node!(bg, [c, r])
    connect!(bg, r, c)

    sys = ODESystem(bg)
    eqs = constitutive_relations(bg)
    @test length(eqs) == 1

    (C, R) = (sys.C.C, sys.R.R)
    x = sys.C.q
    e1 = eqs[1]
    e2 = D(x) ~ -x / C / R

    @test isequal(e1.lhs, e2.lhs)
    @test isequal(expand(e1.rhs), e2.rhs)
end

@testset "RL circuit" begin
    r = Component(:R)
    l = Component(:I)
    bg = BondGraph(:RL)
    add_node!(bg, [r, l])
    connect!(bg, l, r)

    eqs = constitutive_relations(bg)
    sys = ODESystem(bg)
    x = sys.I.p
    (R, L) = (sys.R.R, sys.I.L)
    @test eqs == [D(x) ~ -R * x / L]
end

@testset "RLC circuit" begin
    bg = RLC()
    eqs = constitutive_relations(bg)
    @test length(eqs) == 2

    sys = ODESystem(bg)
    (R, L, C) = (sys.R.R, sys.I.L, sys.C.C)
    (qC, pL) = (sys.C.q, sys.I.p)
    e1 = D(qC) ~ -pL / L + (-qC / C / R)
    e2 = D(pL) ~ qC / C

    @test isequal(simplify(eqs[1].rhs - e1.rhs), 0)
    @test isequal(eqs[2].rhs, e2.rhs)
end

@testset "Chemical reaction A ⇌ B" begin
    A = Component(:ce, :A)
    B = Component(:ce, :B)
    re = Component(:re, :r)
    bg = BondGraph()

    add_node!(bg, [A, B, re])
    connect!(bg, A, (re,1))
    connect!(bg, (re,2), B)
    sys = ODESystem(bg)
    eqs = sorted_eqs(sys)

    (xA, xB) = (sys.A.q, sys.B.q)
    (KA, KB, r) = (sys.A.K, sys.B.K, sys.r.r)
    e1 = D(xA) ~ r * (-KA * xA + KB * xB)
    e2 = D(xB) ~ r * (KA * xA - KB * xB)

    @test isequal(eqs[1].rhs, e1.rhs)
    @test isequal(eqs[2].rhs, e2.rhs)
end

@testset "Chemical reaction A ⇌ B + C, C ⇌ D" begin
    C_A = Component(:ce, :A)
    C_B = Component(:ce, :B)
    C_C = Component(:ce, :C)
    C_D = Component(:ce, :D)
    re1 = Component(:re, :r1)
    re2 = Component(:re, :r2)
    common_C = EqualEffort()
    BC = EqualFlow()

    bg = BondGraph()
    add_node!(bg, [C_A, C_B, C_C, C_D, re1, re2, common_C, BC])
    connect!(bg, C_A, (re1,1))
    connect!(bg, (re1,2), BC)
    connect!(bg, BC, C_B)
    connect!(bg, BC, common_C)
    connect!(bg, common_C, C_C)
    connect!(bg, common_C, (re2,1))
    connect!(bg, (re2,2), C_D)

    sys = ODESystem(bg)
    eqs = sorted_eqs(sys)

    (xA, xB, xC, xD) = (sys.A.q, sys.B.q, sys.C.q, sys.D.q)
    (KA, KB, KC, KD, r1, r2) = (sys.A.K, sys.B.K, sys.C.K, sys.D.K, sys.r1.r, sys.r2.r)
    e1 = D(xA) ~ -r1 * (KA * xA - KB * xB * KC * xC)
    e2 = D(xB) ~ r1 * (KA * xA - KB * xB * KC * xC)
    e3 = D(xC) ~ r1 * (KA * xA - KB * xB * KC * xC) - r2 * (KC * xC - KD * xD)
    e4 = D(xD) ~ r2 * (KC * xC - KD * xD)

    @test isequal(simplify(eqs[1].rhs - e1.rhs),0)
    @test isequal(simplify(eqs[2].rhs - e2.rhs),0)
    @test isequal(simplify(eqs[3].rhs - e3.rhs),0)
    @test isequal(simplify(eqs[4].rhs - e4.rhs),0)
end
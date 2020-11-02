using QuickTypes
using QuickTypes: construct, roottypeof, fieldsof, type_parameters, roottype,
      tuple_parameters
using Test
using ConstructionBase: setproperties

abstract type Vehicle end

@qstruct Car{T<:Number, U}(size::T, nwheels::Int=4; manufacturer::U=nothing,
                           brand::String="off-brand") <: Vehicle

c = Car(10; manufacturer=("Danone", "Hershey"))

@test c.size==10
@test c.nwheels==4
@test c.manufacturer==("Danone", "Hershey")
@test c.brand=="off-brand"
c2 = @inferred setproperties(c, (size=42, nwheels=8))
@test c2.nwheels == 8
@test c2.size == 42
@test c2.brand == c.brand
# Check that the fields are in the right order
@test collect(fieldnames(Car)) == [:size, :nwheels, :manufacturer, :brand]
# This is essentially the definition of these functions.
@test construct(roottypeof(c), fieldsof(c)...) == c
@test type_parameters(Vector{Int}) == Base.Core.svec(Int64, 1)
@test tuple_parameters(Tuple{Int, Float64}) == Base.Core.svec(Int64, Float64)
@inferred roottypeof(1=>2) == Pair

################################################################################

@qstruct Empty()
Empty()
@test setproperties(Empty(), NamedTuple()) === Empty()

# Used to yield:
#     WARNING: static parameter T does not occur in signature for Type.
#     The method will not be callable.
@qstruct Blah{T}()

################################################################################

@qstruct Boring(x::Int)
@inferred Boring(10)
@test Boring(10).x == 10
@test Boring(10.0).x == 10   # check that convert is called correctly
@qstruct ParametricBoring{X}(x::X; _concise_show=true)
@inferred ParametricBoring(10)
@test ParametricBoring(10).x === 10
o = ParametricBoring(1)
@test setproperties(o, x=:one).x === :one

@qstruct Kwaroo(x; y=10)
@test Kwaroo(5) == Kwaroo(5; y=10)
o = Kwaroo(5, y=10)
o2 = @inferred setproperties(o, (x=:five, y=100.0))
@test o2 isa Kwaroo
@test o2.x === :five
@test o2.y === 100.0

################################################################################
# Slurping

@qstruct Slurp(x, y=1, args...; kwargs...)
s = Slurp(1,2,3,4,5,6,7; x=1, y=10+2)
@test s.args == (3,4,5,6,7)
@test s.kwargs == [(:x => 1), (:y => 12)]
s2 = @inferred setproperties(s, x=:hello)
@test s2 isa Slurp
@test s2.x == :hello
@test s2.y == s.y

let
    @unpack_Slurp Slurp(10)
    @test x == 10
    @test y == 1
end

################################################################################

@qmutable Foo{T}(x::T; y=2) do
    @assert x < 10
end

@test_throws AssertionError Foo(11; y=10.0)
@test_throws AssertionError construct(Foo, 11, 10.0)

################################################################################
# Fully-parametric

@qstruct_fp Plane(nwheels::Number; brand=:zoomba) do
    @assert nwheels < 100
end <: Vehicle

@test_throws MethodError Plane{Int, Symbol}(2; brand=12)
@test Plane{Int, Symbol}(2; brand=:zoomba).brand == :zoomba
@test supertype(Plane) == Vehicle
# This used to be a MethodError, but since we moved the outer constructor inside
# the type, it has become a TypeError. Not sure why!
@test_throws TypeError Plane("happy")

@qstruct_fp NoFields()   # was an error before it was special-cased

o = Plane(4)
o2 = @inferred setproperties(o, brand=10, nwheels=o.nwheels)
@test o2 isa Plane
@test o2.brand === 10
@test o2.nwheels === o.nwheels

################################################################################
# Narrowly-parametric

@qstruct_fp Foo_fp(a, b)
@qstruct_np Foo_np(a, b)
convert_f(foo) = convert(foo.a, 10)
@test_throws(Exception, @inferred convert_f(Foo_fp(Int, 2)))
@inferred convert_f(Foo_np(Int, 2))
@test fieldtype(typeof(Foo_np(Int, 2)), :a) == Type{Int64}

@qstruct Issue11(;no_default_value)
@test_throws UndefKeywordError Issue11()

################################################################################
# @qfunctor

@qfunctor function Action(a; kw=100)(x)
    return a + x + kw
end

@test Action(2)(10) == 112

################################################################################
# @destruct

@destruct foo(Ref(x)) = x+2
@destruct foo(Ref{Float64}(x)) = x+10
@test foo(Ref(10)) == 12
@test foo(Ref(10.0)) == 20
@destruct foo(a, (Ref{T} where T)(x)) = a + x

struct LongerStruct{X}
    a
    b
    c::X
end
#@destruct kwfun(LongerStruct{X}(


#TODO:
#@destruct x = Foo(x)   # have the @destruct function ... expand into that
#@destruct x if Foo(x) ... end

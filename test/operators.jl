using Distributed
@testset "drop_repeats" begin
    Signals.async_mode(false)
    A = Signal(1)
    B = Signal(droprepeats(A); state = 0) do a, state
        state.x += 1
        a + 1
    end
    C = Signal(B; state = 0) do b, state
        state.x += 1
        b + 1
    end

    @test B.state.x == 1
    @test C.state.x == 1
    A(1); A(1);
    @test B.state.x == 1
    @test C.state.x == 1
    A(3.14)
    @test B.state.x == 2
    @test C.state.x == 2
end

@testset "when do" begin
    Signals.async_mode(false)
    A = Signal(1)
    cond = Signal(A) do a
        a < 10
    end
    B = when(cond, A) do a
        a*2
    end
    A(5)
    @test B[] == 10
    A(15)
    @test B[] == 10

    A[] = 2
    @test B() == 4
    A[] = 15
    @test B() == 4
end

@testset "sampleon" begin
    Signals.async_mode(false)
    A = Signal(1)
    B = Signal(10)
    C = sampleon(A, B)

    @test C[] == 10
    B(0)
    @test C[] == 10
    A(2)
    @test C[] == 0

    B[] = 200
    @test C() == 0
    A[] = 9
    @test C() == 200
end

@testset "filter" begin
    Signals.async_mode(false)
    A = Signal(100000)
    B = filter(x -> x<10, 1, A)

    @test B[] == 1
    A(100)
    @test B[] == 1
    A(9)
    @test B[] == 9

    A[] = 1
    @test B() == 1
    A[] = 100
    @test B() == 1
    A[] = 9
    @test B() == 9
end

@testset "foldp" begin
    Signals.async_mode(false)
    A = Signal(1)
    B = foldp(+, 0, A)

    A(2)
    A(3)
    @test B[] == 6

    A[] = 6
    @test B() == 12
end

@testset "merge" begin
    Signals.async_mode(false)
    A = Signal(1)
    B = Signal(1)
    C = merge(A, B)

    A(10)
    @test C[] == 10
    B[] = "aa"
    @test C() == "aa"

    A[] = 0; B[] = 100
    @test C() == 100

    A = Signal(1)
    B = Signal(1)
    C = droprepeats(A)
    D = merge(B, C)

    A(100)
    @test D[] == 100
    B[] = "hh"; A[] = 100
    @test D() == "hh"
end

@testset "async_signal" begin
    addprocs(1)
    @everywhere using Signals
    Signals.async_mode(true)

    A = Signal(1)
    B = async_signal(x -> x+1, A)
    C = remote_signal(x -> x+1, A)

    A(10)
    sleep(2)
    @test B() == 11
    sleep(2)
    @test C() == 11
end

@testset "recursion_free" begin
    A = Signal(1)
    C = count(A)

    B = recursion_free(A) do a
        A(a+1)
    end

    Signals.async_mode(true)
    A(10)
    sleep(0.1)
    @test C() == 3
    @test A() == 11

    Signals.async_mode(false)
    A(100)
    @test C() == 4
    @test A() == 101
end

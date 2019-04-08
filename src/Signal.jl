mutable struct SignalData
    x
    valid::Bool
    propagated::Bool
end
SignalData(x) = SignalData(x, true, false)
SignalData() = SignalData(nothing, false, false)
SignalData(::Nothing) = SignalData()

struct Signal
    data::SignalData
    action::PullAction
    children::Vector{Signal}
    binders::Vector{Signal}
    strict_push::Bool
    state::Ref
end

add_child!(arg_signal::Signal,s::Signal) = push!(arg_signal.children,s)
add_child!(arg_signal,s) = nothing


function store!(sd::SignalData, val)
     sd.propagated = false
     sd.valid = true;
     sd.x = val
end
store!(s::Signal, val) = store!(s.data, val)

value(s::Signal) = value(s.data)
value(sd::SignalData) = sd.x

"""Retrieve the internal state of a `Signal`"""
state(s::Signal) = state(s.state)
state(ref::Ref) = ref.x
state(s::Signal, val) = state(s.state, val)
state(ref::Ref, val) = ref.x = val

propagated(s::Signal) = propagated(s.data)
propagated(sd::SignalData) = sd.propagated
propagated(s::Signal, val::Bool) = propagated(s.data, val)
propagated(sd::SignalData, val::Bool) = sd.propagated = val

valid(s::Signal) = valid(s.data)
valid(sd::SignalData) = sd.valid

Signal(val; kwargs...) = Signal(() -> val; kwargs...)

abstract type Stateless end
function Signal(f::Function, args...; state = Stateless, strict_push = false,
                pull_type = StandardPull, v0 = nothing)
    _state = Ref(state)
    if state != Stateless
        args = (args..., _state)
    end
    sd = SignalData(v0)
    action = PullAction(f, args, pull_type)
    s=Signal(sd, action, _state, strict_push)
    v0 === nothing && s()
    s
end

function Signal(sd::SignalData, action::PullAction, state = Stateless, strict_push = false)
    debug_mode() && finalizer(sd, x-> @async println("signal deleted"))

    !(typeof(state) <: Ref) && (state = Ref(state))
    s = Signal(sd, action, Signal[], Signal[], strict_push, state)
    for arg in action.args
        add_child!(arg,s)
        # isa(arg, Signal) && push!(arg.children, s)
    end
    s
end

import Base.getindex
function getindex(s::Signal)
    value(s)
end

import Base.setindex!
function setindex!(s::Signal, val)
    set_value!(s, val)
end

function set_value!(s::Signal, val)
    invalidate!(s)
    store!(s, val)
end

function invalidate!(s::Signal)
    if valid(s)
        invalidate!(s.data)
        foreach(invalidate!, s.children)
    end
end

function invalidate!(sd::SignalData)
    sd.valid = false
    sd.propagated = false
end

function validate(s::Signal)
    valid(s) && return
    if valid(s.action)
        validate(s.data)
        foreach(validate, s.children)
    end
end

function validate(sd::SignalData)
    sd.propagated = false
    sd.valid = true
end

import Base.show
show(io::IO, s::Signal) = show(io, MIME"text/plain"(), s)

function show(io::IO, ::MIME"text/plain", s::Signal)
    state_str = "\nstate{$(typeof(s.state.x))}: $(s.state.x)"
    state_str = state(s) === Signals.Stateless ? "" : state_str
    valid_str = valid(s) ? "" : "(invalidated)"
    printstyled(io, "Signal"; bold = true,color = 200)
    val = s[] === nothing ? Nothing : s[]
    print(io, "$valid_str $state_str \nvalue: ", val)
end

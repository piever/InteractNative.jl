"""
```
dropdown(options::Associative;
         value = first(values(options)),
         label = nothing,
         multiple = false)
```

A dropdown menu whose item labels will be the keys of options.
If `multiple=true` the observable will hold an array containing the values
of all selected items
e.g. `dropdown(OrderedDict("good"=>1, "better"=>2, "amazing"=>9001))`
"""
function dropdown(::WidgetTheme, options::Associative;
    postprocess = identity,
    label = nothing,
    multiple = false,
    value = multiple ? valtype(options)[] : first(values(options)),
    class = "interact-widget",
    outer = vbox,
    kwargs...)

    extra_attr = Dict{Symbol, Any}(kwargs)
    multiple && (extra_attr[:multiple] = true)

    (value isa Observable) || (value = Observable{Any}(value))
    vmodel = (valtype(options) <: Number) ? "v-model.number" : "v-model"
    args = [Node(:option, key, attributes = Dict(:value=>val)) for (key, val) in options]
    s = gensym()
    attrDict = merge(
        Dict(Symbol(vmodel) => "value"),
        extra_attr
    )

    template = Node(:select, args..., className = class, attributes = attrDict) |> postprocess
    label != nothing && (template = outer(template, wdglabel(label)))
    ui = vue(template, ["value"=>value]);
    primary_obs!(ui, "value")
    slap_design!(ui)
end

"""
`dropdown(values::AbstractArray; kwargs...)`

`dropdown` with labels `string.(values)`
see `dropdown(options::Associative; ...)` for more details
"""
dropdown(T::WidgetTheme, vals::AbstractArray; kwargs...) =
    dropdown(T, OrderedDict(zip(string.(vals), vals)); kwargs...)

"""
```
radiobuttons(options::Associative;
             value::Union{T, Observable} = first(values(options)))
```

e.g. `radiobuttons(OrderedDict("good"=>1, "better"=>2, "amazing"=>9001))`
"""
function radiobuttons(T::WidgetTheme, options::Associative;
    value = first(values(options)), outer = dom"form", kwargs...)

    (value isa Observable) || (value = Observable{Any}(value))
    vmodel = isa(value[], Number)  ? "v-model.number" : "v-model"

    s = gensym()
    btns = [radio(s, key, val, vmodel; kwargs...) for (key, val) in options]

    template = outer(
        btns...
    )
    ui = vue(template, ["value" => value])
    primary_obs!(ui, "value")
    slap_design!(ui)
end

"""
`radiobuttons(values::AbstractArray; kwargs...)`

`radiobuttons` with labels `string.(values)`
see `radiobuttons(options::Associative; ...)` for more details
"""
radiobuttons(T::WidgetTheme, vals::AbstractArray; kwargs...) =
    radiobuttons(T, OrderedDict(zip(string.(vals), vals)); kwargs...)

radio(T::WidgetTheme, s, key, val, vmodel; kwargs...) =
    dom"label"(dom"input[name = $s, type=radio, $vmodel=value, value=$val]"(), key)

"""
`togglebuttons(options::Associative; value::Union{T, Observable})`

Creates a set of toggle buttons whose labels will be the keys of options.
"""
function togglebuttons(T::WidgetTheme, options::Associative; tag = :button, class = "interact-widget", outer = dom"div",
    activeclass = "active", value = medianelement(1:length(options)), label = nothing, kwargs...)

    jfunc = js"""function (num){
        return this.index = num;
    }
    """

    index = isa(value, Observable) ? value : Observable(value)
    vals = collect(values(options))

    btns = [Node(tag,
                 label,
                 attributes=Dict("key" => idx,
                                 "v-on:click"=>"changeValue($idx)",
                                 "v-bind:class" => "['$class', {'$activeclass' : index == $idx}]")
                 ) for (idx, (label, val)) in enumerate(options)]

    template = outer(
        btns...
    )
    value = map(i -> vals[i], index)
    label != nothing && (template = flex_row(wdglabel(label), template))
    ui = vue(template, ["index" => index], methods = Dict(:changeValue => jfunc))
    primary_obs!(ui, value)
    slap_design!(ui)
end

"""
`togglebuttons(values::AbstractArray; kwargs...)`

`togglebuttons` with labels `string.(values)`
see `togglebuttons(options::Associative; ...)` for more details
"""
function togglebuttons(T::WidgetTheme, vals; kwargs...)
    togglebuttons(T::WidgetTheme, OrderedDict(zip(string.(vals), vals)); kwargs...)
end

function tabs(T::WidgetTheme, options::Associative; tag = :li, kwargs...)
    togglebuttons(T::WidgetTheme, options; tag = tag, kwargs...)
end

function tabs(T::WidgetTheme, vals; kwargs...)
    tabs(T::WidgetTheme, OrderedDict(zip(vals, vals)); kwargs...)
end

checkboxes(::WidgetTheme, options::Associative; kwargs...) =
    multiselect(gettheme(), options; typ="checkbox", kwargs...)

toggles(::WidgetTheme, options::Associative; kwargs...) =
    multiselect(gettheme(), options; typ="checkbox", kwargs...)

function multiselect(::WidgetTheme, options::Associative;
    outer = dom"div", value = valtype(options)[], kwargs...)

    (value isa Observable) || (value = Observable(value))

    onClick = js"""
    function (i){
        Vue.set(this.bools, i, ! this.bools[i]);
        vals = [];
        for (var ii = 0; ii < this.bools.length; ii++){
            if (this.bools[ii]) {
                vals.push(this.values[ii]);
            }
        }
        return this.value = vals;
    }
    """

    template = outer(
        entry(gettheme(); kwargs...)
    )
    vals = collect(values(options))
    bools = Observable([val in value[] for val in vals])
    ui = vue(template, ["options"=>options, "bools"=>bools, "values" => vals, "value" => value],
        methods = Dict("onClick" => onClick))
    InteractBase.primary_obs!(ui, "value")
    slap_design!(ui)
end

function entry(::WidgetTheme; typ=typ, class="interact-widget", kwargs...)
    Node(:div, className="field", attributes = Dict("v-for" => "(content, label, idx) in options"))(
        dom"input[type=$typ]"(attributes = Dict("v-model" => "bools[idx]",
                                                "v-on:click" => "onClick(idx)",
                                                "class" => class)),
        dom"label"("{{label}}")
    )
end


function mask(options, values; key=Observable(""), display = "block")
    s = string(gensym())
    onjs(key, js"""
        function (k) {
            var options = document.getElementById($s).childNodes;
            for (var i=0; i < options.length; i++) {
                options[i].style.display = (options[i].getAttribute('key') ==  String(k)) ? $display : 'none';
            }
        }
    """)

    displays = [(option == key[]) ? "display:$display" : "display:none" for option in options]

    dom"div[id=$s]"(
        (dom"div[key=$option, style=$displaystyle;]"(value) for (displaystyle, option, value) in zip(displays, options, values))...
    )
end

mask(pairs::Associative; kwargs...) = mask(keys(pairs), values(pairs); kwargs...)
mask(values; kwargs...) = mask(1:length(values), values; kwargs...)

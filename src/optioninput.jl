_getindex(d, s::AbstractArray) = map(x -> getindex(d, x), s)
_getindex(d, s) = getindex(d, s)

function valueindexpair(value, options)
    vals = map(collect∘values, options)
    dict = map(x -> OrderedDict(zip(x, 1:length(x))), vals)
    f = x -> _getindex(dict[], x)
    g = x -> _getindex(vals[], x)
    ObservablePair(value, f=f, g=g)
end

function vectordictpair(vals::Observable{<:AbstractArray}; process = string)
    f = x -> OrderedDict(zip(process.(x), x))
    g = collect∘values
    ObservablePair(vals, Observable{Associative}(f(vals[])), f=f, g=g)
end

vectordictpair(vals::AbstractArray; kwargs...) =
    vectordictpair(Observable{AbstractArray}(vals); kwargs...)

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
function dropdown(::WidgetTheme, options::Observable{<:Associative};
    attributes=PropDict(),
    label = nothing,
    multiple = false,
    value = multiple ? valtype(options[])[] : first(values(options[])),
    class = nothing,
    className = _replace_className(class),
    style = PropDict(),
    outer = vbox,
    div_select = dom"div.select",
    kwargs...)

    style = _replace_style(style)
    multiple && (attributes[:multiple] = true)

    (value isa Observable) || (value = Observable{Any}(value))
    bind = multiple ? "selectedOptions" : "value"
    option_array = map(x -> [OrderedDict("key" => key, "val" => i) for (i, (key, val)) in enumerate(x)], options)
    s = gensym()
    attrDict = merge(
        Dict(Symbol("data-bind") => "options : options, $bind : value, optionsText: 'key', optionsValue: 'val'"),
        attributes
    )

    className = mergeclasses(getclass(:dropdown), className)
    template = Node(:select; className = className, attributes = attrDict, kwargs...)() |> div_select
    label != nothing && (template = outer(template, wdglabel(label)))
    ui = knockout(template, ["value" => valueindexpair(value, options), "options" => option_array]);
    slap_design!(ui)
    Widget{:dropdown}(ui, value) |> wrapfield
end

"""
`dropdown(values::AbstractArray; kwargs...)`

`dropdown` with labels `string.(values)`
see `dropdown(options::Associative; ...)` for more details
"""
dropdown(T::WidgetTheme, vals::Union{AbstractArray, Observable{<:AbstractArray}}; kwargs...) =
    dropdown(T, vectordictpair(vals).second; kwargs...)

dropdown(T::WidgetTheme, vals::Associative; kwargs...) =
    dropdown(T, Observable{Associative}(vals); kwargs...)

function multiselect(T::WidgetTheme, options::Observable{<:Associative}; label = nothing, typ="radio", wdgtyp=typ,
    value = (typ == "radio") ? first(values(options[])) : valtype(options[])[], kwargs...)

    (value isa Observable) || (value = Observable{Any}(value))

    s = gensym()
    option_array = map(x -> [OrderedDict("key" => key, "val" => i, "id" => "id"*randstring()) for (i, (key, val)) in enumerate(x)], options)
    entry = InteractBase.entry(s; typ=typ, wdgtyp=wdgtyp, kwargs...)
    (entry isa Tuple )|| (entry = (entry,))
    template = Node(:div, className=getclass(:radiobuttons), attributes = "data-bind" => "foreach : options")(
        entry...
    )
    ui = knockout(template, ["value" => valueindexpair(value, options), "options" => option_array])
    (label != nothing) && (scope(ui).dom = flex_row(wdglabel(label), scope(ui).dom))
    slap_design!(ui)
    Widget{:radiobuttons}(ui, value) |> wrapfield
end

"""
`radiobuttons(values::AbstractArray; kwargs...)`

`radiobuttons` with labels `string.(values)`
see `radiobuttons(options::Associative; ...)` for more details
"""
radiobuttons(T::WidgetTheme, vals::Union{AbstractArray, Observable{<:AbstractArray}}; kwargs...) =
    radiobuttons(T, vectordictpair(vals).second; kwargs...)

"""
```
radiobuttons(options::Associative;
             value::Union{T, Observable} = first(values(options)))
```

e.g. `radiobuttons(OrderedDict("good"=>1, "better"=>2, "amazing"=>9001))`
"""
radiobuttons(T::WidgetTheme, options::Associative; kwargs...) =
    radiobuttons(T, Observable{Associative}(options); kwargs...)

radiobuttons(T, options::Observable{<:Associative}; kwargs...) =
    multiselect(T, options; kwargs...)

function entry(T::WidgetTheme, s; className="", typ="radio", wdgtyp=typ, stack=(typ!="radio"), kwargs...)
    className = mergeclasses(getclass(:input, wdgtyp), className)
    f = stack ? Node(:div, className="field") : tuple
    f(
        Node(:input, className = className, attributes = Dict("name" => s, "type" => typ, "data-bind" => "checked : \$root.value, checkedValue: val, attr : {id : id}"))(),
        Node(:label, attributes = Dict("data-bind" => "text : key, attr : {for : id}"))
    )
end

for (wdg, tag, singlewdg, div) in zip([:togglebuttons, :tabs], [:button, :li], [:button, :tab], [:div, :ul])
    @eval begin
        function $wdg(T::WidgetTheme, options::Observable{<:Associative}; tag = $(Expr(:quote, tag)),
            className = getclass($(Expr(:quote, singlewdg)), "fullwidth"),
            activeclass = getclass($(Expr(:quote, singlewdg)), "active"),
            value = medianelement(options[]), label = nothing, kwargs...)

            (value isa Observable) || (value = Observable{Any}(value))

            className = mergeclasses(getclass($(Expr(:quote, singlewdg))), className)

            btn = Node(tag,
                Node(:label, attributes = Dict("data-bind" => "text : key")),
                attributes=Dict("data-bind"=>
                "click: function () {\$root.value(val)}, css: {'$activeclass' : \$root.value() == val, '$className' : true}"),
            )
            option_array = map(x -> [OrderedDict("key" => key, "val" => i) for (i, (key, val)) in enumerate(x)], options)
            template = Node($(Expr(:quote, div)), className = getclass($(Expr(:quote, wdg))), attributes = "data-bind" => "foreach : options")(
                btn
            )

            label != nothing && (template = flex_row(wdglabel(label), template))
            ui = knockout(template, ["value" => valueindexpair(value, options), "options" => option_array])
            slap_design!(ui)
            Widget{$(Expr(:quote, wdg))}(ui, value) |> wrapfield
        end
    end
end

"""
`togglebuttons(options::Associative; value::Union{T, Observable})`

Creates a set of toggle buttons whose labels will be the keys of options.
"""
function togglebuttons(T::WidgetTheme, vals::Associative; kwargs...)
    togglebuttons(T, Observable{Associative}(vals); kwargs...)
end

"""
`togglebuttons(values::AbstractArray; kwargs...)`

`togglebuttons` with labels `string.(values)`
see `togglebuttons(options::Associative; ...)` for more details
"""
function togglebuttons(T::WidgetTheme, vals::Union{AbstractArray, Observable{<:AbstractArray}}; kwargs...)
    togglebuttons(T, vectordictpair(vals).second; kwargs...)
end

function tabs(T::WidgetTheme, vals::Associative; kwargs...)
    tabs(T, Observable{Associative}(vals); kwargs...)
end

function tabs(T::WidgetTheme, vals::Union{AbstractArray, Observable{<:AbstractArray}}; kwargs...)
    tabs(T, vectordictpair(vals, process = identity).second; kwargs...)
end

"""
```
checkboxes(options::Associative;
         value = first(values(options)))
```

A list of checkboxes whose item labels will be the keys of options.
Tthe observable will hold an array containing the values
of all selected items,
e.g. `checkboxes(OrderedDict("good"=>1, "better"=>2, "amazing"=>9001))`
"""
checkboxes(T::WidgetTheme, options::Associative; kwargs...) =
    checkboxes(T, Observable{Associative}(options); kwargs...)

checkboxes(T::WidgetTheme, options::Observable{<:Associative}; kwargs...) =
    Widget{:checkboxes}(multiselect(T, options; typ="checkbox", kwargs...))

"""
`checkboxes(values::AbstractArray; kwargs...)`

`checkboxes` with labels `string.(values)`
see `checkboxes(options::Associative; ...)` for more details
"""
checkboxes(T::WidgetTheme, vals::Union{AbstractArray, Observable{<:AbstractArray}}; kwargs...) =
    checkboxes(T, vectordictpair(vals).second; kwargs...)

"""
`toggles(values::AbstractArray; kwargs...)`

`toggles` with labels `string.(values)`
see `toggles(options::Associative; ...)` for more details
"""
toggles(T::WidgetTheme, vals::Union{AbstractArray, Observable{AbstractArray}}; kwargs...) =
    toggles(T, vectordictpair(vals).second; kwargs...)

"""
```
toggles(options::Associative;
         value = first(values(options)))
```

A list of toggle switches whose item labels will be the keys of options.
Tthe observable will hold an array containing the values
of all selected items,
e.g. `toggles(OrderedDict("good"=>1, "better"=>2, "amazing"=>9001))`
"""
toggles(T::WidgetTheme, options::Associative; kwargs...) =
    toggles(T, Observable{Associative}(options); kwargs...)

toggles(T::WidgetTheme, options::Observable{<:Associative}; kwargs...) =
    Widget{:toggles}(multiselect(T, options; typ="checkbox", wdgtyp="toggle", kwargs...))

function _mask(key, keyvals, values; display = "block")
    s = string(gensym())
    onjs(key, js"""
        function (k) {
            var options = document.getElementById($s).childNodes;
            for (var i=0; i < options.length; i++) {
                options[i].style.display = (options[i].getAttribute('key') ==  String(k)) ? $display : 'none';
            }
        }
    """)

    displays = [(keyval == key[]) ? "display:$display" : "display:none" for keyval in keyvals]

    dom"div[id=$s]"(
        (dom"div[key=$keyval, style=$displaystyle;]"(value) for (displaystyle, keyval, value) in zip(displays, keyvals, values))...
    )
end

function tabulator(options, values; value=1, display = "block", vskip = 1em)

    buttons = togglebuttons(options; value=value)
    key = buttons["index"]
    keyvals = 1:length(options)

    content = _mask(key, keyvals, values; display=display)

    ui = vbox(buttons, CSSUtil.vskip(vskip), content)
    Widget{:tabulator}(ui, scope(buttons), key)
end

tabulator(pairs::Associative; kwargs...) = tabulator(collect(keys(pairs)), collect(values(pairs)); kwargs...)

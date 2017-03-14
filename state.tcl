
import class@  from "class@"
import parser from "state-dex-parser"
proc initState {} {
  uplevel 1 {
    variable Middlewares {}
    namespace eval Containers {}
    namespace eval Items      {}
    namespace eval Entries    {}
    namespace eval Mixins     {}
    class@ create API {}
    class@ create Container {}
    class@ create Entry {}
    class@ create Item {}
    source "./classes/api.tcl"
    source "./classes/container.tcl"
    source "./classes/entry.tcl"
    source "./classes/item.tcl"
    source "./classes/setters_getters.tcl"
    API create state
  }
  catch { rename initState {} }
}

# extendState allows us to extend various parts of our state with new methods or 
# capabilities.  Its purpose is to allow a "plugin-like" system for extending what 
# the state can or does do.
proc extendState { what with args } {
  switch -nocase -- $what {
    api {
      if { $with eq "method" } {
        set args [ lassign $args name withArgs withBody ]
        if { [llength $args] } { set withBody [string cat [list eval [join $args "\;"]] \; $withBody] }
        ::oo::define API method $name $withArgs $withBody
      } else {
        ::oo::define API $what $with {*}$args
      }
    }
  }
}

proc provideMiddleware { name middleware config { mixins {} } } {
  if { [dict exists [set [namespace current]::Middlewares] $name] } {
    throw error "\[state\]: Middleware $name already exists" 
  } else {
    dict for { mixinType mixin } $mixins {
      set mixinClass [::oo::class create Mixins::${name}_${mixinType} $mixin]
      switch -- $mixinType {
        api {
          ::oo::define API mixin -append $mixinClass
          dict unset mixins api
        }
        default { dict set mixins $mixinType $mixinClass }
      }
    }
    dict set [namespace current]::Middlewares $name \
      [dict create \
        config [dict merge [dict create] $config] \
        middleware $middleware \
        mixins $mixins
      ]
  }
}

initState

export default state
export extendState provideMiddleware
::oo::define Container {
  variable KEY READY ENTRIES REQUIRED CONFIG SCHEMA SUBSCRIBED MIDDLEWARES ITEM_REFS
}

::oo::define Container constructor schema {
  #puts "Container [namespace tail [namespace current]] \n Schema: $schema \n "
  set READY    0
  set KEY      [dict get $schema key]
  set REQUIRED [dict get $schema required]
  
  if { [dict exists $schema config] } {
    set CONFIG [dict get $schema config]
    dict unset schema config
  } else { set CONFIG [dict create] }
  set ENTRIES [list]
  set SCHEMA  $schema
  set MIDDLEWARES [dict create]
  set SUBSCRIBED 1
  if { $KEY eq {} } { set KEY "@@S" }
  my CreateItems
  if { [dict exists $SCHEMA default] && $KEY eq "@@S" } {
    # Default is only available for singleton state and it is 
    # applied before middlewares.
    my set [dict get $SCHEMA default]
    dict unset SCHEMA default
  }
  my ApplyMiddlewares
  
}

::oo::define Container destructor {
  puts "[self] is being destroyed!"
}

::oo::define Container method CreateItems {} {
  dict for {itemID params} [dict get $SCHEMA items] {
    my CreateItem $itemID $params
  }
}

::oo::define Container method CreateItem { itemID params } {
  lappend ITEM_REFS [ Item create Items::$itemID [self] $params ]
}

::oo::define Container method CreateEntry { entryID } {
  Entry create Entries::$entryID [self] $entryID $KEY $SCHEMA
  lappend ENTRIES $entryID
}

::oo::define Container method prop { what {value {}} } { 
  if { ! [info exists $what] } {
    throw error "Property $what does not exist in [self]"
  }
  return [set $what]
}

::oo::define Container method RemoveEntries { entryIDs } {
  foreach entryID $entryIDs {
    set ENTRIES [lsearch -all -inline -not -exact $ENTRIES[set ENTRIES ""] $entryID]
  }
}

::oo::define Container method apply_middleware { middlewareID } {
  # Apply a new middleware to a state container.  This may have
  # adverse effects depending on the middleware type.
  set middlewares [dict get? $SCHEMA middlewares]
  if { $middlewareID ni $middlewares } { lappend middlewares $middlewareID }
  dict set SCHEMA middlewares $middlewares
  my ApplyMiddlewares
}

::oo::define Container method ApplyMiddlewares {} {
  set onregisters [list]
  if { [dict exists $SCHEMA middlewares] } {
    set MiddlewareRegistry [set [namespace parent [namespace parent]]::Middlewares]
    foreach middlewareID [dict get $SCHEMA middlewares] {
      if { [info command middlewares::$middlewareID] ne {} } { 
        # Middleware alraedy applied.
        continue
      }
      set Middleware [dict get $MiddlewareRegistry $middlewareID]
      set MiddlewareClass  [dict get $Middleware middleware]
      set MiddlewareConfig [dict get $Middleware config]
      set MiddlewareMixins [dict get $Middleware mixins]
      
      set instance [$MiddlewareClass create middlewares::$middlewareID [self] $CONFIG $MiddlewareConfig]
      set methods [info class methods $MiddlewareClass]
      
      if { "onSnapshot" in $methods } {
        dict set MIDDLEWARES onSnapshot $middlewareID $instance
      }
      
      if { [dict exists $MiddlewareMixins container] } {
        ::oo::objdefine [self] mixin -append [dict get $MiddlewareMixins container]
      }
      
      if { [dict exists $MiddlewareMixins item] } {
        set mixin [dict get $MiddlewareMixins item]
        foreach ref $ITEM_REFS[set ITEM_REFS ""] { ::oo::objdefine $ref mixin -append $mixin } 
      }
      
      if { "onRegister" in $methods } {
        lappend onregisters [list $middlewareID $instance]
      }
    }
  }
  foreach middleware $onregisters { 
    lassign $middleware middlewareID instance
    {*}$instance onRegister $SCHEMA $CONFIG
  }
  set READY 1
}

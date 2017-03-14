
::oo::define API method register {localID args} {
	try {
		if {[state exists $localID]} {
			::onError "State $localID Already Exists" {} "
				You can not create a State Container which has already been 
				registered (${localID})
			"	
			return
		}
		set schema [parser state $localID {*}$args]
		tailcall Container create [namespace parent]::Containers::${localID} $schema
	} on error {result options} {
		puts "Register Error: $result"
		puts "\n $options"
		return
	}
}

::oo::define API method exists { ref {strict 0} } {
	tailcall namespace exists $ref
}

::oo::define API method ref {localID} {
	set ref [namespace parent]::Containers::${localID}
	if { ! [my exists $ref] } {
		throw error "State $localID has not yet been registered"	
	}
	return $ref
}

# ::oo::define API method key {localID {ref {}}} {
# 	if { $ref eq {} } { set ref [state ref $localID] }
# 	return [$ref prop key]
# }

# ::oo::define API method prop {localID prop {ref {}}} {
# 	if { $ref eq {} } { set ref [state ref $localID] }
# 	return [$ref prop $prop]
# }

::oo::define API method set {localID args} {
	set ref [my ref $localID]
	foreach updateDict $args { $ref set $updateDict }
}

# state get LocalID <?List?>$entryIDs <?List?>$itemIDs
::oo::define API method get {localID args} {
	tailcall [my ref $localID] get VALUES {*}$args
}

::oo::define API method apply_middleware { localID middlewareID } {
	set ref [my ref $localID]
	$ref apply_middleware $middlewareID
}


::oo::define API method push {localID entryID args} {
	set updateDict {}
	set ref [state ref $localID]
	set key [state key $localID $ref]
	if { [state prop $localID singleton $ref] } {
		if { $entryID ne {} } { set args [concat $entryID $args] }
		set entryID "SINGLETON"
	} else {
		dict set updateDict $key $entryID
	}
	foreach arg $args {
		lassign $arg var as default
		if { $as eq {} } { set as $var }
		upvar 1 $as val
		if { ! [info exists val] || $val eq {} } {
			set val $default
		}
		dict set updateDict $as $val
	}
	return [state set $localID $updateDict]
}


::oo::define API method previous {localID args} {
	tailcall [my ref $localID] get PREV {*}$args
}

::oo::define API method pull {localID {entryID {}} args} {
	set ref [state ref $localID]
	if {[$ref prop singleton]} {
		if {$entryID ne {} && $entryID ne "SINGLETON"} {
			set args [concat [list $entryID] $args]
		}
		set singleton true
		set entryID {}
	} else { set singleton false }
	set response [$ref get $entryID current {*}$args]
	if {!$singleton} {
		dict pull response [list $entryID tempDict]
	} else {
		set tempDict $response
	}
	if {$args eq {}} {
		set updateDict $tempDict
	} else {
		foreach arg $args {
			lassign $arg var as default
			if {$as eq {}} { set as $var }
			upvar 1 $as val
			set val [dict get? $tempDict $var]
			dict set updateDict $as $val
		}
	}
	return $updateDict
}

# ::oo::define API method keys {localID} {
# 	set ref [state ref $localID]
# 	if {[state prop $localID singleton $ref]} {
# 		return [dict keys [$ref get $localID]]
# 	} else {
# 		return [dict keys [$ref prop refs]]
# 	}
# }

# ::oo::define API method items {localID entryID} {
# 	set ref [state ref $localID]
# 	if {[state prop $localID singleton $ref]} {
# 		return [state keys $localID]	
# 	} else {
# 		return [dict keys [dict get? [$ref get $entryID "current"] $entryID] ]
# 	}
# }

# ::oo::define API method values {localID {entryIDs {}} args} {
# 	set ref [state ref $localID]
# 	if {[state prop $localID singleton $ref]} {
# 		return [dict values [$ref get $localID]]
# 	} else {
# 		set data [$ref values $entryIDs "current" $args]
# 		return $data
# 	}
# }


::oo::define API method delete {localID} {
	tailcall [my ref $localID] destroy
}

::oo::define API method remove {localID args} {
	tailcall [my ref $localID] remove {*}$args
}

::oo::define API method removeIf {localID args} {
	set entryIDs [my query $localID {*}$args]

	#puts "REMOVING ENTRIES DUE TO REMOVE IF QUERY: $entryIDs"
	if { $entryIDs ne {} } { my remove $localID $entryIDs }
	return $entryIDs
}

::oo::define API method commands {} {
	return [info class methods API]
}

::oo::define API method containers {{trim 1}} {
	set containers [info class instances Container]
	return [ expr { [string is true -strict $trim] \
		? [string map [list [namespace parent]::Containers:: {}] $containers] \
		: $containers
	}]
}

::oo::define API method json {localID args} {
	tailcall [my ref $localID] json VALUES {*}$args
}

# ::oo::define API method serialize {localID {what {}} {entryIDs {}} {itemIDs {}}} {
# 	set ref [state ref $localID]
# 	if {[isTrue [state empty $localID $ref]]} { return }
# 	return [$ref toJSON $entryIDs $what $itemIDs]
# }

::oo::define API method query {localID args} {
	set ref [my ref $localID]
	set query [parser query $localID {*}$args]
	puts "Query"
	puts $query
	#set response [$ref query $query]
	#return $response
}

# ::oo::define API method getIndex {localID indexKey} {
# 	set ref [state ref $localID]
# 	if {[isTrue [state empty $localID $ref]]} { return }
# 	set index [$ref getIndex $indexKey]
# 	return $index
# }

# ::oo::define API method subscriptions { {localID {}} {pattern *} } {
# 	if {$localID ne {}} {
# 		set subscriptions [state prop $localID subscriptions]
# 		dict pull subscriptions subscriptions
# 		set subscriptions [dict values [dict withKey $subscriptions ref]]
# 		if {$pattern ne {*}} {
# 			set pattern [string map {"Subscriptions::" ""} $pattern]
# 			set pattern Subscriptions::${pattern}
# 			set subscriptions [lsearch -all -inline $subscriptions $pattern]
# 		}
# 	} else {
# 		set subscriptions [info commands Subscriptions::${pattern}]
# 	}
# 	return $subscriptions
# }



::oo::define API method unsubscribe { {localID {}} {pattern {}} } {
	if {$localID eq {} && $pattern eq {}} { throw error "Local ID OR Pattern Required" }
	if {$localID ne {} && $pattern eq {}} {
		~ "
			----------------
				No Pattern Defined when trying to Remove from State $localID
				
				Did you mean to supply a pattern to \[state unsubscribe\] ?
				
				Tip:  If you want to unsubscribe from all of ${localID}'s subscriptions
					  you can use \[state unsubscribe $localID *\]
			----------------
		"
		return
	}
	set subscriptions [state subscriptions $localID $pattern]
	foreach subscription $subscriptions {
		try {
			$subscription destroy
		} on error {result options} {
			::onError $result $options "While attempting to unsubscribe from $subscription"
		}
	}
}

::oo::define API method sync {localID} {
	set ref [state ref $localID]
	if { [ isTrue [$ref prop datastream] ] } {
		set json [$ref syncRefresh]
		datastream database update [dict create \
			$localID $json
		]
	}
}
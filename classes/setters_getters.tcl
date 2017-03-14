import { { lhas } } from "list-tools"

## Setters & Getters
# 	These commands are responsible for modifying or reading from the state
#		in some way.  Each command is passed through the state, routed as necessary
#		based on the arguments received.  
#
#		We need to gather special information when we have subscriptions to fufill.
#		When we are working with a subscribed state, the snapshot variable will be 
#		passed down with the execution of the command.  It will be modified to generate
#		an overall "snapshot" of the modification that was made.  
#
#		#		Snapshots
#	
#		A snapshot provides a detailed view of what occurred during the course of the 
#		given action.  This is used by our subscription evaluator to efficiently determine
#		if any matching subscriptions should be triggered.
#
##	State Set Commands

::oo::define Container method set data {
	if { $KEY eq "@@S" || [dict exists $data $KEY] } {
		if { $KEY eq "@@S" } {
			set stateKeyValue "@@S"
		} else {
			set stateKeyValue [dict get $data $KEY]
		}
		if { $READY && [dict exists $MIDDLEWARES onSnapshot] } {  
			# We only create a snapshot when the state has active middlewares that 
			# are expecting a snapshot.
			set snapshot [dict create \
				keyID    $KEY \
				keyValue $stateKeyValue \
				set      [dict keys $data] \
				created  [list] \
				changed  [list] \
				keys     [list] \
				removed  [list] \
				items    [dict create \
					$KEY [dict create value $stateKeyValue prev $stateKeyValue]
				]
			]
		}
		catch { dict unset data $KEY }
		# Does the entry already exist? If not, create it!
		if { $stateKeyValue ni $ENTRIES } {
			if { [info exists snapshot] } {
				dict lappend snapshot created $KEY
			}
			my CreateEntry $stateKeyValue 
		}
		Entries::$stateKeyValue set $data
		if { [info exists snapshot] } {
			# If we have a snapshot we know that we need to evaluate middlewares.
			if { ( [dict exists $CONFIG stream] && [dict get $CONFIG stream] )
				|| ! [ string equal [dict get $snapshot changed] {} ]
				|| ! [ string equal [dict get $snapshot created] {} ]
				|| ! [ string equal [dict get $snapshot removed] {} ]
			} {
				# Each Middleware will have its "onSnapshot" method called with the snapshot
				# value. This only occurs by default if the snapshot changes.
				foreach middleware [dict values [dict get $MIDDLEWARES onSnapshot]] {
					$middleware onSnapshot $snapshot
				}
			}
		}
		return
	} else {
		throw error "You may only set Keyed stated when the given key is within your update snapshot! Expected $KEY within: $data"
	}
}

::oo::define Container method sets states {
	foreach entry $states { my set $entry }
}

::oo::define Entry method set data {
	upvar 1 snapshot snapshot
	if { $ITEMS eq {} } {
		# First time that we are setting this entry.  Check required values.
		set required [{*}$CONTAINER prop REQUIRED]
		set keys     [dict keys $data]
		if { ! [lhas $required $keys] } {
			throw error "Required items are missing while setting $ENTRY_ID - $keys vs $required"
		}
	}
	# Iterate through the received snapshot and set each of the items held within.
	dict for { k v } $data {
		if { ! [ ${ITEMS_PATH}::$k set $ENTRY_ID $v ] } {
			if { $k in $ITEMS } { set ITEMS [lsearch -all -inline -not -exact $ITEMS $k] }
		} else {
			if { $k ni $ITEMS } { lappend ITEMS $k }
		}
	}
	if { [info exists snapshot] } {
		# The actual entry key value
		
		# All the current items this entry has
		dict set snapshot keys [concat $KEY $ITEMS]
		# When we need to send commands to the entry later
		dict set snapshot refs entry [self]
	}
	return
}

::oo::define Item method set {key value {force 0}} {
	upvar 1 snapshot snapshot
	if { [dict exists $VALUES $key] } {
		set prev [dict get $VALUES $key]
	} elseif { $value ne {} } { 
		set prev {} 
	} else { return 0 }
	if { $value eq {} } {
		# Setting an item to a value of {} will remove it from the state.
		# an empty value shall be treated as "null" for our purposes and may 
		# be further interpreted by the higher-order-procedures.
		# -- Still have to determine if this is the appropriate logic to use.
		if { $REQUIRED && ! $force } { throw error "$key is a required item but you tried to remove it in [self]" }
		if { [dict exists $VALUES $key] } { dict unset VALUES $key }
		if { [dict exists $PREV $key] }   { dict unset PREV   $key }
		if { [info exists snapshot] } {
			dict lappend snapshot removed $ITEM_ID	
			dict set snapshot set [lsearch -all -inline -not -exact [dict get $snapshot set] $ITEM_ID]
			dict set snapshot items $ITEM_ID [dict create value {} prev $prev]
		}
		return 0
	} elseif { ! [ my validate value ] } {
		throw error "$key $value does not match the schema: $TYPE"
  } else {
  	if { [info exists snapshot] } { 
  		if { $prev eq {} } { 
  			dict lappend snapshot created $ITEM_ID 
  			dict set snapshot items $ITEM_ID [dict create value $value prev {} ]
  		} else {
  			dict set snapshot items $ITEM_ID [dict create value $value prev $prev]
  			if { [string equal $prev $value] } { return 1 } else {
  				dict lappend snapshot changed $ITEM_ID
  			}
  		}
		}
  	dict set VALUES $key $value
		dict set PREV   $key $prev
  }
  return 1
}

##	State Get Commands

::oo::define Container method get {op args} {
	set value {}
	if { $KEY eq "@@S" } {
		set args [lassign $args items]
		if { [info command Entries::$KEY] ne {} } {
			set value [Entries::$KEY get $op $items {*}$args]
			dict unset value $KEY
		}
	} elseif { $ENTRIES ne {} } {
		set args [lassign $args entries items]
		set entries [expr { $entries eq {} ? $ENTRIES : $entries }]
		foreach entry $entries[set entries ""] {
			if { $entry in $ENTRIES } {
				dict set value $entry [Entries::$entry get $op $items {*}$args]
			}
		}
	} else { return }
	return $value
}

::oo::define Entry method get {op {items {}} args} {
	set items [expr { $items eq {} ? $ITEMS : $items }]
	set value [dict create $KEY $ENTRY_ID]
	foreach itemID $items {
		if { $itemID ni $ITEMS } { continue }
		dict set value $itemID \
			[ ${ITEMS_PATH}::$itemID get $op $ENTRY_ID {*}$args ]
	}
	return $value
}

::oo::define Item method get {op entryID args} {
	if { [string equal $op "SNAPSHOT"] } {
		tailcall dict create value [dict get $VALUES $entryID {*}$args] prev [dict get $PREV $entryID {*}$args]
	} else {
		tailcall dict get [set $op] $entryID {*}$args
	}
}

## JSON / Serialization Commands

::oo::define Container method json {op args} {
	set json [yajl create #auto]
	try {
		$json map_open
		if { $KEY eq "@@S" } {
			set args [lassign $args items]
			set value [Entries::$KEY json $json $op $items {*}$args]
		} else {
			set args [lassign $args entries items]
			set entries [expr { $entries eq {} ? $ENTRIES : $entries }]
			foreach entry $entries {
				$json map_key $entry map_open
				if { $entry in $ENTRIES } {
					Entries::$entry json $json $op $items {*}$args
				}
				$json map_close
			}
		}
		$json map_close
		set body [$json get]
		$json delete
	} on error {result options} {
		# If we encounter an error, we need to conduct some cleanup, then we throw
		# the error to the next level.
		catch { $json delete }
		throw error $result
	}
	return $body
}

::oo::define Entry method json {json op items args} {
	set items [expr { $items eq {} ? $ITEMS : $items }]
	foreach itemID $items {
		${ITEMS_PATH}::$itemID json $json $op $ENTRY_ID {*}$args
	}
	return
}

::oo::define Item method json {json op entryID args} {
	my serialize $json $ITEM_ID [my get $op $entryID] {*}$args
}

## Remove Commands

::oo::define Container method remove {args} {
	if { $KEY eq "@@S" } {
		set args [lassign $args items]
		Entries::$KEY remove $items {*}$args
	} else {
		set args [lassign $args entries items]
		set entries [expr { $entries eq {} ? $ENTRIES : $entries }]
		foreach entry $entries {
			if { $entry in $ENTRIES } {
				if { $items eq {} } {
					Entries::$entry destroy
				} else {
					Entries::$entry remove $items {*}$args
				}
			}
		}
	}
	return
}

::oo::define Entry method remove {items args} {
	foreach itemID $items {
		${ITEMS_PATH}::$itemID set $ENTRY_ID {}
		set ITEMS [lsearch -all -inline -not -exact $ITEMS[set ITEMS ""] $itemID]
	}
}



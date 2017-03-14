# State Entry
#		State Entries are responsible for coordinating a set of items which 
#		are located within an Item class.  They are responsible for aggregating
#		the denormalized data when required.
#
::oo::define Entry {
	variable KEY
	variable CONTAINER
	variable ENTRY_ID
	variable ITEMS
	variable ITEMS_PATH
}

::oo::define Entry constructor { container entryID key schema } {
	set CONTAINER  $container
	set KEY        $key
	set ENTRY_ID   $entryID
	set ITEMS      [list]
	set ITEMS_PATH [namespace parent [namespace parent]]::Items
}

::oo::define Entry destructor {
	foreach itemID $ITEMS {
		${ITEMS_PATH}::$itemID set $ENTRY_ID {} 1
	}
	{*}$CONTAINER RemoveEntries [list $ENTRY_ID]
}
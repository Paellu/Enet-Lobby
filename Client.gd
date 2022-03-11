extends Lobby

func _on_option_changed(value):
#	if typeof(value) == TYPE_INT:
#		for client in peers:
#			header_limit.rset_id(client, "selected", value)
#
#		var intent = {
#			"action" : ACTION.REFRESH, 
#			"room_number" : info.room_number,
#			"room_limit" : header_limit.selected +2
#		}
#
#		rpc_id(peer.TARGET_PEER_SERVER, "report", intent)
		
	# room Alias text_changed
	if typeof(value) == TYPE_STRING:
		if not value.is_valid_filename():
			return
		
		info.name = value
		main.set_text("Connected as %s (%s)" % [value, info.id])
		
		if info.room_number == tree.get_network_unique_id():
			var intent = {
				"action" : ACTION.REFRESH,
				"peer_info" : info,
			}
				
			rpc_id(peer.TARGET_PEER_SERVER, "report", intent)
	
	# Header_select button toggle
	if typeof(value) == TYPE_BOOL:
		var intent = {
			"action" : ACTION.OPEN, 
			"limit": header_limit.selected +2
		}
		rpc_id(peer.TARGET_PEER_SERVER, "report", intent)

""" Person Functions"""
func person_entered(server_room, name_tag):
	var new_person = person.instance()
	var peer_info = server_room.peers[name_tag]
	var intent = {}
	
	crowd.add_child(new_person)
	
	new_person.set_name("Person_%s" % name_tag)
	new_person.set_network_master(name_tag)
	new_person.set_alias(peer_info.name)
	
	# Host of this room
	if server_room.host == tree.get_network_unique_id():
		# When adding host as a person
		if new_person.is_network_master(): #name_tag == tree.get_network_unique_id()
			new_person.shoe.connect("pressed", self, "room_exited")
			intent = {"action" : ACTION.CLOSE, "peer" : info.room_number}
		# When adding a client person in host's room
		else:
			intent = {"action" : ACTION.BOUNCE, "peer" : peer_info.id}
			new_person.shoe.set_text("Kick")
	# Client in this room
	else:
		# When adding this client's person
		if new_person.is_network_master():
			intent = {"action" : ACTION.EXIT, "room_number" : info.room_number}
			new_person.shoe.connect("pressed", self, "room_exited")
		# When adding another client's or host's person
		else:
			new_person.shoe.set_disabled(true)
	
	var args = [peer.TARGET_PEER_SERVER, "report", intent]
	new_person.shoe.connect("pressed", self, "rpc_id", args)
	new_person.alias.connect("text_entered", self, "_on_option_changed")
	
	# Not really elegant but if this 
	# person node is not the network master
	
	# Set options of master_node peer on newly added person
	# So when that peer now enters this room they know what was going on
	# Since this is a server-client setup it'd be better to keep a log
	# of all activity, and this is just a shorthand of that
			
	# Then you cant toggle the new_person options
	
	if not new_person.is_network_master():
		if crowd.has_node("Person_%s" % tree.get_network_unique_id()):
			var master_node = crowd.get_node("Person_%s" % tree.get_network_unique_id())
			master_node.set_options_on(name_tag)
			
		new_person.alias.set_editable(false)
		new_person.options.set_disabled(true)
		new_person.check.set_disabled(true)
		
		# Record peer for future option changes
		peers[name_tag] = peer_info
			
	return new_person


""" Room Functions"""

func room_created(room_number):
	var new_room = room.instance()
	
	building.add_child(new_room)
	
	new_room.set_network_master(room_number)
	
	if room_number == tree.get_network_unique_id():
		new_room.hide()
	
	var intent = {
		"action" : ACTION.ENTER, 
		"room_number" : room_number
	}
	
	var args = [peer.TARGET_PEER_SERVER, "report", intent]
	new_room.door.connect("pressed", self, "rpc_id", args)
	
	return new_room

remote func room_entered(room_number):
	info.room_number = room_number
	
	#header_limit.set_disabled(true)
	header_amount.hide()
	header_limit.hide()
	header_new.hide()
	
	building.hide()
	crowd.show()

remote func room_exited():
	header_limit.set_disabled(false)
	header_name.set_text("Rooms")
	header_amount.set_text("Has")
	header_amount.show()
	header_limit.show()
	header_new.show()
	building.show()
	crowd_clear()
	
	peers.clear()
	info.room_number = 0

remote func rooms_reset(server_rooms):
	# Ignore unless recieved from server peer
	# May be wiser to set-up puppet-master relations
	if tree.get_rpc_sender_id() != peer.TARGET_PEER_SERVER:
		return
		
	# Ignore if data up-to-date
	if server_rooms.hash() == peer_rooms.hash():
		return
		
	# remove old rooms
	for room_number in peer_rooms:
		if not room_number in server_rooms:
			if building.has_node("Room_%s" % room_number):
				building.remove_child(building.get_node("Room_%s" % room_number))
	
	for room_number in server_rooms:
		# add new rooms
		var current_room
		if not room_number in peer_rooms:
			current_room = room_created(room_number)
		else:
			# Skip if data up-to-date
			if server_rooms[room_number].hash() == peer_rooms[room_number].hash():
				continue
			# get reference
			current_room = building.get_node("Room_%s" % room_number)
		
		# if in that room
		if info.room_number == room_number:
			header_name.set_text(server_rooms[room_number].name)
			header_amount.set_text("Has:" + str(server_rooms[room_number].inner))
			#header_limit.set_text(str(server_rooms[room_number].limit))
			
			# remove old_persons
			for person in crowd.get_children():
				if not person.name.to_int() in server_rooms[room_number].peers:
					crowd.remove_child(person)
			
			# Create Life
			for peer_id in server_rooms[room_number].peers:
				if not crowd.has_node("Person_%s" % peer_id):
					person_entered(server_rooms[room_number], peer_id)
		
		# update room display
		# Easier way to deal with this is to setup Master-Puppet relationships
		current_room.set_inner(server_rooms[room_number].inner)
		current_room.set_limit(server_rooms[room_number].limit)
		current_room.set_alias(server_rooms[room_number].name)
		current_room.set_name("Room_%s" % room_number)
		
		if server_rooms[room_number].inner == server_rooms[room_number].limit:
			current_room.door.set_disabled(true)
		else:
			current_room.door.set_disabled(false)
		
	# Sync rooms
	peer_rooms = server_rooms

func room_close():
	if building.has_node("Room_%s" % str(info.room_number)):
		var current_room = building.get_node("Room_%s" % info.room_number)
		building.remove_child(building.get_node(current_room))

""" Network Manager Functions """

# Only for clients (not server).
func _server_disconnected():
	connection_close()
	crowd_clear()
	building_clear()
	peers.clear()
	
	# Switch to Into
	main.reset()

# Only for clients (not server).
func _connection_success():
	main.save_config() #Save last connected IP address
	
	var id = str(tree.get_network_unique_id())
	main.set_text("Connected as %s (%s)" % [info.name, id])
	
	# Room related signals
	
	if not header_new.is_connected("toggled", self, "_on_option_changed"):
		header_new.connect("toggled", self, "_on_option_changed")
		#header_new.connect("pressed", self, "room_entered", [tree.get_network_unique_id()])
	header_new.show()

# Only for clients (not server).
func _connection_failed():
	main.reset()

func connection_join():
	if intro_name.text.empty():
		intro_name.grab_focus()
		return
	connection_close() # Clear any previous connection attempts
		
	peer.create_client(LAN.ADDRESS, LAN.PORT)
	tree.set_network_peer(peer)
	
	# Switch to lobby Pending
	intro.hide()
	
	info.name = intro_name.text
	info.id = tree.get_network_unique_id()
	info.password = "********"
	info.email = "someone@someemail.com"
	info.location = "motherearth"
	info.room_number = 0

func _ready():
	# Connect all the callbacks related to networking for clients.
	tree.connect("server_disconnected", self, "_server_disconnected")
	tree.connect("connected_to_server", self, "_connection_success")
	tree.connect("connection_failed", self, "_connection_failed")
	
	connection_join()
	
	main.set_text("Connecting . . . .")

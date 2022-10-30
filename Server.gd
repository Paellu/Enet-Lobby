extends Lobby

var max_peers = 15

var blacklist = []
var backlog = []

""" Network Remote Functions """
remote func report(intent):
	var peer_id = tree.get_rpc_sender_id()
	
	if peer_id != peer.TARGET_PEER_BROADCAST:
		if blacklist.has(peer.get_peer_address(peer_id)):
			peer.disconnect_peer(peer_id, true)
			return
			
		# Log intent
		backlog.append(
			[
				peer_id,
				peer.get_peer_address(peer_id), 
				"%s-%s-%s" % OS.get_date().values().slice(0, 2),
				"%s:%s:%s" % OS.get_time().values(),
				ACTION.keys()[ACTION.values().find(intent.action)]
			]
		)
		print(backlog.back())
		
	if not intent is Dictionary \
	or not intent.has("action") \
	or not intent.action in ACTION.values():
		
		blacklist.append(peer.get_peer_address(peer_id))
		peer.disconnect_peer(peer_id, true)
		return
	
	match intent.action:
		# New peer connected
		ACTION.IDENTIFY:
			var new_person = person.instance()
			
			peers[peer_id] = intent.peer_info
			
			crowd.add_child(new_person)
			new_person.set_network_master(peer_id)
			
			new_person.set_name("Person_%s" % peer_id)
			new_person.alias.set_text(peers[peer_id].name)
			new_person.alias.set_editable(false)
			
			new_person.check.hide()
			new_person.options.hide()
			
			new_person.shoe.connect("pressed", peer, "disconnect_peer", [peer_id, true])
			new_person.shoe.set_text("Kick")
		
			header_amount.set_text("Has:" + str(peers.size()))
			
		# Host opened a New Room
		ACTION.OPEN:
			var new_room = {}
			new_room.name = "%s's room" % peers[peer_id].name
			new_room.host = peer_id
			new_room.limit = intent.limit
			new_room.peers = {}
			
			# The info stored in the peer_rooms needs to be stripped of sensitive
			# information like passwords, email addresses and any meta data
			var peer_info = {
				"name" : peers[peer_id].name,
				"id" : peer_id
			}
			
			new_room.peers[peer_id] = peer_info
			new_room.inner = new_room.peers.size()
			
			peer_rooms[peer_id] = new_room
			peers[peer_id].room_number = peer_id
			
			rpc_id(peer_id, "room_entered", new_room.host)
			
		# Peer entered a room
		ACTION.ENTER:
			var peer_room = peer_rooms[intent.room_number]
			
			# This should never happen because of line 198 in Client.gd
			if peer_room.inner == peer_room.limit:
				return
			
			# The info sent to the host peer needs to be stripped of sensitive
			# information like passwords, email addresses and any other meta data
			var peer_info = {
				"name" : peers[peer_id].name,
				"id" : peer_id
			}
			
			peer_room.peers[peer_id] = peer_info
			peer_room.inner = peer_room.peers.size()
			
			peers[peer_id].room_number = intent.room_number
			
			rpc_id(peer_id, "room_entered", intent.room_number)
			
		# Peer Exited a room
		ACTION.EXIT:
			var peer_room = peer_rooms[intent.room_number]
			
			peer_room.peers.erase(peer_id)
			peer_room.inner = peer_room.peers.size()
			peers[peer_id].erase("room_number")
			
		# Host closed the room
		ACTION.CLOSE:
			var peer_room = peer_rooms[intent.peer]
			if intent.peer != peer_room.host:
				return
				
			# Remove host
			peer_room.peers.erase(intent.peer)
			
			if not peer_room.peers.empty(): # Host left with clients inside (how rude)
				# The intelligent thing to do here would be kick all clients from the room
				# and leave em bitter and angry at the host for going AWOL
				# But will do something a little more generous by creating a new room and 
				# promoting the next client in line as host. Know that all options get reset
				
				# ToDo: Record and pass options for each peer in old room to new room
				# pretty easy to accomplish since the server already has a person node rep
				# most servers usually don't have gui like this one so left undone
				
				var new_host = peer_room.peers.keys().front()
				var new_room = {}
				new_room.name = "%s's room" % peers[new_host].name
				new_room.host = new_host
				new_room.limit = peer_rooms[intent.peer].limit
				new_room.peers = peer_rooms[intent.peer].peers
				new_room.inner = new_room.peers.size()
				
				peer_rooms[new_host] = new_room
				
				for abandoned in new_room.peers:
					rpc_id(abandoned, "room_exited")
					rpc_id(abandoned, "room_entered", new_host)
					
			peers[intent.peer].erase("room_number")
			peer_rooms.erase(intent.peer)
		
		# Peer changed the room of his/her/they/their info somehow
		ACTION.REFRESH:
			if intent.has("peer_info"):
				peers[peer_id] = intent.peer_info
				if peer_id in peer_rooms:
					peer_rooms[peer_id].name = "%s's room" % peers[peer_id].name
				if peers[peer_id].has("room_number"):
					peer_rooms[peers[peer_id].room_number].peers[peer_id].name = peers[peer_id].name
				
#			if intent.has("room_limit"):
#				var peer_room = peer_rooms[peer_id]
#				peer_room.inner = peer_room.peers.size()
#				peer_room.limit = intent.room_limit
			
		# Host kicked peer out of their room
		ACTION.BOUNCE:
			var peer_room = peer_rooms[peer_id]
			
			peer_room.peers.erase(intent.peer)
			peer_room.inner = peer_room.peers.size()
			peers[peer_id].erase("room_number")
			rpc_id(intent.peer, "room_exited")
		_:
			print("Unknown intent received from %s" % peer_id)
			
	# Sync and Update room_list on all client peers
	rpc("rooms_reset", peer_rooms)

""" Network Manager Functions """

func _peer_disconnected(id):
	# If in a room as a client
	if peers.has(id):
		if peers[id].has("room_number"):
			if peer_rooms.has(peers[id].room_number):
				peer_rooms[peers[id].room_number].peers.erase(id)
				peer_rooms[peers[id].room_number].inner -= 1
				
	# If in a room as a host
	if peer_rooms.has(id):
		if not peer_rooms[id].peers.empty():
			var intent = {
				"action" : ACTION.CLOSE, 
				"peer" : id
			}
			report(intent)
		else:
			peer_rooms.erase(id)
			
	._peer_disconnected(id)
	
	# Sync and Update room_list on all client peers
	rset("peer_rooms", peer_rooms)
	header_amount.set_text("Has:" + str(peers.size()))
		
	backlog.append(
		[
			id,
			peer.get_peer_address(id), 
			"%s-%s-%s" % OS.get_date().values().slice(0, 2),
			"%s:%s:%s" % OS.get_time().values(),
			ACTION.keys()[ACTION.values().find(ACTION.DISCONNECT)]
		]
	)
	print(backlog.back())

func connection_host():
	connection_close() # Clear any previous connection attempts
	
	if not address.text.is_valid_ip_address():
		main.reset()
		return
		
	#peer.set_bind_ip(address.text) # Set host address
	var err = peer.create_server(LAN.PORT, LAN.MAX_PEERS) # Create server with max peers.
	if err != OK:
		if err == ERR_ALREADY_IN_USE:
			push_error("Can't host, address in use.")
		elif err == ERR_CANT_CREATE:
			push_error("Enter valid host IP address")
		main.reset()
		return
		
	tree.set_network_peer(peer)
	
	# Set only lobby this node's network master to Server
	# Done Automatically just a reminder that this happens
	# set_network_master(tree.get_network_unique_id(), false)
	
	# Switch to lobby
	intro.hide()
	header.show()
	header_new.hide()
	header_amount.set_text("Has: 0")
	header_name.set_text("Connected Peers")
	header_limit.set_text("Limit: " + str(LAN.MAX_PEERS))
	header_limit.set_disabled(true)
	
	main.set_text("%s Server @ %s" % [intro_name.text, LAN.ADDRESS])

# A little house keeping for peers that disconnect in an unusal way
# Unlikely to happen but keeps the server accurate
func _process(_delta):
	if tree.get_network_connected_peers().size() < peers.size():
		for bad_id in peers:
			if not bad_id in tree.get_network_connected_peers():
				_peer_disconnected(bad_id)

func _ready():
	connection_host()

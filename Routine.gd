extends Button

onready var address = get_parent().get_node("Address")
onready var auto_connect = get_parent().get_node("Auto")
onready var tree = get_tree()
onready var main = tree.get_current_scene()

var udp_client := PacketPeerUDP.new()
var udp_server := UDPServer.new()
var udp_server_found = false
var udp_requests = 5
var error = OK

var deltaTime = 0

func _search_pressed():
	#reset
	udp_server.stop()
	udp_server_found = false
	udp_requests = 5
	
	#search for server address
	udp_client.set_broadcast_enabled(true)
	error = udp_client.set_dest_address("255.255.255.255", 9899)
	if error != OK:
		print("udp_client set_dest_address error code %s" % error)
	
	main.set_text("Searching for Host")
	set_process(true)

func _ready():
	call("connect", "pressed", self, "_search_pressed")
	set_process(false)

func _process(delta):
	deltaTime += delta
	if deltaTime >= 2.0:
		deltaTime = 0
		udp_requests -= 1
		if udp_requests == 0:
			#shutdown client and start as server if no server found after 10 seconds
			udp_client.close()
			if auto_connect.is_pressed():
				main._host_pressed()
				error = udp_server.listen(9899, "255.255.255.255")
				if error != OK:
					print("udp_server listen error code %s" % error)
			else:
				main.set_text("Host not Found!!!")
				set_process(false)
					
	#Server Side - client wait
	if udp_server.is_listening():
		error = udp_server.poll()
		if error != OK:
			print("server poll error code %s" % error)
		if udp_server.is_connection_available():
			var udp_peer : PacketPeerUDP = udp_server.take_connection()
			var packet = udp_peer.get_packet()
			print("Received : %s from %s:%s" % 
				[
					packet.get_string_from_ascii(),
					udp_peer.get_packet_ip(), 
					udp_peer.get_packet_port(),
				]
			)
			# Reply so it knows were this server is.
			error = udp_peer.put_packet(address.get_text().to_ascii())
			if error != OK:
				print("server put_packet error code %s" % error)
		
	#Client Side - server search
	if udp_requests > 0:
		if not udp_server_found: # Try to contact server
			error = udp_client.put_packet("ValidRequest".to_ascii())
			if error != OK:
				print("put_packet error code %s" % error)
				
		if udp_client.get_available_packet_count() > 0:
			address.text = udp_client.get_packet().get_string_from_ascii()
			udp_client.close()
			
			if auto_connect.is_pressed():
				main._join_pressed()
			else:
				main.set_text("Host Found!")
			
			udp_server_found = true
			set_process(false)

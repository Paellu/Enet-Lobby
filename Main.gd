extends Label

onready var interface = $Intro/Connection/Interface
onready var address = $Intro/Connection/Address
onready var join = $Intro/Connection/Join
onready var host = $Intro/Connection/Host
onready var search = $Intro/Connection/Search
onready var auto_connect = $Intro/Connection/Auto
onready var intro_name = $Intro/Name
onready var intro = $Intro

""" Utility Functions"""

func save_config():
	var config = ConfigFile.new()
	if config.load("res://Lobby.cfg") == OK:
		# Store variables to config file
		config.set_value("Connection", "last_address", address.text)
		
		# Save the changes by overwriting the previous config file
		config.save("res://Lobby.cfg")
	else:
		push_error("Failed to load lobby")

func load_config():
	var config = ConfigFile.new()
	if config.load("res://Lobby.cfg") == OK:
		# Look for last connected address or default to localhost if missing
		var last = config.get_value("Connection", "last_address", "127.0.0.1")
		address.set_text(last)
	else:
		# Create config file if it does not exist
		config.save("res://Lobby.cfg")

# Self explanitory
func _name_changed(new_name):
	if not new_name.is_valid_filename():
		intro_name.clear()
	elif address.text.is_valid_ip_address():
		join.set_disabled(false)

# Verify entered IP address
func _address_entered(ip_address):
	if ip_address.is_valid_ip_address():
		address.set_editable(false)
		if intro_name.text.is_valid_filename():
			join.set_disabled(false)
	else:
		address.clear()

# Setup default ip on interface changed
func _interface_selected(index):
	var item = IP.get_local_interfaces()[index]
	if item.name.begins_with("lo"):
		address.set_text("127.0.0.1")
		address.set_editable(false)
		join.set_disabled(false)
	else:
		# Make typing local address easy
		if auto_connect.is_pressed():
			address.set_text(item.addresses[0])
			address.set_editable(false)
		else:
			var point = item.addresses[0].find_last(".")
			address.set_text(item.addresses[0].left(point + 1))
			address.set_editable(true)
		address.set_cursor_position(address.text.length())
		address.grab_focus()

# Populate interface selection on press
func _interface_pressed():
	interface.clear()
	for item in IP.get_local_interfaces():
		if OS.get_name() == "Windows":
			if item.friendly:
				interface.add_item(item.friendly)
		else:
			if item.name.begins_with("lo"):
				interface.add_item("Localhost")
			elif item.name.begins_with("rmnet"):
				interface.add_item("GPRS")
			elif item.name.begins_with("wlan"):
				interface.add_item("WIFI")
			elif item.name.begins_with("rndi") or item.name.begins_with("etho"):
				interface.add_item("USB")
			elif item.name.begins_with("enp"):
				interface.add_item("Ethernet")
			else:
				interface.add_item(item.name)
	interface.add_item("None")
	interface.select(interface.get_item_count() -1)

func _join_pressed():
	if intro_name.text.empty():
		# Generate random name
		var names = ["Lee", "Moses", "Gary", "Terry", "Marvin", "Ethen", "Felix", "Walter"]
		randomize()
		intro_name.grab_focus()
		intro_name.set_text(names[randi() % names.size()])
		intro_name.set_cursor_position(intro_name.text.length())
		
	var lobby = load("Lobby.tscn").instance()
	lobby.set_script(load("Client.gd"))
	add_child(lobby)

func _host_pressed():
	var lobby = load("Lobby.tscn").instance()
	lobby.set_script(load("Server.gd"))
	add_child(lobby)

func reset():
	if has_node("Lobby"):
		remove_child(get_node("Lobby"))
	intro.show()
	
	set_text("Tilte Screen")

func _ready():
	# Setup intro signals
	intro_name.connect("text_entered", self, "_name_changed")
	
	address.connect("text_entered", self, "_address_entered")
	interface.connect("pressed", self, "_interface_pressed")
	interface.connect("item_selected", self, "_interface_selected")
	
	# Load any previously saved config
	load_config()
	
	if address.text:
		join.set_disabled(false)
		
	# Try to automatically set ip address
	elif IP.get_local_interfaces().size():
		# Auto selection if localhost and 1 other interface available
		if IP.get_local_interfaces().size() == 2:
			for item in IP.get_local_interfaces():
				if int(item.index) == 2:
					address.set_text(item.addresses[0])
					join.set_disabled(false)
		else:
			address.set_text(IP.get_local_interfaces()[0].addresses[0])
			join.set_disabled(false)
	else:
		# no networking available
		interface.hide()
		join.set_disabled(true)
		host.set_disabled(true)
	
	# Save config for future use
	save_config()
	
	join.connect("pressed", self, "_join_pressed")
	host.connect("pressed", self, "_host_pressed")
	
	set_text("Tilte Screen")

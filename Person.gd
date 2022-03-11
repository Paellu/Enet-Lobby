extends HBoxContainer

signal option_changed()

onready var lobby = find_parent("Lobby")
onready var options = get_node("Options")
onready var popup = options.get_popup()
onready var check = get_node("Check")
onready var alias = get_node("Alias")
onready var shoe = get_node("Shoe")

func get_options():
	var opt = {}
	opt.options = options.selected
	opt.check = check.pressed
	opt.alias = alias.text
	return opt

# Send all options to remote peer_id
# of this person and can only be called by its network_master
func set_options_on(peer_id):
	options.rset_id(peer_id, "selected", options.get_selected())
	check.rset_id(peer_id, "pressed", check.pressed)
	alias.rset_id(peer_id, "text", alias.text)

func set_alias(val):
	alias.set_text(str(val))

func _on_option_changed(value):
	# not all peers on the server will have the same
	# node tree so instead of rset, rset_id is used here for 
	# peers with the same setup i.e the same room
	# ToDo: complain to Godot devs about lack of rset_group_id()
	
	for peer_id in lobby.peers:
		match typeof(value):
			TYPE_STRING:
				if not value.is_valid_filename():
					return
				alias.rset_id(peer_id, "text", value)
			TYPE_INT:
				options.rset_id(peer_id, "selected", value)
			TYPE_BOOL:
				check.rset_id(peer_id, "pressed", value)
	emit_signal("option_changed")

func _ready():
	# Set-up remote options for other peers in the room so when a choice is made 
	# it is reflected globally for every peer in that room
	var rpc_mode = MultiplayerAPI.RPC_MODE_REMOTE
	options.rset_config("selected", rpc_mode)
	check.rset_config("pressed", rpc_mode)
	alias.rset_config("text", rpc_mode)
	
	options.connect("item_selected", self, "_on_option_changed")
	alias.connect("text_entered", self, "_on_option_changed")
	check.connect("toggled", self, "_on_option_changed")

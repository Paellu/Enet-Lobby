class_name Lobby extends Control

# Used for intents
enum ACTION {
		IDENTIFY = 4586, REQUEST,
		OPEN, ENTER, EXIT, CLOSE, REFRESH,
		BOUNCE, DISCONNECT
}

onready var header_amount = $Header/Amount
onready var header_limit = $Header/Limit
onready var header_name = $Header/Alias
onready var header_new = $Header/Door
onready var header = $Header

onready var building = $Building
onready var crowd = $Crowd

onready var peer = NetworkedMultiplayerENet.new()
onready var tree = get_tree()
onready var main = tree.get_current_scene()
onready var intro = main.get_node("Intro")
onready var intro_name = main.get_node("Intro/Name")
onready var address = main.get_node("Intro/Connection/Address")

var LAN = {"ADDRESS" : "", "PORT" : 9898, "MAX_PEERS" : 15}

var person = preload("res://Person.tscn")
var room = preload("res://Room.tscn")

remote var peer_rooms = {}
var peers = {}
var info = {}

""" Person Functions"""

func crowd_clear():
	for child in crowd.get_children():
		crowd.remove_child(child)
	crowd.hide()

""" Room Functions"""

func building_clear():
	for child in building.get_children():
		building.remove_child(child)
	building.hide()

""" Network Manager Functions """

func connection_close():
	peers.clear()
	if peer.get_connection_status() != peer.CONNECTION_DISCONNECTED:
		peer.close_connection()
		tree.set_network_peer(null) # Remove peer.

func _peer_disconnected(id):
	if building.has_node("Room_%s" % str(id)):
		building.get_node("Room_%s" % str(id)).queue_free()
	if crowd.has_node("Person_%s" % str(id)):
		crowd.get_node("Person_%s" % str(id)).queue_free()
		
	if peers.has(id):
		peers.erase(id)

func _peer_connected(id):
	# Send this peer's info to the server peer
	# know that this is and may not be the best approach for all use cases
	# as each peer is not peer aware with this setup and only the server peer is
	if id == peer.TARGET_PEER_SERVER:
		#only the server keeps record of your information
		var intent = {
			"action" : ACTION.IDENTIFY,
			"peer_info" : info,
		}
		
		rpc_id(id, "report", intent)

# To whom it may concern or bother
# Came from an Object-C background and accustommed to having ordered functions
# GDScript is orderless or rather overridden functions like this are
# to be top most... end rant ...
func _ready():
	LAN.ADDRESS = address.get_text()
	
	peer.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	
	# Connect the callbacks related to networking.
	tree.connect("network_peer_disconnected", self, "_peer_disconnected")
	tree.connect("network_peer_connected", self, "_peer_connected")

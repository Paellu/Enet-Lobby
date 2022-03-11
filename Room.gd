extends HBoxContainer

onready var alias = get_node("Alias")
onready var door = get_node("Door")
onready var inner = get_node("Amount")
onready var limit = get_node("Limit")

func set_inner(val):
	inner.set_text(str(val))
	
func set_limit(val):
	limit.set_text(str(val))
	
func set_alias(val):
	alias.set_text(str(val))

func set_value(node, val):
	get_node(node).set_text(str(val))

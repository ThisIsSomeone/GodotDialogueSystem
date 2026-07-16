class_name DialogueCommand
extends DialogueEntry

var name := ""
var arguments: PackedStringArray = []

func _init(_name := "", _arguments: PackedStringArray = []):
	name = _name
	arguments = _arguments

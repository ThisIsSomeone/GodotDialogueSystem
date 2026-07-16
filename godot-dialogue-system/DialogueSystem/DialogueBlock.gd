class_name DialogueBlock
extends RefCounted

var speaker := ""
var base_offset := Vector2.ZERO

var entries: Array[DialogueEntry] = []

func _init():
	entries = []

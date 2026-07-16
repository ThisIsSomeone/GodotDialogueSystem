class_name DialogueLine
extends DialogueEntry

var offset := Vector2.ZERO

var text: String = ""

# Inline commands (\!)
var inline_commands: Array = []

# One-shot commands (%)
var commands: Dictionary = {}

func _init(_text := ""):
	text = _text
	commands = {}
	inline_commands = []

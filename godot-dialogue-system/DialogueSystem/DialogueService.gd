extends Node

var manager: DialogueManager

const MIN_TEXT_SPEED := 10.0
const DEFAULT_SPEED := 25.0
const MAX_TEXT_SPEED := 40.0

# Stored as 0.0 -> 1.0
var text_speed := 0.5

# Convert fake speed into real speed
func get_characters_per_second() -> float:
	return lerpf(MIN_TEXT_SPEED, MAX_TEXT_SPEED, text_speed)

### Should be used when calling from a ready function to ensure the manager is loaded
func start_dialogue(path: String):
	if manager:
		manager.start_dialogue(path)

func set_text_speed(value: float):
	#Ignore the standard value request from the save manager
	if value == -1001:
		return
	
	text_speed = clampf(value, 0.0, 1.0)

	if manager:
		manager.characters_per_second = get_characters_per_second()

### Should be used when calling from a ready function to ensure the manager is loaded
func start_dialogue_deferred(path: String):
	await get_tree().process_frame
	start_dialogue(path)

func next_line():
	if manager:
		manager.next_line()

func close():
	if manager:
		manager.end_dialogue()

func is_playing() -> bool:
	return manager != null and manager.is_playing


# Call DialogueService via autoload, so every script can do 
# DialogueService.manager.start_dialogue(...)
# And it will work!

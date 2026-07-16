extends Node2D

@export_group("Dialogue Triggers")
@export_file("*.txt") var dialogue_on_ready: String
@export var dialogue_trigger_signals: Array[StringName] = []
@export_file("*.txt") var dialogue_on_triggers: Array[String] = []
@export var dialogue_trigger_one_shots: Array[bool] = []

func _setup_dialogue_triggers() -> void:
	print("Setting up dialogue triggers")
	if dialogue_trigger_signals.size() != dialogue_on_triggers.size() \
	or dialogue_trigger_signals.size() != dialogue_trigger_one_shots.size():
		push_error("%s: Dialogue trigger arrays must all be the same size." % name)
		return

	for i in dialogue_trigger_signals.size():
		var signal_name := dialogue_trigger_signals[i]

		if !has_signal(signal_name):
			push_warning("%s: Signal '%s' does not exist." % [name, signal_name])
			continue
		

		var path := dialogue_on_triggers[i]
		var one_shot := dialogue_trigger_one_shots[i]

		print("Connecting:", signal_name, "->", path, "(one shot:", one_shot, ")")
		if one_shot:
			connect(signal_name, func(): print("Triggered:", signal_name, "->", path); DialogueService.start_dialogue(path), CONNECT_ONE_SHOT)
		else:
			connect(signal_name, func(): print("Triggered:", signal_name, "->", path); DialogueService.start_dialogue(path))


func _ready():
	_setup_dialogue_triggers()
	
	# Below are examples of how you could connect the DialogueSignals to your player
	#DialogueSignals.player_action.connect(_on_dialogue_player_action)
	#DialogueSignals.player_move.connect(_on_dialogue_player
	
	
	# Convert to strict String and strip invisible characters
	var safe_path = str(dialogue_on_ready).strip_edges()
		
	if safe_path != "" and FileAccess.file_exists(safe_path):
		# Wait for the entire scene tree to finish its _ready() phase
		#await owner.ready 
		DialogueService.start_dialogue_deferred(safe_path)

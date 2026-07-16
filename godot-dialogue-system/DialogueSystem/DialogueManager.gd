class_name DialogueManager
extends Node2D

@onready var dialogue_root: Control = $DialogueRoot
@onready var dialogue_box: Panel = $DialogueRoot/DialogueBox
@onready var text: RichTextLabel = $DialogueRoot/DialogueBox/MarginContainer/RichTextLabel
@onready var arrow: Sprite2D = $DialogueRoot/Arrow

@export var characters_per_second := 25.0

const MAX_DIALOGUE_CHARACTERS := 60
const BOUNCE_LENGTH := 6 # Variable to adjust bounciness
const ARROW_OFFSET  := -40 # How high the arrow is above the player

enum RuntimeState {
	IDLE,
	RESOLVING_ENTRY,
	TYPING,
	WAITING_FOR_INPUT,
	WAITING_FOR_COMMAND,
	ENDED
}

var current_text := ""
var is_advancing := false
var dialogue_box_visible := false


var dialogue_hide_requests := 0 #Requests to hide dialogue
var dialogue_busy_requests := 0 #Keeps track of when dialogue is busy
var dialogue_block_requests := 0 #Keeps track of how many inline blocks were called
								 #Relevant when calling blocks in dialogue from different sources

var previous_visible_characters := 0
var visible_character_progress := 0.0
var arrow_bounce_time := 0.0
var arrow_base_position := Vector2.ZERO

# For inline commands
var current_dialogue_line: DialogueLine = null
var next_inline_command := 0

var current_block := 0
var current_entry := 0

var is_playing := false
var runtime_state: RuntimeState = RuntimeState.IDLE
var pending_advance_request := false
var entry_completed := false

var conversation: DialogueConversation

# Follow the talker variables
var speaker: Node2D = null
var base_offset := Vector2.ZERO

func _ready():
	DialogueService.manager = self # Register yourself as the new dialogue manager for the scene
	characters_per_second = DialogueService.get_characters_per_second() # Set text speed based on global value
	dialogue_box.hide()
	arrow.hide()

func start_dialogue(path: String):
	if is_playing: #Ensures we arent already parsing dialogue
		return

	conversation = DialogueParser.parse(path)

	current_block = 0
	current_entry = 0
	reset_runtime_state()

	set_runtime_state(RuntimeState.RESOLVING_ENTRY)
	
	### Call the Unique player node name to ensure that all functions are stopped
	var player := get_node_or_null("%Player")

	if player:
		player.enter_dialogue()

	await show_current_entry()
	complete_current_entry()

func set_runtime_state(new_state: RuntimeState) -> void:
	runtime_state = new_state
	is_playing = new_state != RuntimeState.IDLE and new_state != RuntimeState.ENDED

func can_accept_advance() -> bool:
	return is_playing and runtime_state == RuntimeState.WAITING_FOR_INPUT

func is_typing_state() -> bool:
	return runtime_state == RuntimeState.TYPING

func is_resolving_entry_state() -> bool:
	return runtime_state == RuntimeState.RESOLVING_ENTRY

func reset_runtime_state() -> void:
	current_dialogue_line = null
	next_inline_command = 0
	previous_visible_characters = 0
	visible_character_progress = 0.0
	arrow_bounce_time = 0.0
	is_advancing = false
	pending_advance_request = false
	runtime_state = RuntimeState.IDLE
	entry_completed = false
	dialogue_hide_requests = 0
	dialogue_busy_requests = 0
	dialogue_block_requests = 0

func finish_typing() -> void:
	text.visible_characters = text.get_total_character_count()
	previous_visible_characters = text.visible_characters
	set_runtime_state(RuntimeState.WAITING_FOR_INPUT)
	arrow_bounce_time = 0.0
	arrow.show()

func get_current_block() -> DialogueBlock:
	if conversation == null or current_block < 0 or current_block >= conversation.blocks.size():
		return null

	return conversation.blocks[current_block]

func get_current_entry() -> DialogueEntry:
	var block := get_current_block()
	if block == null or current_entry < 0 or current_entry >= block.entries.size():
		return null

	return block.entries[current_entry]

func advance_to_next_entry() -> bool:
	if conversation == null:
		return false

	if current_block < 0:
		current_block = 0
		current_entry = 0

	while current_block < conversation.blocks.size():
		var block := conversation.blocks[current_block]

		if current_entry + 1 < block.entries.size():
			current_entry += 1
			return true

		current_block += 1
		current_entry = 0

	return current_block < conversation.blocks.size()

func show_current_entry() -> bool:
	print(
		"SHOW ENTRY:",
		current_block,
		current_entry
	)
	entry_completed = false
	set_runtime_state(RuntimeState.RESOLVING_ENTRY)

	var block := get_current_block()
	if block == null:
		end_dialogue()
		set_runtime_state(RuntimeState.ENDED)
		return false

	var entry := get_current_entry()
	if entry == null:
		end_dialogue()
		set_runtime_state(RuntimeState.ENDED)
		return false

	# Find the speaker
	var speaker_node := get_node_or_null("%" + block.speaker)

	if speaker_node == null:
		push_error("Couldn't find speaker node '%s'" % block.speaker)
		set_runtime_state(RuntimeState.ENDED)
		return false

	var anchor := speaker_node.get_node_or_null("DialogueAnchor")

	if anchor == null:
		push_error("%s has no DialogueAnchor!" % block.speaker)
		set_runtime_state(RuntimeState.ENDED)
		return false

	if entry is DialogueLine:
		set_speaker(anchor, block.base_offset + entry.offset)
		current_dialogue_line = entry
		next_inline_command = 0
		await show_dialogue(entry.text)
		await wait_for_typing_completion()
		return true

	if entry is DialogueCommand:
		set_runtime_state(RuntimeState.WAITING_FOR_COMMAND)
		if entry.name.ends_with("_b"):
			await run_command(entry)
		else:
			run_action(entry)
		
		request_advance() # Ensure we actually advance after requesting a dialogue command
		return true

	set_runtime_state(RuntimeState.WAITING_FOR_INPUT)
	return false

func end_dialogue():
	is_playing = false
	set_runtime_state(RuntimeState.ENDED)
	reset_runtime_state()

	dialogue_box.hide()
	arrow.hide()

	speaker = null

func _process(delta):
	if !is_playing or speaker == null:
		return
	
	arrow_bounce_time += delta

	# Adjust Position Dialogue Box
	global_position = (
		speaker.global_position
		- Vector2(dialogue_box.size.x / 2.0, dialogue_box.size.y)
		+ base_offset
	)
	
	# Position the arrow above the player
	arrow_base_position = speaker.global_position + Vector2(0, ARROW_OFFSET)
	if arrow.visible:
		arrow.global_position = arrow_base_position + Vector2(
			0,
			round(sin(arrow_bounce_time * BOUNCE_LENGTH)) # Use round movement
		)
	else:
		arrow.global_position = arrow_base_position
	
	if is_typing_state(): # If we just asked a dialogue comand to be played
		if is_dialogue_blocked(): # Ensures we stop dialogue after an inline block
			return
		visible_character_progress += characters_per_second * delta
		text.visible_characters = floori(visible_character_progress)
				
		if text.visible_characters > previous_visible_characters:
			for index in range(previous_visible_characters, text.visible_characters):

				while (
					current_dialogue_line != null
					and next_inline_command < current_dialogue_line.inline_commands.size()
					and current_dialogue_line.inline_commands[next_inline_command].character_index == index
				):
					run_inline_command(
						current_dialogue_line.inline_commands[next_inline_command]
					)

					next_inline_command += 1
					
					if is_dialogue_blocked(): # Early return when blocking
						previous_visible_characters = index + 1
						return

				if index >= 0 and index < current_text.length():
					var character := current_text[index]

					if character != " " and character != "." and character != ",":
						#TODO: Enable if you have an audio manager
						#AudioManager.play_player_blip()
						pass

			previous_visible_characters = text.visible_characters
		
		if text.visible_characters >= text.get_total_character_count():
			finish_typing()

func wait_for_typing_completion() -> void:
	while is_typing_state():
		await get_tree().process_frame

# Shows dialogue character by character
func show_dialogue(message: String) -> void:
	if !is_dialogue_hidden():
		dialogue_box.show()

	# TODO: Makes the box pop in, just remove the next 4 lines if you want to remove this
	dialogue_box.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_property(dialogue_box, "scale", Vector2(1.02, 1.02), 0.08)
	tween.tween_property(dialogue_box, "scale", Vector2.ONE, 0.05)

	arrow.hide()

	current_text = message
	
	# We ensure our editor gets aware if we make very long sentences
	if message.length() > MAX_DIALOGUE_CHARACTERS:
		push_warning(
			"Dialogue line is %d characters long (recommended max %d): \"%s\""
			% [message.length(), MAX_DIALOGUE_CHARACTERS, message]
		)
	
	text.clear()
	text.append_text(current_text)

	# Wait for RichTextLabel to finish parsing BBCode
	await get_tree().process_frame

	text.visible_characters = 0
	previous_visible_characters = 0
	visible_character_progress = 0.0
	set_runtime_state(RuntimeState.TYPING)

#Sets speaker
func set_speaker(node: Node2D, offset: Vector2 = Vector2.ZERO):
	speaker = node
	base_offset = offset

#Ensure the active levels unregisters its dialogue manager 
func _exit_tree():
	if DialogueService.manager == self:
		DialogueService.manager = null
		
func request_advance() -> void:
	if !is_playing:
		return

	if can_accept_advance():
		pending_advance_request = false
		advance_dialogue()
	elif runtime_state == RuntimeState.RESOLVING_ENTRY or runtime_state == RuntimeState.WAITING_FOR_COMMAND:
		pending_advance_request = true

# Asks for dialogue advancemenet
func next_line():
	request_advance()

# Triggers command functionality, Blocking
func run_command(command: DialogueCommand):
	await DialogueCommandRunner.run(self, command)

# Triggers command functionality, Non-Blocking
func run_action(command: DialogueCommand):
	DialogueActionRunner.run(self, command)
	
func _unhandled_input(event):
	if !is_playing or runtime_state == RuntimeState.RESOLVING_ENTRY or runtime_state == RuntimeState.WAITING_FOR_COMMAND:
		return

	if !event.is_action_pressed("dialogic_default_action"):
		return

	# Ignore input while dialogue is blocked.
	if is_dialogue_blocked():
		return

	# Finish typing instantly, respecting inline commands.
	if is_typing_state():
		while (
			current_dialogue_line != null
			and next_inline_command < current_dialogue_line.inline_commands.size()
		):
			var command: DialogueInlineCommand = current_dialogue_line.inline_commands[next_inline_command]

			# Reveal everything up to the command.
			text.visible_characters = command.character_index
			previous_visible_characters = command.character_index

			run_inline_command(command)
			next_inline_command += 1

			# Stop immediately if the command blocks dialogue.
			if is_dialogue_blocked():
				return

		# No more blocking commands: reveal the rest.
		finish_typing()
		return

	# Ignore input while a dialogue action owns progression.
	if is_dialogue_busy():
		return

	# Otherwise continue normally.
	request_advance()

func request_dialogue_hidden():
	dialogue_hide_requests += 1

	dialogue_box.hide()
	arrow.hide()

func release_dialogue_hidden():
	dialogue_hide_requests = max(dialogue_hide_requests - 1, 0)

	if dialogue_hide_requests == 0:
		dialogue_box.show()

func is_dialogue_hidden() -> bool:
	return dialogue_hide_requests > 0

func request_dialogue_busy():
	dialogue_busy_requests += 1

func release_dialogue_busy():
	dialogue_busy_requests = max(dialogue_busy_requests - 1, 0)

func is_dialogue_busy():
	return dialogue_busy_requests > 0

func request_dialogue_block():
	dialogue_block_requests += 1

func release_dialogue_block():
	dialogue_block_requests = max(dialogue_block_requests - 1, 0)

func is_dialogue_blocked() -> bool:
	return dialogue_block_requests > 0

func run_inline_command(inline_command: DialogueInlineCommand):
	match inline_command.command.name:

		"block":
			if inline_command.command.arguments.is_empty():
				push_warning("\\!block requires a duration.")
				return

			var duration := inline_command.command.arguments[0].to_float()

			request_dialogue_block()

			get_tree().create_timer(duration).timeout.connect(
				func():
					release_dialogue_block()
			)

		"block_until":
			if inline_command.command.arguments.size() < 2:
				push_warning("\\!block_until requires a node name and signal name.")
				return

			var node_name := inline_command.command.arguments[0]
			var signal_name := StringName(inline_command.command.arguments[1])

			var node := get_node_or_null("%" + node_name)

			if node == null:
				push_warning("\\!block_until: Unknown node '%s'." % node_name)
				return

			if !node.has_signal(signal_name):
				push_warning(
					"\\!block_until: Node '%s' has no signal '%s'."
					% [node_name, signal_name]
				)
				return

			request_dialogue_block()

			var requested_signal := Signal(node, signal_name)

			requested_signal.connect(
				func():
					release_dialogue_block(),
				CONNECT_ONE_SHOT
			)

		_:
			DialogueActionRunner.run(self, inline_command.command)

func complete_current_entry() -> void:
	if runtime_state == RuntimeState.ENDED or entry_completed:
		return

	entry_completed = true
	set_runtime_state(RuntimeState.WAITING_FOR_INPUT)

	if pending_advance_request and !is_advancing:
		pending_advance_request = false
		call_deferred("advance_dialogue")

# Owns the progression chain and locks it
func advance_dialogue():
	if is_advancing or !can_accept_advance():
		return

	is_advancing = true
	pending_advance_request = false
	set_runtime_state(RuntimeState.RESOLVING_ENTRY)

	if !advance_to_next_entry():
		end_dialogue()
		is_advancing = false
		return

	await show_current_entry()
	
	complete_current_entry()

	is_advancing = false
	
	if pending_advance_request:
		pending_advance_request = false
		call_deferred("advance_dialogue")

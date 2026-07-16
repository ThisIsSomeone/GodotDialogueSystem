class_name DialogueActionRunner
extends Object


### Handles non-blocking dialogue actions.
static func run(
	manager: DialogueManager,
	command: DialogueCommand
) -> void:

	match command.name:

		### Hides dialogue for a duration, but doesn't stop script progression.
		### Relevant if you want to play other non-blocking commands while dialogue is hidden
		### @delay is intended to accompany one or more non-blocking actions. 
		### Using it by itself is valid, but @delay_b is usually the clearer choice.
		"delay":
			if command.arguments.is_empty():
				push_warning("@delay requires a duration.")
				return

			var duration := command.arguments[0].to_float()

			manager.request_dialogue_hidden()
			manager.request_dialogue_busy()

			manager.get_tree().create_timer(duration).timeout.connect(
				func():
					manager.release_dialogue_hidden()
					manager.release_dialogue_busy()
			)

		### Hide dialogue indefinitely.
		"hide_dialogue":
			manager.request_dialogue_hidden()

		### Show dialogue again.
		"show_dialogue":
			manager.release_dialogue_hidden()

		### Prevent advancing until released.
		"busy":
			manager.request_dialogue_busy()

		### Allow advancing again.
		"free":
			manager.release_dialogue_busy()

		### Shakes camera for requested intensity and duration
		"camera_shake":
			if command.arguments.size() < 2:
				push_warning("@camera_shake requires intensity and duration.")
				return

			DialogueSignals.camera_shake.emit(
				command.arguments[0].to_float(),
				command.arguments[1].to_float()
			)

		### Zooms camera to requested Vector2(x,y) and duration
		"camera_zoom":
			if command.arguments.size() < 3:
				push_warning("@camera_zoom requires x y duration.")
				return

			DialogueSignals.camera_zoom.emit(
				Vector2(
					command.arguments[0].to_float(),
					command.arguments[1].to_float()
				),
				command.arguments[2].to_float()
			)

		### Move Player
		"player_move":
			if command.arguments.size() < 2:
				push_warning("@player_move requires direction and duration.")
				return

			var direction := command.arguments[0]
			var duration := command.arguments[1].to_float()

			DialogueSignals.player_move.emit(direction, duration)

		### Player Action
		"player_action":
			if command.arguments.is_empty():
				push_warning("@player_action requires an action.")
				return

			DialogueSignals.player_action.emit(command.arguments[0])

		_:
			push_warning("Unknown dialogue action: %s" % command.name)

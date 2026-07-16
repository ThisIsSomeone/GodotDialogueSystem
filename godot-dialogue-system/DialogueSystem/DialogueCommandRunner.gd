class_name DialogueCommandRunner
extends Object

### Handles Blocking Operations that pause dialogue until this is resolved

### Handles Command Functionality when a line starts with @
### e.g. @wait 0.5 , or @shake
static func run(
	manager: DialogueManager,
	command: DialogueCommand
) -> void:
	
	### All blocking commands must end with _b
	match command.name:
		### Hides text box and waits for set duration
		"delay_b":
			if command.arguments.is_empty():
				push_warning("@delay_b requires a duration.")
				return

			var duration := command.arguments[0].to_float()

			manager.request_dialogue_hidden()
			manager.request_dialogue_busy()

			await manager.get_tree().create_timer(duration).timeout

			manager.release_dialogue_hidden()
			manager.release_dialogue_busy()

		### Camera Shake
		"camera_shake_b":
			if command.arguments.size() < 2:
				push_warning("@camera_shake_b requires intensity and duration.")
				return

			var intensity := command.arguments[0].to_float()
			var duration := command.arguments[1].to_float()

			manager.request_dialogue_busy()
			DialogueSignals.camera_shake.emit(intensity, duration)

			await manager.get_tree().create_timer(duration).timeout
			manager.release_dialogue_busy()

		### Camera Zoom
		"camera_zoom_b":
			if command.arguments.size() < 3:
				push_warning("@camera_zoom_b requires x y duration.")
				return

			var target_zoom := Vector2(
				command.arguments[0].to_float(),
				command.arguments[1].to_float()
			)

			var duration := command.arguments[2].to_float()

			manager.request_dialogue_busy()
			DialogueSignals.camera_zoom.emit(target_zoom, duration)

			await manager.get_tree().create_timer(duration).timeout
			manager.release_dialogue_busy()

		### Move Player
		"player_move_b":
			if command.arguments.size() < 2:
				push_warning("@player_move_b requires direction and duration.")
				return

			var direction := command.arguments[0]
			var duration := command.arguments[1].to_float()

			manager.request_dialogue_busy()
			DialogueSignals.player_move.emit(direction, duration)

			await manager.get_tree().create_timer(duration).timeout
			manager.release_dialogue_busy()

		### Player Action
		"player_action_b":
			if command.arguments.is_empty():
				push_warning("@player_action_b requires an action.")
				return

			var action := command.arguments[0]

			manager.request_dialogue_busy()
			DialogueSignals.player_action.emit(action)

			match action:
				"jump":
					await manager.get_tree().create_timer(0.6).timeout

				"taunt":
					await manager.get_tree().create_timer(0.8).timeout

			manager.release_dialogue_busy()

		### If no Match pushes warning
		_:
			push_warning("Unknown dialogue command: %s" % command.name)

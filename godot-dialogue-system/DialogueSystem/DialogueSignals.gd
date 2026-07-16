extends Node

@warning_ignore_start("unused_signal") # Ignore these warnings

### Camera
signal camera_shake(intensity: float, duration: float)
signal camera_zoom(zoom: Vector2, duration: float)

### Player
signal player_move(direction: String, duration: float)
signal player_action(action: String)

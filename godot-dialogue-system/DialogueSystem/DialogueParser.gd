class_name DialogueParser
extends RefCounted

static func get_command_name(line: String) -> String:
	var pieces := line.substr(1).split(" ", false, 1)
	return pieces[0]


static func get_command_arguments(line: String) -> String:
	var pieces := line.substr(1).split(" ", false, 1)

	if pieces.size() > 1:
		return pieces[1]

	return ""

static func parse(path: String) -> DialogueConversation:
	var conversation := DialogueConversation.new()

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Couldn't open dialogue file: " + path)
		return conversation

	var current_block: DialogueBlock = null

	while !file.eof_reached():
		var line := strip_comment(file.get_line())

		if line == "":
			continue

		# Saves commands starting with @ 
		if line.begins_with("@"):
			var command := get_command_name(line)
			var arguments := get_command_arguments(line)

			if command == "speaker":
				current_block = DialogueBlock.new()
				current_block.speaker = arguments
				conversation.blocks.append(current_block)
				continue

			if command == "offset":
				if current_block == null:
					push_error("Offset before speaker!")
					continue

				var pieces := arguments.split(" ")

				if pieces.size() >= 2:
					current_block.base_offset = Vector2(
						pieces[0].to_float(),
						pieces[1].to_float()
					)
					
					
				continue
			
			# Everything else becomes a command
			if current_block == null:
				push_error("Command before speaker!")
				continue
				
			# Stores Dialogue Commands
			var dialogue_command := DialogueCommand.new()
			dialogue_command.name = command

			if arguments == "":
				dialogue_command.arguments = []
			else:
				dialogue_command.arguments = arguments.split(" ", false)

			current_block.entries.append(dialogue_command)
			continue

		# Dialogue before any speaker is an error.
		if current_block == null:
			push_error("Dialogue before speaker!")
			continue

		# Parse a dialogue line.
		var dialogue_line := DialogueLine.new()

		if "|" in line:
			var parts := line.split("|", false, 1)

			dialogue_line.text = parts[0].strip_edges()

			var pieces := parts[1].strip_edges().split(" ")

			if pieces.size() >= 2:
				dialogue_line.offset = Vector2(
					pieces[0].to_float(),
					pieces[1].to_float()
				)
		else:
			dialogue_line.text = line
		parse_inline_commands(dialogue_line) # Parse inline commands

		current_block.entries.append(dialogue_line)
		
	# Debug Prints
	print("Blocks:", conversation.blocks.size())

	for block in conversation.blocks:
		print("Speaker:", block.speaker)
		print("Base offset:", block.base_offset)

		for entry in block.entries:
			if entry is DialogueLine:
				print("LINE:", entry.text)

				for inline_command in entry.inline_commands:
					print(
						"  INLINE:",
						inline_command.character_index,
						inline_command.command.name,
						inline_command.command.arguments
					)

			elif entry is DialogueCommand:
				print("COMMAND:", entry.name, entry.arguments)
			
	# File management
	file.close()
	return conversation

static func strip_comment(line: String) -> String:
	var result := ""
	var escaped := false

	for c in line:
		if escaped:
			# Keep the '\' so later parser stages can decide what it means.
			result += "\\" + c # No longer destroys information anymore
			escaped = false
			continue

		if c == "\\":
			escaped = true
			continue

		if c == "#":
			break

		result += c

	# If the line ends with a lone '\', keep it.
	if escaped:
		result += "\\"

	return result.strip_edges()

static func parse_inline_commands(dialogue_line: DialogueLine) -> void:
	var visible_text := ""
	var i := 0

	while i < dialogue_line.text.length():
		var character := dialogue_line.text[i]

		if character == "\\":
			# Lone '\' at the end of the line.
			if i + 1 >= dialogue_line.text.length():
				visible_text += "\\"
				break

			var next_character := dialogue_line.text[i + 1]

			# Escaped backslash (\\ -> \)
			if next_character == "\\":
				visible_text += "\\"
				i += 2
				continue

			# Inline command (\!command(...))
			if next_character == "!":
				var name_start := i + 2
				var open_paren := dialogue_line.text.find("(", name_start)

				if open_paren == -1:
					push_error("Inline command missing '('")
					break

				var close_paren := dialogue_line.text.find(")", open_paren + 1)

				if close_paren == -1:
					push_error("Inline command missing ')'")
					break

				var inline_command := DialogueInlineCommand.new()

				inline_command.character_index = visible_text.length()
				inline_command.command.name = dialogue_line.text.substr(
					name_start,
					open_paren - name_start
				)

				var arguments := dialogue_line.text.substr(
					open_paren + 1,
					close_paren - open_paren - 1
				).strip_edges()

				if arguments == "":
					inline_command.command.arguments = []
				else:
					var pieces := arguments.split(",", false)

					for j in range(pieces.size()):
						pieces[j] = pieces[j].strip_edges()

					inline_command.command.arguments = pieces

				dialogue_line.inline_commands.append(inline_command)

				i = close_paren + 1
				continue

			# Existing escape behaviour (\# -> #, etc.)
			visible_text += next_character
			i += 2
			continue

		visible_text += character
		i += 1

	dialogue_line.text = visible_text

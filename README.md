Developed for Godot 4, Made by Alette Farzad (AI-assisted coding)

READ HOW TO USE

Either use the full project linked in the subfolder that has these basics set up already in an example, or simply extract the godot-dialogue-system.

1. Add DialogueService and DialogueSignals as globals
2. Add DialogueManager to the scene you want to use dialogue in
3. Add Marker2D named DialogueAnchor as child of a speaker with an unique name 
4. (DialogueAnchor can be within the instantiated scene)

DIALOGUE FILES
(Do not assume how any file works unless I send it.)

DialogueManager.gd
- Runtime controller.
- Shows dialogue.
- Types text.
- Executes DialogueCommand/DialogueAction.
- Handles input.
- Never parses dialogue.

DialogueParser.gd
- Parses .txt files into runtime objects.
- Parses @commands.
- Parses dialogue.
- Parses offsets.
- Strips comments.
- Handles escaping.

DialogueConversation.gd
- Holds DialogueBlocks.

DialogueBlock.gd
- Holds speaker, base offset and entries.

DialogueEntry.gd
- Base class.

DialogueLine.gd
- Holds visible text.
- Holds offset.
- Holds one-shot commands.
- Will also hold inline commands.

DialogueCommand.gd
- Holds command name + arguments.

DialogueCommandRunner.gd
- Executes blocking (@*_b) commands.

DialogueActionRunner.gd
- Executes non-blocking commands.

DialogueSignals.gd
- Global signal bus.
- Dialogue never references Player or Camera directly.

DialogueService.gd
- Global helper.
- Stores DialogueManager and characters/sec.

CURRENT FEATURES
- @speaker
- @offset
- Blocking commands
- Non-blocking commands
- Camera shake/zoom
- Player movement
- Player actions
- Dialogue hidden/busy ownership
- Escaped characters \
- Comments #
- Inline commands \!

ESCAPING
\# -> #
\\ -> \
# starts a comment unless escaped.

ARCHITECTURE
Everything should be parsed once.
Runtime should never reparse dialogue.

CURRENT TASK
We are implementing inline commands.

Planned syntax:

Hello \!wait(0.5) there.

Parser should:
- remove the inline command from visible text
- store the command
- store its arguments
- store the visible character index where it should execute

DialogueManager should execute the stored inline commands while typing reaches those indices.

Do not invent architecture. If you need another file, ask for it first.

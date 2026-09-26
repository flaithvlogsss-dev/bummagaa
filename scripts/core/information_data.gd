class_name InformationData
extends Resource
## A piece of knowledge the player collects: note, document, photo or radio message.
## Discovered ids live in GameState.discovered_information and gate dialogues, quests and endings.

@export var id: String = ""
@export var title: String = ""
@export_enum("note", "document", "photo", "radio") var info_type: String = "note"
@export_multiline var content: String = ""
@export var tags: PackedStringArray = PackedStringArray()
## Flags set when this information is discovered.
@export var sets_flags: PackedStringArray = PackedStringArray()

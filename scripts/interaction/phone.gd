class_name PhoneInteractable
extends Examine
## The ringing phone of the intro. Rings (looping sound) until it is answered.


func _process(_delta: float) -> void:
	var ringing := is_available() and is_inside_tree() and Main.instance != null and Main.instance.mode == Main.Mode.PLAYING
	if ringing:
		AudioManager.set_layer("phone", "phone_ring", 0.7, "SFX")
	else:
		AudioManager.stop_layer("phone")


func _exit_tree() -> void:
	AudioManager.stop_layer("phone")

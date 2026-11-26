extends Node
@onready var anim = $Background/AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim.play("bonfire")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends CharacterBody2D

@export var speed := 100.0
var current_dir := "down"

func _ready() -> void:
	$AnimatedSprite2D.play("front_idle")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	if direction != Vector2.ZERO:
		_update_direction(direction)
		play_anim(1)
	else:
		play_anim(0)
	move_and_slide()
	
func _update_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		current_dir = "right" if direction.x > 0 else "left"
	else:
		current_dir = "down" if direction.y > 0 else "up"

func play_anim(movement: int) -> void:
	var dir := current_dir
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	
	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")
			
	if dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")
			
	if dir == "down":
		anim.flip_h = true
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			anim.play("front_idle")
			
	if dir == "up":
		anim.flip_h = true
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			anim.play("back_idle")

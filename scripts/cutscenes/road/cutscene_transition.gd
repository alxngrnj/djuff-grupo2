extends Node2D

@export_file("*.tscn") var next_scene := "res://scenes/world.tscn"
@export_range(0.5, 30.0) var duration := 3.5

@export var road_marker_speed := 720.0
@export var car_shake_strength := 1.0
@export var car_shake_speed := 40.0
@export var transition_enabled := false

@onready var lane_markers: Node2D = $Road/LaneMarkers
@onready var car: Sprite2D = $Road/Car

var elapsed := 0.0
var car_base_position: Vector2

func _ready() -> void:
	car_base_position = car.position
	
	if next_scene == null:
		return
		
	await get_tree().create_timer(duration).timeout
	get_tree().change_scene_to_file(next_scene)


func _process(delta: float) -> void:
	elapsed += delta

	lane_markers.position.x -= road_marker_speed * delta
	if lane_markers.position.x <= -160.0:
		lane_markers.position.x += 160.0

	var shake := sin(elapsed * car_shake_speed) * car_shake_strength
	car.position = car_base_position + Vector2(0, shake * 1.5)

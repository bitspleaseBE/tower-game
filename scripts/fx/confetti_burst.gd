class_name ConfettiBurst
extends Node2D
## Pooled one-shot confetti. CPUParticles2D winner (see PerfBudget header).

signal finished

@onready var particles: CPUParticles2D = $Particles


func _ready() -> void:
	particles.one_shot = true
	particles.amount = PerfBudget.PARTICLES_PER_BURST
	particles.emitting = false
	particles.finished.connect(_on_particles_finished)


func activate(world_pos: Vector2) -> void:
	global_position = world_pos
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	particles.restart()


func _on_particles_finished() -> void:
	finished.emit()

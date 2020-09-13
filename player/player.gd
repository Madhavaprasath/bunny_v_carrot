extends KinematicBody2D


export var speed = 200
export var dash_speed_multiplier := 3
export var dash_length := .16 # Seconds 

var is_enabled := true
var animationState : AnimationNodeStateMachinePlayback
var health := 100.0
var screen_size
enum State{ACTIVE, DASHING, ATTACKING, INACTIVE}
var state = State.ACTIVE
var last_direction = Vector2()
var dash_modulate = Color(.5, .5, .5)
var normal_modulate = Color(1, 1, 1)
var target
var damage := 10

signal player_killed


func _ready():
	$CPUParticles2D.emitting = false
	animationState = $AnimationTree["parameters/playback"]
	$HealthBar.value = health
	screen_size = get_viewport_rect().size


func _physics_process(_delta):
	if state == State.INACTIVE:
		return
		
	var direction = Vector2()
	if state == State.DASHING:
		direction = last_direction 
	else:
		direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	if direction.length() > 0:
		update_sprite(direction)
		last_direction = direction
		var velocity = direction.normalized() * speed
		velocity = move_and_slide(velocity)
	elif state == State.ACTIVE:
		animationState.travel("idle")

	position.x = clamp(position.x, 12, screen_size.x - 12)
	position.y = clamp(position.y, 12, screen_size.y - 20)


func _input(event):
	if state == State.INACTIVE or state == State.DASHING:
		return
	if event.is_action_pressed("ui_dash"):
		dash()
	if event.is_action_pressed("ui_attack"):
		print("attack!")
		attack()


func attack():
	state = State.ATTACKING
	print("attacking!")
	animationState.travel("attack")


func _on_attack_end():
	if state == State.INACTIVE or state == State.ACTIVE:
		return
	state = State.ACTIVE
	if target:
		target.take_damage(damage)


func dash():
	$CPUParticles2D.emitting = true
	state = State.DASHING
	$Sprite.modulate = dash_modulate
	$Tween.interpolate_property(self, "speed", 
			speed * dash_speed_multiplier, speed, dash_length,
			Tween.TRANS_ELASTIC, Tween.EASE_IN)
	$Tween.start()
	yield($Tween, "tween_completed")
	$CPUParticles2D.emitting = false
	$Sprite.modulate = normal_modulate
	if state == State.INACTIVE:
		return
	state = State.ACTIVE


func update_sprite(direction : Vector2):
	$AnimationTree.set("parameters/idle/blend_position", direction)
	$AnimationTree.set("parameters/walk/blend_position", direction)
	$AnimationTree.set("parameters/attack/blend_position", direction)
	
	
	if state == State.ACTIVE:
		animationState.travel("walk")


func hit(damage_in):
	$hit_sound.play()
	health -= damage_in
	$HealthBar.value = health
	if health <= 0 and state != State.INACTIVE:
		emit_signal("player_killed")
		state = State.INACTIVE
		$death_sound.play()


func _on_Area2D_body_entered(body):
	if body.is_in_group("boss_weapon"):
		print("well hey there")
		hit(body.damage)
		body.explode()


func set_inactive():
	state = State.INACTIVE


func set_active():
	state = State.ACTIVE


func revive():
	set_active()
	health = 100
	$HealthBar.value = health


func _on_AttackArea_body_entered(body):
	if body.is_in_group("boss"):
		target = body

func _on_AttackArea_body_exited(body):
	if target and target == body:
		target = null

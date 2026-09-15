extends Node2D

const CELL_SIZE := 16
const GRID_WIDTH := 20
const GRID_HEIGHT := 12
const INITIAL_LENGTH := 3
const MOVE_INTERVAL := 0.12

const SNAKE_COLOR := Color(0.2, 0.8, 0.3)
const HEAD_COLOR := Color(0.3, 0.9, 0.4)
const FOOD_COLOR := Color(0.9, 0.2, 0.2)
const BG_COLOR := Color(0.1, 0.1, 0.12)

const SPARK_COUNT := 10
const SPARK_LIFETIME := 0.35
const SPARK_SPEED_MIN := 40.0
const SPARK_SPEED_MAX := 90.0
const SPARK_COLOR := Color(1.0, 0.85, 0.2)
const POPUP_SIZE := Vector2(32.0, 12.0)

@onready var move_timer: Timer = $MoveTimer
@onready var score_label: Label = $ScoreLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var popup_label: Label = $PopupLabel

var body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var next_direction := Vector2i.RIGHT
var food_pos := Vector2i.ZERO
var score := 0
var game_over := false
var sparks: Array[Dictionary] = []

func _ready() -> void:
	move_timer.wait_time = MOVE_INTERVAL
	move_timer.timeout.connect(_on_move_timer_timeout)
	popup_label.size = POPUP_SIZE
	_reset()

func _process(delta: float) -> void:
	if sparks.is_empty():
		return
	for spark in sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	sparks = sparks.filter(func(s): return s.life > 0.0)
	queue_redraw()

func _reset() -> void:
	game_over = false
	game_over_label.hide()
	score = 0
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT

	@warning_ignore("integer_division")
	var start_x := GRID_WIDTH / 2
	@warning_ignore("integer_division")
	var start_y := GRID_HEIGHT / 2
	body.clear()
	for i in range(INITIAL_LENGTH):
		body.append(Vector2i(start_x - i, start_y))

	_place_food()
	_update_score_label()
	sparks.clear()
	popup_label.hide()
	score_label.scale = Vector2.ONE
	move_timer.start()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event.is_action_pressed("ui_accept"):
			_reset()
		return

	var desired := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		desired = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		desired = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		desired = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		desired = Vector2i.RIGHT
	else:
		return

	# Buffer the turn; ignore direct reversals so the snake can't run into its own neck.
	if desired != -direction:
		next_direction = desired

func _on_move_timer_timeout() -> void:
	if game_over:
		return

	direction = next_direction
	var new_head: Vector2i = body[0] + direction

	if new_head.x < 0 or new_head.x >= GRID_WIDTH or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		_game_over()
		return

	var ate_food := new_head == food_pos
	# The tail cell vacates this tick unless the snake is growing, so it's a legal move target.
	var body_to_check := body if ate_food else body.slice(0, body.size() - 1)
	if body_to_check.has(new_head):
		_game_over()
		return

	body.insert(0, new_head)
	if ate_food:
		score += 1
		_update_score_label()
		_spawn_pickup_feedback(new_head)
		_place_food()
	else:
		body.remove_at(body.size() - 1)

	queue_redraw()

func _game_over() -> void:
	game_over = true
	move_timer.stop()
	game_over_label.text = "Game Over - Length %d\nPress Enter to Restart" % body.size()
	game_over_label.show()

func _place_food() -> void:
	var free_cells: Array[Vector2i] = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			if not body.has(cell):
				free_cells.append(cell)
	if free_cells.is_empty():
		_game_over()
		return
	food_pos = free_cells[randi() % free_cells.size()]

func _update_score_label() -> void:
	score_label.text = "Score: %d   Length: %d" % [score, body.size()]

func _spawn_pickup_feedback(cell: Vector2i) -> void:
	var center := Vector2(cell) * CELL_SIZE + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

	for i in range(SPARK_COUNT):
		var angle := (TAU / SPARK_COUNT) * i + randf_range(-0.25, 0.25)
		var speed := randf_range(SPARK_SPEED_MIN, SPARK_SPEED_MAX)
		sparks.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": SPARK_LIFETIME,
			"max_life": SPARK_LIFETIME,
		})

	popup_label.position = center - POPUP_SIZE * 0.5 - Vector2(0.0, CELL_SIZE * 0.5)
	popup_label.modulate = Color(1, 1, 1, 1)
	popup_label.show()
	var popup_tween := create_tween()
	popup_tween.tween_property(popup_label, "position:y", popup_label.position.y - 12.0, 0.45)
	popup_tween.parallel().tween_property(popup_label, "modulate:a", 0.0, 0.3).set_delay(0.15)
	popup_tween.tween_callback(popup_label.hide)

	score_label.scale = Vector2(1.35, 1.35)
	var score_tween := create_tween()
	score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_SIZE), BG_COLOR)
	draw_rect(Rect2(Vector2(food_pos) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), FOOD_COLOR)
	for i in range(body.size()):
		var color := HEAD_COLOR if i == 0 else SNAKE_COLOR
		draw_rect(Rect2(Vector2(body[i]) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), color)
	for spark in sparks:
		var t: float = spark.life / spark.max_life
		var color := SPARK_COLOR
		color.a = t
		draw_rect(Rect2(spark.pos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), color)

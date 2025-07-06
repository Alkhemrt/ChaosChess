extends Node2D

const TILE_SIZE := Global.TILE_SIZE
enum State {RUNNING, ENDED, PROMOTING}
var board: Array
var selected_piece: Piece
var moves: Dictionary
var round_num: int = 1
var turn := "white"
var state: State = State.RUNNING
var move_history : Array = []
var ai_enabled := false 

# Audio
@onready var capture: AudioStreamPlayer = $Audio/Capture
@onready var castle: AudioStreamPlayer = $Audio/Castle
@onready var click: AudioStreamPlayer = $Audio/Click
@onready var game_end: AudioStreamPlayer = $Audio/GameEnd
@onready var move_check: AudioStreamPlayer = $Audio/MoveCheck
@onready var move_black: AudioStreamPlayer = $Audio/MoveBlack
@onready var move_white: AudioStreamPlayer = $Audio/MoveWhite
@onready var promote: AudioStreamPlayer = $Audio/Promote

func _ready():
	randomize()
	$AnimationPlayer.play("fade")
	await setup_board()

func setup_board() -> void:
	var pieces_node := get_node_or_null("Pieces")
	if pieces_node:
		pieces_node.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	var values = Create.create_board(Create.DEFAULT_BOARD)
	board = values["board"]
	var pieces = values["node"]
	pieces.name = "Pieces"
	add_child(pieces)

	moves.clear()
	selected_piece = null
	$Board.queue_redraw()

func _on_restart_button_pressed():
	click.play()
	print("Restart pressed. Resetting game...")
	round_num = 1
	turn = "white"
	state = State.RUNNING
	move_history.clear()
	moves.clear()
	selected_piece = null
	$UI/ChaosLog.text = "None"
	update_move_list()
	await setup_board()

	if ai_enabled and turn == "black" and state == State.RUNNING:
		await get_tree().create_timer(0.5).timeout
		ai_make_move()

func _on_cpu_check_toggled(button_pressed: bool) -> void:
	click.play()
	ai_enabled = button_pressed
	if ai_enabled and turn == "black" and state == State.RUNNING:
		await get_tree().create_timer(0.5).timeout
		ai_make_move()

func _unhandled_input(event):
	if state != State.RUNNING:
		return
	if event.is_action_pressed("left_click"):
		var pos := get_tile_pos()
		if moves.has(pos):
			make_move(pos)
		else:
			show_moves(pos)
		$Board.queue_redraw()

func get_tile_pos() -> Vector2i:
	var mouse_pos = get_local_mouse_position()
	var pos = (mouse_pos / TILE_SIZE).floor()
	return pos.clamp(Vector2i.ZERO, Vector2i(7, 7))

func get_legal_moves(piece: Piece) -> Dictionary:
	var piece_moves = piece.get_moves(board)
	var original_pos := piece.pos
	for move in piece_moves.keys():
		var take_piece: Piece = null
		if piece_moves[move].type == Moves.CAPTURE:
			take_piece = piece_moves[move].take_piece
			board[take_piece.pos.y][take_piece.pos.x] = null

		board[piece.pos.y][piece.pos.x] = null
		board[move.y][move.x] = piece
		piece.pos = move
		if is_in_check():
			piece_moves.erase(move)
		piece.pos = original_pos
		board[move.y][move.x] = null
		board[piece.pos.y][piece.pos.x] = piece
		if take_piece:
			board[take_piece.pos.y][take_piece.pos.x] = take_piece
	
	return piece_moves

func no_legal_moves() -> bool:
	for row in board:
		for piece in row:
			if !piece or piece.team != turn:
				continue
			if get_legal_moves(piece).size():
				return false
	return true

func is_in_check() -> bool:
	for row in board:
		for piece in row:
			if !piece or piece.team == turn:
				continue
			var piece_moves: Dictionary = piece.get_moves(board)
			for move in piece_moves.values():
				if move.type == Moves.CAPTURE and move.take_piece.piece_id == Piece.KING:
					return true
	return false

func show_moves(pos: Vector2i):
	if !board[pos.y][pos.x]:
		return
	var piece: Piece = board[pos.y][pos.x]
	if piece.team != turn:
		return
	if selected_piece == piece:
		moves.clear()
		selected_piece = null
		return
	moves = get_legal_moves(piece)
	selected_piece = piece

func move_piece(pos: Vector2i, piece: Piece):
	board[piece.pos.y][piece.pos.x] = null
	board[pos.y][pos.x] = piece
	piece.last_move_round = round_num
	piece.pos = pos
	piece.move_animation(pos)

func make_move(pos: Vector2i):
	var move = moves[pos]
	moves.clear()
	move_piece(pos, selected_piece)

	var move_notation = get_move_notation(selected_piece, pos)

	if turn == "white":
		move_notation = move_notation.rpad(7)
		move_history.append(str(round_num) + ". " + move_notation)
		move_white.play()
	else:
		move_history[-1] += "   " + move_notation
		move_black.play()
		round_num += 1
		if round_num > 5:
			ChaosManager.trigger_chaos(board)

	update_move_list()

	if move.type == Moves.CAPTURE:
		var timer = get_tree().create_timer(Piece.MOVE_TIME)
		timer.timeout.connect(move.take_piece.queue_free)
		capture.play()

	elif move.type == Moves.CASTLE and not is_in_check():
		castle.play()
		var rook: Piece
		var x := pos.x
		if move.side == "long":
			rook = board[pos.y][0]
			x += 1
		else:
			rook = board[pos.y][7]
			x -= 1
		move_piece(Vector2i(x, pos.y), rook)

	if move.has("promote"):
		promote.play()
		$Board.queue_redraw()
		state = State.PROMOTING
		await selected_piece.promote_menu(pos)
		state = State.RUNNING

	turn = "black" if turn == "white" else "white"
	selected_piece = null

	var white_king_alive := false
	var black_king_alive := false
	for row in board:
		for piece in row:
			if not piece or piece.piece_id != Piece.KING:
				continue
			if piece.team == "white":
				white_king_alive = true
			elif piece.team == "black":
				black_king_alive = true

	if not white_king_alive:
		state = State.ENDED
		game_end.play()
		$UI/ChaosLog.text = "Black wins!"
		return
	elif not black_king_alive:
		state = State.ENDED
		game_end.play()
		$UI/ChaosLog.text = "White wins!"
		return

	if no_legal_moves():
		state = State.ENDED
		game_end.play()
		if not is_in_check():
			$UI/ChaosLog.text = "Stalemate!"
		else:
			$UI/ChaosLog.text = turn.capitalize() + " is Checkmated!"
		return  # <-- Critical return to stop AI from continuing

	if is_in_check():
		move_check.play()
		print("Check!")

	if ai_enabled and turn == "black" and state == State.RUNNING:
		await get_tree().create_timer(0.5).timeout
		ai_make_move()

func get_move_notation(piece: Piece, pos: Vector2i) -> String:
	var piece_letter := ""
	match piece.piece_id:
		Piece.KNIGHT: piece_letter = "N"
		Piece.BISHOP: piece_letter = "B"
		Piece.ROOK: piece_letter = "R"
		Piece.QUEEN: piece_letter = "Q"
		Piece.KING: piece_letter = "K"
		_: piece_letter = ""
	return piece_letter + pos_to_algebraic(pos)

func pos_to_algebraic(pos: Vector2i) -> String:
	var file := char('a'.unicode_at(0) + pos.x)
	var rank := str(8 - pos.y)
	return file + rank

func update_move_list():
	var label = $UI/MovePanel/MoveList
	label.clear()
	for move in move_history:
		label.append_text(move + "\n")

func ai_make_move():
	print("AI is calculating move...")
	var best_move: Dictionary = CPU.get_best_move(board, "black")
	print("AI chose move: ", best_move)
	if best_move.size() == 0:
		print("AI found no move (likely game over).")
		return

	var from_pos: Vector2i = best_move["from"]
	var to_pos: Vector2i = best_move["to"]

	if board[from_pos.y][from_pos.x] == null:
		print("Piece not found at AI 'from' position!")
		return

	selected_piece = board[from_pos.y][from_pos.x]
	moves = get_legal_moves(selected_piece)
	if moves.has(to_pos):
		make_move(to_pos)
	else:
		print("AI tried illegal move!")
	selected_piece = null

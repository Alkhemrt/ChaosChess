extends Node

const CHAOS_CHANCE := 0.5

var chaos_events = [
	"swap_two_random_pieces",
	"promote_random_pawn",
	"change_piece_type",
	"random_teleport",
	"traitor_piece",
	"suicide"
]

func trigger_chaos(board) -> void:
	await trigger_chaos_delayed(board)

func trigger_chaos_delayed(board) -> void:
	var main := get_node("/root/Main")
	var log_label := get_node("/root/Main/UI/ChaosLog")
	main.state = main.State.ENDED

	log_label.text = "Loading"
	for i in 3:
		await get_tree().create_timer(0.4).timeout
		log_label.text += "."
	await get_tree().create_timer(0.3).timeout

	if randf() > CHAOS_CHANCE:
		log_label.text = "None"
		main.state = main.State.RUNNING
		return

	var original_board = deep_copy_board(board)
	var event = chaos_events[randi() % chaos_events.size()]
	var message := ""

	match event:
		"swap_two_random_pieces":
			message = swap_two_random_pieces(board)
		"promote_random_pawn":
			message = promote_random_pawn(board)
		"change_piece_type":
			message = change_piece_type(board)
		"random_teleport":
			message = random_teleport(board)
		"traitor_piece":
			message = traitor_piece(board)
		"suicide":
			message = suicide(board)

	if causes_check_or_checkmate(board):
		restore_board(board, original_board)
		message = "None"

	if message == "" or message.begins_with("Could not") or message.begins_with("No "):
		message = "None"

	log_label.text = message
	main.state = main.State.RUNNING


func change_piece_type(board) -> String:
	var pool := []
	for row in board:
		for piece in row:
			if piece and piece.piece_id != Piece.KING:
				pool.append(piece)
	if pool.is_empty():
		return "No valid piece to change."
	var piece = pool[randi() % pool.size()]
	var new_type = randi() % 5
	while new_type == piece.piece_id:
		new_type = randi() % 5
	piece.piece_id = new_type
	piece.queue_redraw()
	return "Piece type changed!"


func random_teleport(board) -> String:
	var empty := []
	var movable := []
	for y in range(8):
		for x in range(8):
			var p = board[y][x]
			if not p:
				empty.append(Vector2i(x, y))
			elif p.piece_id != Piece.KING:
				movable.append(p)
	if empty.is_empty() or movable.is_empty():
		return "No teleport possible."
	var piece = movable[randi() % movable.size()]
	var new_pos = empty[randi() % empty.size()]
	board[piece.pos.y][piece.pos.x] = null
	board[new_pos.y][new_pos.x] = piece
	piece.move_animation(new_pos)
	piece.pos = new_pos
	return "A piece teleported!"


func traitor_piece(board) -> String:
	var candidates := []
	for row in board:
		for piece in row:
			if piece and piece.piece_id != Piece.KING:
				candidates.append(piece)
	if candidates.is_empty():
		return "No piece to betray."
	var piece = candidates[randi() % candidates.size()]
	piece.team = "white" if piece.team == "black" else "black"
	if piece.team == "black":
		piece.texture = preload("res://assets/black.png")
	else:
		piece.texture = preload("res://assets/white.png")
	return "A piece was a spy!"


func suicide(board) -> String:
	var candidates := []
	for row in board:
		for piece in row:
			if piece and piece.piece_id != Piece.KING:
				candidates.append(piece)
	if candidates.is_empty():
		return "No piece to destroy."
	var piece = candidates[randi() % candidates.size()]
	board[piece.pos.y][piece.pos.x] = null
	piece.queue_free()
	return "A piece gave up!"


func promote_random_pawn(board) -> String:
	var pawns = []
	for row in board:
		for piece in row:
			if piece and piece.piece_id == Piece.PAWN:
				pawns.append(piece)
	if pawns.is_empty():
		return "No pawns available to promote."
	var pawn = pawns[randi() % pawns.size()]
	pawn.piece_id = Piece.QUEEN
	pawn.queue_redraw()
	return "Random promotion!"


func swap_two_random_pieces(board) -> String:
	var valid = []
	for row in board:
		for piece in row:
			if piece and piece.piece_id != Piece.KING:
				if piece.piece_id == Piece.PAWN and (piece.pos.y == 0 or piece.pos.y == 7):
					continue
				valid.append(piece)
	if valid.size() < 2:
		return "Could not find valid pieces to swap."
	var a = null
	var b = null
	var attempts := 0
	while attempts < 100:
		a = valid[randi() % valid.size()]
		b = valid[randi() % valid.size()]
		if a != b:
			break
		attempts += 1
	if a == b:
		return "Failed to find two distinct pieces."
	var pos_a = a.pos
	var pos_b = b.pos
	board[pos_a.y][pos_a.x] = b
	board[pos_b.y][pos_b.x] = a
	a.pos = pos_b
	b.pos = pos_a
	a.move_animation(pos_b)
	b.move_animation(pos_a)
	return "Swapped two pieces!"


# --- Utility ---

func causes_check_or_checkmate(board: Array) -> bool:
	var main = get_node("/root/Main")
	var turn = main.turn
	var king_in_check := false
	var has_moves := false
	for row in board:
		for piece in row:
			if piece and piece.team == turn:
				var moves = main.get_legal_moves(piece)
				if moves.size() > 0:
					has_moves = true
			elif piece and piece.piece_id == Piece.KING and piece.team != turn:
				var moves = main.get_legal_moves(piece)
				for move in moves.values():
					if move.type == Moves.CAPTURE and move.take_piece.piece_id == Piece.KING:
						king_in_check = true
	if king_in_check or not has_moves:
		return true
	return false

func deep_copy_board(original_board: Array) -> Array:
	var new_board := []
	for y in range(original_board.size()):
		var new_row := []
		for x in range(original_board[y].size()):
			var piece = original_board[y][x]
			if piece:
				var copy = piece.duplicate()
				copy.set_script(piece.get_script())
				copy.pos = piece.pos
				copy.piece_id = piece.piece_id
				copy.team = piece.team
				copy.last_move_round = piece.last_move_round
				copy.texture = piece.texture
				new_row.append(copy)
			else:
				new_row.append(null)
		new_board.append(new_row)
	return new_board

func restore_board(board: Array, backup: Array) -> void:
	for y in range(board.size()):
		for x in range(board[y].size()):
			board[y][x] = backup[y][x]

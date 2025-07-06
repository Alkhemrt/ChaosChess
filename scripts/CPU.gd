extends Node

var previous_ai_move = null

func get_best_move(board: Array, team: String) -> Dictionary:
	var king_captures = []
	var promotions = []
	var queen_captures = []
	var castle_moves = []
	var capture_moves = []
	var escape_moves = []
	var center_pawn_pushes = []
	var legal_moves = []

	for y in range(8):
		for x in range(8):
			var piece = board[y][x]
			if piece == null or piece.team != team:
				continue

			var moves = get_legal_moves(board, piece, team)
			for move_pos in moves.keys():
				var target = moves[move_pos].take_piece if moves[move_pos].has("take_piece") else null
				var move = {
					"from": piece.pos,
					"to": move_pos,
					"piece": piece,
					"type": moves[move_pos].type,
					"target": target
				}

				if target != null and target.piece_id == Piece.KING and target.team != team:
					king_captures.append(move)
				elif is_pawn_promotion(piece, move_pos):
					promotions.append(move)
				elif target != null and target.piece_id == Piece.QUEEN and target.team != team and is_trade_favorable_or_equal(piece, target):
					queen_captures.append(move)
				elif is_castling_move(piece, move_pos):
					castle_moves.append(move)
				elif target != null and is_trade_favorable_or_equal(piece, target):
					capture_moves.append(move)
				elif is_center_pawn_push(piece, move_pos):
					center_pawn_pushes.append(move)
				elif is_under_attack(board, piece.pos, team) and not is_trade_losing(piece, target):
					escape_moves.append(move)
				else:
					legal_moves.append(move)

	if king_captures.size() > 0:
		return choose_non_repeating(king_captures)
	if promotions.size() > 0:
		return choose_non_repeating(promotions)
	if queen_captures.size() > 0:
		return choose_non_repeating(queen_captures)
	if castle_moves.size() > 0:
		return choose_non_repeating(castle_moves)
	if capture_moves.size() > 0:
		return choose_non_repeating(capture_moves)
	if escape_moves.size() > 0:
		return choose_non_repeating(escape_moves)
	if center_pawn_pushes.size() > 0:
		return choose_non_repeating(center_pawn_pushes)
	if legal_moves.size() > 0:
		return choose_non_repeating(legal_moves)

	return {}

func choose_non_repeating(moves: Array) -> Dictionary:
	for move in moves:
		if previous_ai_move == null or (move["from"] != previous_ai_move["to"] or move["to"] != previous_ai_move["from"]):
			previous_ai_move = move
			return move
	previous_ai_move = moves[0]
	return moves[0]

func is_castling_move(piece, to_pos: Vector2i) -> bool:
	return piece.piece_id == Piece.KING and abs(to_pos.x - piece.pos.x) == 2

func is_trade_favorable_or_equal(piece, target) -> bool:
	if target == null:
		return false
	return piece.piece_value <= target.piece_value

func is_trade_losing(piece, target) -> bool:
	if target == null:
		return false
	return piece.piece_value > target.piece_value

func is_center_pawn_push(piece, to_pos: Vector2i) -> bool:
	if piece.piece_id != Piece.PAWN:
		return false
	return to_pos == Vector2i(3, 3) or to_pos == Vector2i(4, 3)

func is_pawn_promotion(piece, to_pos: Vector2i) -> bool:
	if piece.piece_id != Piece.PAWN:
		return false
	return (piece.team == "white" and to_pos.y == 0) or (piece.team == "black" and to_pos.y == 7)

func is_under_attack(board: Array, pos: Vector2i, team: String) -> bool:
	var opp = opposite_team(team)
	for row in board:
		for enemy in row:
			if enemy and enemy.team == opp:
				var moves = enemy.get_moves(board)
				if moves.has(pos) and moves[pos].type == Moves.CAPTURE:
					return true
	return false

func get_legal_moves(board: Array, piece, team: String) -> Dictionary:
	var raw_moves = piece.get_moves(board)
	var legal_moves = {}
	var original_pos = piece.pos

	for move_pos in raw_moves.keys():
		var captured = null
		if raw_moves[move_pos].type == Moves.CAPTURE:
			captured = raw_moves[move_pos].take_piece
			board[captured.pos.y][captured.pos.x] = null

		board[piece.pos.y][piece.pos.x] = null
		board[move_pos.y][move_pos.x] = piece
		piece.pos = move_pos

		if !is_in_check(board, team):
			legal_moves[move_pos] = raw_moves[move_pos]

		piece.pos = original_pos
		board[move_pos.y][move_pos.x] = null
		board[piece.pos.y][piece.pos.x] = piece
		if captured:
			board[captured.pos.y][captured.pos.x] = captured

	return legal_moves

func is_in_check(board: Array, team: String) -> bool:
	for row in board:
		for piece in row:
			if piece and piece.team != team:
				for move in piece.get_moves(board).values():
					if move.type == Moves.CAPTURE and move.take_piece and move.take_piece.piece_id == Piece.KING:
						if move.take_piece.team == team:
							return true
	return false

func is_game_over(board: Array) -> bool:
	var has_white = false
	var has_black = false
	for row in board:
		for piece in row:
			if piece:
				if piece.piece_id == Piece.KING:
					if piece.team == "white":
						has_white = true
					elif piece.team == "black":
						has_black = true
	return !(has_white and has_black)

func opposite_team(team: String) -> String:
	return "black" if team == "white" else "white"

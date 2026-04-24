extends CanvasLayer

@onready var item_list = $ColorRect/VBoxContainer/ItemList
@onready var timer_label = $ColorRect/VBoxContainer/TimerLabel

func update_ui(stats: Dictionary):
	if not is_node_ready():
		await ready
	
	var sorted_players = stats.keys()
	sorted_players.sort_custom(func(a, b): return stats[a]["height"] > stats[b]["height"])
	
	var existing_rows = item_list.get_children()
	
	# Only rebuild rows if player count changed; otherwise update labels in-place
	if existing_rows.size() != sorted_players.size():
		for c in existing_rows:
			c.queue_free()
		for net_id in sorted_players:
			var p_data = stats[net_id]
			var hbox = HBoxContainer.new()
			
			var l_name = Label.new()
			l_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l_name.text = "Player " + str(net_id)
			if net_id == multiplayer.get_unique_id():
				l_name.text += " (You)"
				l_name.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			hbox.add_child(l_name)
			
			var l_kills = Label.new()
			l_kills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l_kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l_kills.text = str(p_data["kills"])
			hbox.add_child(l_kills)
			
			var l_height = Label.new()
			l_height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l_height.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l_height.text = str(p_data["height"]) + "m"
			hbox.add_child(l_height)
			
			item_list.add_child(hbox)
	else:
		# Update text of existing rows in-place — no node creation/deletion
		for i in range(sorted_players.size()):
			var net_id = sorted_players[i]
			var p_data = stats[net_id]
			var hbox = existing_rows[i]
			var labels = hbox.get_children()
			if labels.size() < 3:
				continue
			labels[0].text = "Player " + str(net_id) + (" (You)" if net_id == multiplayer.get_unique_id() else "")
			labels[1].text = str(p_data["kills"])
			labels[2].text = str(p_data["height"]) + "m"

func update_timer(seconds_remaining: float):
	if not is_node_ready():
		await ready
	var mins = int(seconds_remaining) / 60
	var secs = int(seconds_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	
	# Flash red when time is low
	if seconds_remaining <= 30:
		timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	else:
		timer_label.remove_theme_color_override("font_color")

extends Node

signal item_equipped(item_data: ItemData)

var categories = {
	ItemData.ItemCategory.WEAPON: [],
	ItemData.ItemCategory.GRENADE: [],
	ItemData.ItemCategory.TOOL: []
}

var category_indices = {
	ItemData.ItemCategory.WEAPON: 0,
	ItemData.ItemCategory.GRENADE: 0,
	ItemData.ItemCategory.TOOL: 0
}

var current_category: ItemData.ItemCategory = ItemData.ItemCategory.WEAPON

@onready var category_nodes = {
	ItemData.ItemCategory.WEAPON: $HUD/HotbarController/CategoryHBox/Category1_Weapons,
	ItemData.ItemCategory.GRENADE: $HUD/HotbarController/CategoryHBox/Category2_Throwable,
	ItemData.ItemCategory.TOOL: $HUD/HotbarController/CategoryHBox/Category3_Tools
}

# Sync variables for MultiplayerSynchronizer
@export var sync_current_cat: int = 0:
	set(v):
		sync_current_cat = v
		current_category = v as ItemData.ItemCategory
		if is_node_ready(): 
			update_ui()
			_emit_current_item()

@export var sync_weapon_idx: int = 0:
	set(v):
		sync_weapon_idx = v
		category_indices[ItemData.ItemCategory.WEAPON] = v
		if is_node_ready(): 
			update_ui()
			if current_category == ItemData.ItemCategory.WEAPON: _emit_current_item()

@export var sync_grenade_idx: int = 0:
	set(v):
		sync_grenade_idx = v
		category_indices[ItemData.ItemCategory.GRENADE] = v
		if is_node_ready(): 
			update_ui()
			if current_category == ItemData.ItemCategory.GRENADE: _emit_current_item()

@export var sync_tool_idx: int = 0:
	set(v):
		sync_tool_idx = v
		category_indices[ItemData.ItemCategory.TOOL] = v
		if is_node_ready(): 
			update_ui()
			if current_category == ItemData.ItemCategory.TOOL: _emit_current_item()

func _ready():
	# Inherit authority from player
	set_multiplayer_authority(get_parent().get_multiplayer_authority())
	
	_load_initial_items()
	
	# Only the local player sees their HUD
	if is_multiplayer_authority():
		$HUD.show()
		# Initial emission for local player
		call_deferred("_emit_current_item")
	else:
		$HUD.hide()
		# For others (like server), ensure UI is updated if they ever see it, 
		# but primarily ensure initial item is equipped on server-side
		if multiplayer.is_server():
			call_deferred("_emit_current_item")
	
	update_ui()

func _load_initial_items():
	# In a real game, this would be populated from a save or start inventory
	var initial_item_paths = [
		"res://scripts/Item Data/assult_rifle.tres",
		"res://scripts/Item Data/footbomb.tres",
		"res://scripts/Item Data/3x3Shovel.tres"
	]
	
	for path in initial_item_paths:
		if ResourceLoader.exists(path):
			var item = load(path)
			if item is ItemData:
				categories[item.category].append(item)

func change_category(category_index: int):
	if not is_multiplayer_authority(): return
	
	# category_index is 0, 1, or 2 (from keys 1, 2, 3)
	var new_cat = category_index as ItemData.ItemCategory
	if new_cat == current_category:
		# If pressing the same category key, cycle through items
		cycle_item(1)
	else:
		sync_current_cat = category_index

func cycle_item(direction: int):
	if not is_multiplayer_authority(): return
	
	var items = categories[current_category]
	if items.size() <= 1 and direction != 0: 
		# If only one item, still update UI/signal once to be sure
		if items.size() == 1:
			_emit_current_item()
		return
	
	var new_idx = (category_indices[current_category] + direction + items.size()) % items.size()
	
	# Update the correct sync variable
	match current_category:
		ItemData.ItemCategory.WEAPON: sync_weapon_idx = new_idx
		ItemData.ItemCategory.GRENADE: sync_grenade_idx = new_idx
		ItemData.ItemCategory.TOOL: sync_tool_idx = new_idx

func _emit_current_item():
	var items = categories[current_category]
	if items.size() > 0:
		var item = items[category_indices[current_category]]
		item_equipped.emit(item)

func update_ui():
	for cat in category_nodes:
		var node = category_nodes[cat]
		var is_active = (cat == current_category)
		
		# Dim inactive categories
		node.modulate.a = 1.0 if is_active else 0.4
		
		var items = categories[cat]
		var idx = category_indices[cat]
		
		# Determine slot names based on category
		var prefix = ""
		match cat:
			ItemData.ItemCategory.WEAPON: prefix = "weapon"
			ItemData.ItemCategory.GRENADE: prefix = "throwable"
			ItemData.ItemCategory.TOOL: prefix = "tool"
			
		_update_slot(node.get_node("previous_" + prefix), items, idx - 1)
		_update_slot(node.get_node("active_" + prefix), items, idx)
		_update_slot(node.get_node("next_" + prefix), items, idx + 1)

func _update_slot(slot_node: Control, items: Array, index: int):
	var texture_rect = slot_node.get_node_or_null("TextureRect")
	if not texture_rect: return
	
	if items.size() == 0:
		texture_rect.texture = null
		slot_node.visible = false
		return
	
	slot_node.visible = true
	var actual_idx = (index + items.size()) % items.size()
	var item = items[actual_idx]
	texture_rect.texture = item.icon

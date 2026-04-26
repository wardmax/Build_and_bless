extends Control

signal purchase_requested(item_id: String, price: int)

@export var store_items: Array = [
	{ "id": "ammo", "name": "Ammo", "price": 10, "icon": null },
	{ "id": "footbomb", "name": "Footbomb", "price": 20, "icon": null },
	{ "id": "shovel_radius", "name": "Increase Shovel Radius", "price": 50, "icon": null },
	{ "id": "shovel_speed", "name": "Increase Shovel Speed", "price": 10, "icon": null },
	{ "id": "double_jump", "name": "Double Jump", "price": 10, "icon": null }
]

var current_page: int = 0
const ITEMS_PER_PAGE: int = 3

@onready var prev_button = $GridContainer/UpgradesPages
@onready var next_button = $GridContainer/WeaponsPages

@onready var slot_containers = [
	$GridContainer/VBoxContainer,
	$GridContainer/VBoxContainer2,
	$GridContainer/VBoxContainer3
]

func _ready():
	prev_button.pressed.connect(_on_prev_page_pressed)
	next_button.pressed.connect(_on_next_page_pressed)
	
	for i in range(slot_containers.size()):
		var buy_button = slot_containers[i].get_child(1).get_child(0)
		buy_button.pressed.connect(_on_buy_button_pressed.bind(i))
		
	update_ui()

func update_ui():
	var total_pages = ceil(store_items.size() / float(ITEMS_PER_PAGE))
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page >= total_pages - 1)
	
	var start_idx = current_page * ITEMS_PER_PAGE
	
	for i in range(slot_containers.size()):
		var container = slot_containers[i]
		var item_idx = start_idx + i
		
		if item_idx < store_items.size():
			container.show()
			var item = store_items[item_idx]
			
			var name_label = container.get_child(0)
			var price_label = container.get_child(1).get_child(1)
			
			name_label.text = item.name
			price_label.text = str(item.price)
		else:
			container.hide()

func _on_prev_page_pressed():
	if current_page > 0:
		current_page -= 1
		update_ui()

func _on_next_page_pressed():
	var total_pages = ceil(store_items.size() / float(ITEMS_PER_PAGE))
	if current_page < total_pages - 1:
		current_page += 1
		update_ui()

func _on_buy_button_pressed(slot_index: int):
	var item_idx = (current_page * ITEMS_PER_PAGE) + slot_index
	if item_idx < store_items.size():
		var item = store_items[item_idx]
		purchase_requested.emit(item.id, item.price)

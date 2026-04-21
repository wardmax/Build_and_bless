class_name ItemData extends Resource

enum ItemCategory { WEAPON, GRENADE, TOOL }

@export var item_name: String = "Item"
@export var icon: Texture2D
@export var category: ItemCategory = ItemCategory.WEAPON
@export var item_scene: PackedScene

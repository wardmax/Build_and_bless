extends Node

@export var models : Array[PackedScene]
var save_path = "res://screencapture/screenshots/"
var viewport : Viewport


func _ready() -> void:
	create_images()


func create_images():
	viewport = get_viewport()
	viewport.transparent_bg = true
	
	for model in $MeshInstance3D:
		var model_instance = model.instantiate()
		add_child(model_instance)
		await RenderingServer.frame_post_draw
		
		var image =  viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.save_png(save_path + "%s.png" %model_instance.name)
		model_instance.queue_free()
		
	print("Done")
	get_tree().quit()

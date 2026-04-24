@tool
extends EditorPlugin

const AUTOLOAD_NAME = "DevConsole"
const AUTOLOAD_PATH = "res://addons/Console/console.gd"

func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	print("[MyConsole] Plugin enabled. Use DevConsole from anywhere.")

func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	print("[MyConsole] Plugin disabled.")

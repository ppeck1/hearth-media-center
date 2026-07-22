class_name HearthInputActions
extends RefCounted

const NAVIGATE_UP := "navigate_up"
const NAVIGATE_DOWN := "navigate_down"
const NAVIGATE_LEFT := "navigate_left"
const NAVIGATE_RIGHT := "navigate_right"
const SELECT := "select"
const BACK := "back"
const HOME := "home"
const MENU := "menu"
const PLAY_PAUSE := "play_pause"
const PAGE_LEFT := "page_left"
const PAGE_RIGHT := "page_right"

const DEFINITIONS: Array[Dictionary] = [
	{"id": NAVIGATE_UP, "label": "Navigate up"},
	{"id": NAVIGATE_DOWN, "label": "Navigate down"},
	{"id": NAVIGATE_LEFT, "label": "Navigate left"},
	{"id": NAVIGATE_RIGHT, "label": "Navigate right"},
	{"id": SELECT, "label": "Select"},
	{"id": BACK, "label": "Back"},
	{"id": HOME, "label": "Hearth home"},
	{"id": MENU, "label": "Menu / options"},
	{"id": PLAY_PAUSE, "label": "Play / pause"},
	{"id": PAGE_LEFT, "label": "Previous page"},
	{"id": PAGE_RIGHT, "label": "Next page"},
]

const RECOVERY_UI_ACTIONS := {
	NAVIGATE_UP: "ui_up",
	NAVIGATE_DOWN: "ui_down",
	NAVIGATE_LEFT: "ui_left",
	NAVIGATE_RIGHT: "ui_right",
	SELECT: "ui_accept",
	BACK: "ui_cancel",
}

static func label_for(action_id: String) -> String:
	for definition in DEFINITIONS:
		if definition["id"] == action_id:
			return definition["label"]
	return action_id.replace("_", " ").capitalize()

static func ids() -> Array[String]:
	var result: Array[String] = []
	for definition in DEFINITIONS:
		result.append(definition["id"])
	return result

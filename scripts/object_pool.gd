class_name ObjectPool
extends RefCounted
## Generic scene pool. Nodes are never queue_free'd — they die with their parent.

enum GrowPolicy { GROW_WARN, DROP }

var _scene: PackedScene
var _parent: Node
var _cap: int
var _grow_policy: GrowPolicy
var _free: Array[Node] = []
var _live: Array[Node] = []


func _init(
	scene: PackedScene,
	parent: Node,
	prewarm: int,
	cap: int,
	grow_policy: GrowPolicy = GrowPolicy.GROW_WARN
) -> void:
	_scene = scene
	_parent = parent
	_cap = cap
	_grow_policy = grow_policy
	for _i: int in prewarm:
		_free.append(_make_inactive())


func acquire() -> Node:
	var node: Node = null
	if not _free.is_empty():
		node = _free.pop_back()
	elif _live_and_free_count() < _cap:
		node = _make_inactive()
	elif _grow_policy == GrowPolicy.GROW_WARN:
		push_warning("ObjectPool over cap (%d) for %s — growing" % [_cap, _scene.resource_path])
		node = _make_inactive()
	else:
		return null
	_live.append(node)
	return node


func release(node: Node) -> void:
	if node == null or not _live.has(node):
		return
	_live.erase(node)
	_deactivate(node)
	if not _free.has(node):
		_free.append(node)


func live_count() -> int:
	return _live.size()


func free_count() -> int:
	return _free.size()


## Oldest live node (index 0), or null. Used by floater steal-recycle.
func oldest_live() -> Node:
	if _live.is_empty():
		return null
	return _live[0]


func _live_and_free_count() -> int:
	return _live.size() + _free.size()


func _make_inactive() -> Node:
	var node: Node = _scene.instantiate()
	_parent.add_child(node)
	_deactivate(node)
	return node


func _deactivate(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED

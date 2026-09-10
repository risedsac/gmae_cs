extends SceneTree
func _initialize():call_deferred("run")
func run():
 for name_ in ClassDB.class_get_integer_constant_list("Environment"):
  if "REFLECT" in name_:print(name_,"=",ClassDB.class_get_integer_constant("Environment",name_))
 var factory=load("res://scripts/weapons.gd")
 for i in [2,3]:
  var node=factory.make(i,true);root.add_child(node)
  var doc=GLTFDocument.new();var state=GLTFState.new()
  var error=doc.append_from_scene(node,state)
  if error==OK:error=doc.write_to_filesystem(state,"res://assets/"+("m4a1" if i==2 else "awp")+".glb")
  print("MODEL_EXPORT ",i," ",error);node.free()
 quit()

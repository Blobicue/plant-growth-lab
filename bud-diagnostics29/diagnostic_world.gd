extends "res://world.gd"
var policy_mode=0
var target_id=-1
func policy_collect(p,net:float):
 if policy_mode in [1,3,5,6] and p.plant_id==target_id and p.nodes.size()<32:return
 super.policy_collect(p,net)
func step(reverse:bool=false):
 for p in plants:
  p.hold_partial=policy_mode in [2,3,4,5] and p.plant_id==target_id
  p.hold_leaves=policy_mode in [4,5,6,7] and p.plant_id==target_id
 super.step(reverse)
 for p in plants:p.finish_hour()

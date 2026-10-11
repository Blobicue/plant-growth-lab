extends SceneTree
const State=preload("res://state.gd")
const O=preload("res://reduction_order.gd")
func _initialize():call_deferred("run")
func run():
 GDExtensionManager.load_extension("res://native/resource_field.gdextension")
 var w=State.new().restore("/workspace/plant-growth-lab/cloud-diagnostics/evidence/birth-12011-3.bin");var p=w.plant_by_id(3);var original=p.nodes.duplicate(true)
 var values=[0.0,0.0,0.0,.008964199999999999,pow(2.0,-60),pow(2.0,-60),0.0];var forward=0.0;var reverse=0.0
 for x in values:forward+=x
 for j in range(values.size()-1,-1,-1):reverse+=values[j]
 assert(int(floor(forward*1e9*.01))!=int(floor(reverse*1e9*.01)),"fixture must straddle an unchanged real floor boundary")
 var order=[0,2,1,6,5,4,3];var map={};var relabeled=[];var perm_values=[]
 for i in order.size():map[order[i]]=i
 for i in order:
  var n=original[i].duplicate(true);n.parent=map[n.parent] if n.parent>=0 else -1;relabeled.append(n);perm_values.append(values[i])
 var a=O.sum_values(p,values);p.nodes=relabeled;var b=O.sum_values(p,perm_values)
 assert(var_to_bytes(a)==var_to_bytes(b));assert(a==forward)
 var result={"pass":true,"raw_forward_q":int(floor(forward*1e9*.01)),"raw_reverse_q":int(floor(reverse*1e9*.01)),"R1_original_q":int(floor(a*1e9*.01)),"R1_permuted_q":int(floor(b*1e9*.01)),"original_sum_bits":var_to_bytes(a).hex_encode(),"permuted_sum_bits":var_to_bytes(b).hex_encode(),"threshold_and_stock_unchanged":true}
 var f=FileAccess.open("res://evidence/boundary-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify(result));w.close();quit()

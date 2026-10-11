extends SceneTree
const T=preload("res://transport.gd")
func _initialize():call_deferred("run")
func flatten(a)->PackedFloat64Array:
 var out=PackedFloat64Array()
 for row in a:
  for value in row:out.append(float(value))
 return out
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string("/workspace/plant-growth-lab/cloud-transport/evidence/fixtures.json"));var checks=[];var maximum_error=0.0;var maximum_ledger=0.0
 for c in data.cases:
  var n=c.keys.size();var original=flatten(c.values);var reference=flatten(c.expected24);var edges=[];var rates=PackedFloat64Array(c.rates)
  for e in c.edges:edges.append(Vector2i(int(e[0]),int(e[1])))
  var canonical_result=T.advance(original,edges,rates,c.keys,24);var total=[0.0,0.0,0.0];var after=[0.0,0.0,0.0];var minimum=[INF,INF,INF];var maximum=[0.0,0.0,0.0]
  for i in n:
   for k in 3:total[k]+=original[3*i+k];after[k]+=canonical_result.values[3*i+k];minimum[k]=minf(minimum[k],original[3*i+k]);maximum[k]=maxf(maximum[k],original[3*i+k])
  for i in n:
   for k in 3:
    var value=canonical_result.values[3*i+k];var tolerance=maxf(total[k],1e-30)*1e-12
    assert(value>=0.0 and value>=minimum[k]-tolerance and value<=maximum[k]+tolerance,"positivity/max principle")
    assert(absf(value-reference[3*i+k])<=tolerance,"independent reference")
    maximum_error=maxf(maximum_error,absf(value-reference[3*i+k])/maxf(total[k],1e-30))
  for k in 3:assert(absf(total[k]-after[k])<=maxf(total[k],1e-30)*1e-12);maximum_ledger=maxf(maximum_ledger,absf(total[k]-after[k])/maxf(total[k],1e-30))
  assert(canonical_result.maximum_sender_fraction<1.0)
  for variant in 6:
   var order=range(n)
   if variant%2==1:order.reverse()
   if variant>=2:for _j in mini(n,variant):order.push_back(order.pop_front())
   var inverse={};var keys=[];var values=PackedFloat64Array()
   for i in n:inverse[order[i]]=i;keys.append(c.keys[order[i]]);values.append_array(original.slice(3*order[i],3*order[i]+3))
   var shuffled=[];var shuffled_rates=PackedFloat64Array();var indices=range(edges.size())
   if variant%2==0:indices.reverse()
   for z in indices:shuffled.append(Vector2i(inverse[edges[z].x],inverse[edges[z].y]));shuffled_rates.append(rates[z])
   var result=T.advance(values,shuffled,shuffled_rates,keys,24)
   for i in n:
    for k in 3:assert(result.values[3*inverse[i]+k]==canonical_result.values[3*i+k],"exact canonical permutation equivariance")
  checks.append({"fixture":c.name,"permutations_exact":6,"effective_steps":canonical_result.steps,"sender_fraction":canonical_result.maximum_sender_fraction,"pass":true})
 var result={"fixture_count":checks.size(),"permutation_checks":checks.size()*6,"max_reference_relative_error":maximum_error,"max_conservation_relative_error":maximum_ledger,"checks":checks,"pass":true}
 var f=FileAccess.open("res://evidence/kernel-checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print(JSON.stringify({"fixtures":checks.size(),"permutations":checks.size()*6,"pass":true}));quit()

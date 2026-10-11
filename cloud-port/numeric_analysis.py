"""Explain report-only differences; never replace strict golden or physical gates."""
from pathlib import Path
from decimal import Decimal,getcontext,ROUND_HALF_UP
import json,math,struct,collections
getcontext().prec=100
P=Path(__file__).resolve().parent;R=P.parent;E=P/'evidence'
def at(obj,path):
 for key in path.strip('/').split('/'):obj=obj[int(key)] if isinstance(obj,list) else obj[key]
 return obj
def quantum(x):
 x=abs(x)
 return Decimal(10)**max(-32,(x.adjusted()-14 if x else -32))
def exact_bits(s):return Decimal.from_float(struct.unpack('<d',bytes.fromhex(s))[0])
results=[]
for name in ['shared-atmosphere27','juvenile-allocation30']:
 source=json.loads((E/(name+'-cloud-numeric-diagnostics.json')).read_text());references={};rows=[]
 for row in source['rows']:
  key=(row['seed'],row['mode'])
  if key not in references:references[key]=json.loads((R/name/'evidence'/f'matrix-{key[0]}-{key[1]}.json').read_text(),parse_float=Decimal,parse_int=Decimal)
  sample=next(x for x in references[key]['samples'] if x['tick']==row['tick']);original=at(sample,row['path']);raw=exact_bits(row['raw_bits'])
  # Archive serialization promises approx. 15 significant digits. Adjacent
  # decimal rounding intervals can touch; binary conversion at their boundary
  # contributes <=1 ulp per endpoint. No blanket absolute/relative tolerance.
  q=quantum(original);ulp=Decimal.from_float(math.ulp(float(original)))
  distance=abs(raw-original);bound=q/2+ulp
  canonical_exact=row['actual_full']==row['expected_roundtrip_full']
  rows.append({**row,'archive_decimal':str(original),'raw_exact_decimal':str(raw),'archive_rounding_half_quantum':str(q/2),'binary_conversion_ulp':str(ulp),'raw_archive_distance':str(distance),'raw_within_archive_rounding_interval':distance<=bound,'expected_roundtrip_equals_actual':canonical_exact,'shortest_decimal_half_up_reproduces_archive':Decimal(row['raw_full']).quantize(q,rounding=ROUND_HALF_UP)==original})
 results.append({'project':name,'checkpoints':len(source['fingerprints']),'all_state_checkpoints_exact':all(x['exact']for x in source['fingerprints']),'strict_scalar_mismatches':len(rows),'canonical_report_matches':sum(x['expected_roundtrip_equals_actual']for x in rows),'raw_within_archive_rounding_interval':sum(x['raw_within_archive_rounding_interval']for x in rows),'residual_rounding_boundary_cases':sum(not x['expected_roundtrip_equals_actual'] for x in rows),'residual_half_up_emulation_matches':sum(not x['expected_roundtrip_equals_actual'] and x['shortest_decimal_half_up_reproduces_archive'] for x in rows),'rows':rows,'parser_probes':source['parser_probes']})
out={'criterion':'Diagnostic report agreement: exact integer/count/string/structure checks and full-state hashes remain mandatory. For raw binary floating metrics versus archived decimal, require membership in the archive formatter rounding interval: abs(raw - decimal) <= 0.5*10^max(-32,floor(log10(abs(decimal)))-14) + one binary64 ulp. This is not a conservation tolerance and does not turn strict equality failures into passes. Known default JSON parser truncation must be diagnosed separately; new diagnostic reports preserve full-precision strings and raw float bits.','results':results}
(E/'numeric-analysis.json').write_text(json.dumps(out,indent=2))
print(json.dumps([{k:v for k,v in x.items()if k not in ['rows','parser_probes']}for x in results],indent=2))

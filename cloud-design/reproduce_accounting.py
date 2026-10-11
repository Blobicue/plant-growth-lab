#!/usr/bin/env python3
"""Read archived observer evidence; never invoke the simulator or change evidence."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = []
for seed in (12011, 4242, 7301):
    archive = json.loads((root / f'cloud-diagnostics/evidence/observer-{seed}-12288.json').read_text())
    for plant in archive['plants']:
        refusal = next(e for e in plant['events'] if e['event'] == 'refusal_root_["n"]')
        data = refusal['data']
        count = 7 + sum(e['event'].startswith('built_node_') and e['age'] <= refusal['age'] for e in plant['events'])
        mobile_n = data['pools']['n']
        rows.append(dict(seed=seed, id=plant['id'], generation=plant['generation'],
                         age=refusal['age'], packets=count, front_N=data['local']['n'],
                         root_N_cost=data['cost']['n'], connected_mobile_N=mobile_n,
                         frozen_equal_pool_mean=mobile_n/count,
                         hypothetical_mean_after_one_stem=(mobile_n-.0024*.024)/(count+1),
                         note='Static accounting illustration, not a trajectory or transport feasibility claim.'))
expected = json.loads((root / 'cloud-design/evidence/frozen-pool-accounting.json').read_text())
assert rows == expected, 'Archived arithmetic differs'
assert len(rows) == 11
print(json.dumps({'cohorts_checked': len(rows), 'arithmetic_matches': True, 'simulator_invoked': False}))

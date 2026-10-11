F1 fresh-founder comparison — authorized local execution
Frozen protocol: ../cloud-budget/NEXT-EXPERIMENT.txt (unchanged; digest in manifest).
Model basis5d3a8ef; budget/preregistration basis911a206. Local branch
experiment/fresh-founder-f1. No push/merge/promotion, no feedback or tuning.

setup.py clones the completed R1/T1 runtime to ignored work/model and changes only
passive plant observation and observation persistence in saved states. All actual
numerical/biological modules remain byte-identical. Founders now receive the same
budget diagnostics as descendants. Respiration call classification records paid
upkeep, stress recovery and tips without altering calls. Added proposal records
retain actual local payment stocks, current short resources and previous blocked
labels separately. No instrumentation is consumed by model decisions.

preflight.gd checks3*96 fresh legacy golden hashes plus768 completed T1 hashes.
manifest.json freezes initial source/configs, selected96h canonical checks on each
T1 world's first paid descendant,6144h restart+96h reverse replay, and recovery.
No earlier trajectory has the full F1 model/history/observer contract; none is
reused as a fresh result. Legacy runs check every original first960h hash and
8160/12288 endpoint fingerprints during execution.

Daily files are written before an atomic binary state, then an atomic latest.json
pointer. Every day state is retained in work/model/evidence/f1-SEED-MODE. Hourly
hashes and daily plant/environment rows are packed into tracked daily.jsonl.gz upon
completion. Full daily binary states stay locally in ignored work; their digests
are tracked, and6144/12288 states are also copied into committed evidence.
A recovering run resumes only the latest fully committed day. Any interrupted
partial-day output is deterministically replaced.600s slices are scheduler stops,
not biological endpoints; total primary engine wall time remains <=1800s as frozen.
A genuine correctness or resource failure stops the dependent queue for diagnosis.
No biological horizon extension or early outcome-based selection is permitted.

Commands from repository root:
python3 cloud-fresh/setup.py                 # fresh work only; refuses overwrite
python3 cloud-fresh/run.py --timeout 300 model preflight.gd
python3 cloud-fresh/run_matrix.py            # serial, resumable, fixed six cases
python3 cloud-fresh/run_founder_checks.py    # three selected canonical replays
python3 cloud-fresh/archive_selected.py
python3 cloud-fresh/analyze.py
python3 cloud-fresh/audit.py
The completed preflight's result must exist before starting the matrix. Every
launcher record includes exact engine arguments, source hashes and measured
RSS/headroom. Original native GPU/Windows tests remain unavailable, not passed.

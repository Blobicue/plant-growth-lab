PLANT RESEARCH WORKSTATION / Linux candidate 0.1.0

Scope: six completed F1 runs (three seeds, legacy+R1 and T1/24+R1), paired
world outcomes/resources, all plants' lineage and carbon budgets, exact archived
checkpoint replay, and model/provenance reports. No biology changes or promotion.
W27 and original candidate30 have report/provenance entries, not new binary-state
adapters. Their existing native workstations and the Windows W27 default remain
untouched. Root feedback and the proposed mechanism assay were not implemented.

Launch the self-contained LOCAL Linux package on a graphical Linux desktop.
From the extracted package directory, run ./launch.sh. In this saved checkout:
  cd /workspace/plant-growth-lab
  cloud-workstation/packages/model/launch.sh
In the saved cloud software display (start Xorg first if :99 is absent):
  Xorg :99 -config /workspace/plant-growth-lab/cloud-port/toolchain/xorg.conf \
    -logfile /workspace/plant-growth-lab/cloud-workstation/evidence/Xorg.log \
    -nolisten tcp -noreset
  DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 cloud-workstation/packages/model/launch.sh
The package is local and has not been hosted, pushed or installed over W27.
The existing guarded launcher serializes ownership, enforces >=8GiB headroom and
bounds each session to600 seconds. Use normal close to retain navigation choices.
There is no remote desktop/web delivery added by this task.

Use
1. Evidence catalog: select seed and transport arm. Paired outcomes always compare
   identical initial worlds; never pair altered descendants by their numeric ID.
2. Lineage & budgets: select a plant row. Death age and right-censored survival
   are distinct. End-minus-birth is elapsed observation time, not lifespan for a
   plant that died earlier. Maturity means the unchanged32-paid-node gate.
3. Paired resources: choose a common daily hour24..12288. Tables show model units,
   whole-world partitions and T1-minus-legacy differences, not invented receipts.
4. Saved-state replay: choose hour0,6144 or12288, then Load saved state. The actual
   binary loads into a separate paused, in-memory world. Replay checks every next
   hourly fingerprint, stopping after96h or at the recorded horizon. Step, Pause
   and STOP operate on this copy. Endpoint12288 is inspection-only. Right-drag to
   orbit; wheel to zoom. Geometry comes from actual saved tissue, not an illustration.
5. Provenance & commands: inspect model identity, guards, source paths and exact
   reproduction commands. Models & reports includes the complete audited reports.
6. Live lab: the existing candidate30+R1 ordered-transport UI, in a SEPARATE live
   world. Existing Step/Run/Pause/STOP, local inspection, saves and replay remain.
   The live pane does not silently adopt archive seed/transport/settings. GPU is
   disabled in this CPU candidate. Local control starts OFF and requires explicit
   opt-in; switching panes, STOP or closing revokes it and pauses computation.

Only run/pane selection persists across process reopen. No archived replay, live
run or access permission resumes automatically. Original archive files are never
written; binary SHA256 and model/seed/hour/fingerprint are checked before use.
A missing/changed checkpoint is blocked. Catalog source digests are auditable via
adapter-manifest.json. The copied catalog is derived from committed source evidence.

Build/reproduce in this saved checkout
  python3 cloud-workstation/setup.py         # first build only; refuses overwrite
  python3 cloud-workstation/sync_ui.py       # updates workstation UI only
  python3 cloud-workstation/run.py model workstation_checks.gd --gui
  python3 cloud-workstation/run.py model workstation_checks.gd --gui reopen
  python3 cloud-workstation/run.py model cpu_checks.gd
  python3 cloud-workstation/run.py model ui_checks.gd --gui
  python3 cloud-workstation/run.py model restart_checks.gd --gui
  python3 cloud-workstation/build_package.py
  python3 cloud-workstation/run.py model workstation_checks.gd --gui --package
  python3 cloud-workstation/run.py model workstation_checks.gd --gui --package reopen
  python3 cloud-workstation/run.py model ui_checks.gd --gui --package
  python3 cloud-workstation/run.py model restart_checks.gd --gui --package
  python3 cloud-workstation/audit.py
Setup depends on the preserved F1 runtime and evidence in this saved environment;
see cloud-port/REPORT.txt and cloud-fresh/README.txt for those prior build stages.
The resulting package contains its own engine, native library, data and states;
its ordinary UI needs no original checkout or network. Provenance/reproduction
paths refer to the checkout; they are not claimed to be packaged full raw histories.

Limits
F1 remains an experimental model, not the promoted W27 app. Evidence uses three
seed families and finite observation. No sustained replacement is established.
Model units and toy nutrient cycling are not calibrated plant physiology. Exact
replay and conservation do not prove biological realism. All rendering checks use
software llvmpipe. Hardware GPU/Windows remain unavailable, not passed. Earlier
strict JSON metric failures stay separate from exact physical-state comparisons.
The full daily source traces remain in cloud-fresh; this package includes summary
budgets, daily resource rows, all hourly hashes and18 selected binary checkpoints.

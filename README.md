# Plant Growth Lab

Private source and essential experiment snapshot, prepared from the original local project on 2026-10-09. Originals and the installed W27 application were not changed. No experiments were restarted for this upload.

## Projects and evidence

- `shared-atmosphere27/`: reviewed Windows baseline (W27), source, native C header/license, model/parity results, six ordinary golden matrices.
- `seedling-diagnostics28/`: matched birth-checkpoint experiments; three exact binary state checkpoints and compact findings.
- `bud-diagnostics29/`: factorial controls, common 768-hour comparison, and independently reconciled carbon budgets.
- `juvenile-allocation30/`: unpromoted candidate, original scientific runtime manifest and run records, three compact ordinary 8,160-hour results. Only the bulk `history` field is omitted from these matrices; original full-file hashes are retained. All 960 hashes, eight checkpoints, configuration, lineage, final state and error bounds remain.

Candidate30 defers new reproductive savings until the existing 32-paid-node gate. All three ordinary runs produced grandchildren; only one grandchild survived to the endpoint. This is not evidence of indefinitely self-sustaining growth. Candidate native/package, exact replay, fairness and parity validation remain unfinished. Diagnostics retaining pending growth alone did not improve paid growth; the full intervention combination harmed one seed's survival.

## Build and use

The validated baseline used **Godot 4.7.2** on Windows and a **C11** native extension, with MinGW-w64 GCC 13.2. Python helpers used Python 3.11. Engine executables and compiled modules are intentionally excluded. See [NATIVE-BUILD.txt](NATIVE-BUILD.txt) for the original build command, ABI details and Linux adaptation requirements.

From `shared-atmosphere27`, with a matching Windows C compiler:

```sh
gcc -O3 -g -std=c11 -shared -o native/resource_field.dll native/resource_field.c
```

Then open `shared-atmosphere27/project.godot` with the matching Godot engine, or run the engine with `--path shared-atmosphere27` from this repository. The graphical workbench requires a suitable graphics environment. This source-only snapshot has not been rebuilt after upload preparation.

The extension uses 4.7-only registration/constructor APIs. **Godot 4.6.3 cannot load it unchanged.** Linux needs an explicit export/configuration adaptation and native/reference parity validation; no Linux binary or working cloud environment is claimed. Historical helpers assume sibling engine/build artifacts and Windows process APIs. Review them before running. In particular, candidate30's copied launcher/native shell is unfinished; do not blindly run its queue or relabel original Windows evidence as new platform results.

## Integrity and scope

Run `python verify_snapshot.py` to verify this repository snapshot without launching an experiment. `SNAPSHOT-MANIFEST.json` records repository file hashes and original source hashes. Two queue helpers use `sys.executable` instead of a personal absolute Python path; scientific runtime source is otherwise unchanged. Compacted evidence records original hashes. Historical hashes may cover omitted binaries or earlier complete trees.

This README defines the GitHub snapshot scope. `MIGRATION.txt` is retained as a historical October 8 migration record and describes a larger archive; its old upload-authorization and included-file statements do not define this repository. `RESUME-STATUS.json` records state at that historical snapshot, not a live process report.

Excluded: credentials and transfer metadata, personal saved sessions, engine/package binaries, DLLs, caches, generated build outputs, icons, bulk candidate hourly histories, older project trees and the reference PDF. Full local evidence remains intact. Native/Godot license notices are retained; no new license is asserted for project code.

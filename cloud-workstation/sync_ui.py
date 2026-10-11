from pathlib import Path
import shutil
P=Path(__file__).resolve().parent;W=P/'work/model'
assert (W/'data/catalog.json').exists()
for p in (P/'scripts').glob('*.gd'):shutil.copy2(p,W/p.name)
(W/'workstation.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://workstation.gd" id="1"]\n[node name="ResearchWorkstation" type="Control"]\nlayout_mode=3\nanchors_preset=15\nanchor_right=1.0\nanchor_bottom=1.0\ngrow_horizontal=2\ngrow_vertical=2\nscript=ExtResource("1")\n')
s=(P.parent/'cloud-fresh/work/model/project.godot').read_text().replace('res://lab.tscn','res://workstation.tscn').replace('BlobusPlantJuvenile30','PlantResearchWorkstationF1').replace('Plant Growth Lab / Juvenile Development','Plant Research Workstation / Experimental F1').replace('"30.0.0"','"0.1.0"')
(W/'project.godot').write_text(s)

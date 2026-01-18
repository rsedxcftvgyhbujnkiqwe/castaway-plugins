import json

with open("data.json","r") as f:
	data = json.loads(f.read())

classes = ["Scout","Soldier","Pyro","Demoman","Heavy","Engineer","Medic","Sniper","Spy"]
slots = ["Primary","Secondary","Melee","PDA 2", "Cosmetic"]

weapon_store = {classname:{slotname:[] for slotname in slots} for classname in classes}

for weapon in data:
	if(len(weapon["categories"]) > 1):
		raise Exception(f"Weapon {weapon['name']} has multiple categories!")
	html_format = f"""
		<!--  {weapon['name']}  -->
		<tr>
			<!--  Vanilla  -->
			<td colspan="2" class="loadout-tooltip-container">
			<div class="tf-backpack-item">
				<div class="tf-backpack-item-content">
				<span class="qua_normal">Vanilla</span>
				</div>
				<center>
				<div class="tf-backpack-item-center">
					<img src="{weapon['backpack_image']}" alt="{weapon['name']}" width="90" height="90">
				</div>
				</center>
				<div class="tf-backpack-item-content">
				<p>
					<span class="qua_unique">{weapon['qua_unique']}</span><br>
					<span class="att_level">{weapon['att_level']}</span><br>
{'\n'.join([f'					<span class="{x['type']}">{x['text']}</span><br>' for x in weapon['current_attributes']])}
				</p>
				</div>
			</div>
			</td>
			<!--  Revert  -->
			<td colspan="2" class="loadout-tooltip-container">
			<div class="tf-backpack-item">
				<div class="tf-backpack-item-content">
				<span class="qua_vintage">Reverted</span>
				</div>
				<center>
				<div class="tf-backpack-item-center">
					<img src="{weapon['backpack_image']}" alt="{weapon['name']}" width="90" height="90">
				</div>
				</center>
				<div class="tf-backpack-item-content">
				<p>
					<span class="qua_unique">{weapon['qua_unique']}</span><br>
					<span class="att_level">{weapon['att_level']}</span><br>
		{'\n'.join([f'			<span class="{x['type']}">{x['text']}</span><br>' for x in weapon['reverted_attributes']])}
				</p>
				</div>
			</div>
			</td>
		</tr>"""
	for classname in weapon["classes"]:
		for category in weapon["categories"]:
			weapon_store[classname][category].append(html_format)

for classname in classes:
	weapons = []
	for slot in slots:
		for weapon in weapon_store[classname][slot]:
			weapons.append(weapon)
	div_format = f"""
<div id="{classname.lower()}" class="tab-content{' active' if classname == 'Scout' else ''}">
    <table>{''.join(weapons)}
	</table>
</div>
"""
	print(div_format)
with open('lib/l10n/translations.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    
new_lines = []
for l in lines:
    if "'pending':" in l and 'Pending' in l: continue
    if "'pending':" in l and 'زیر التواء' in l: continue
    if "'rejected':" in l and 'Rejected' in l: continue
    if "'rejected':" in l and 'مسترد شدہ' in l: continue
    new_lines.append(l)

with open('lib/l10n/translations.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

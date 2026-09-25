import re
import sys

def fix_const_and_lang(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # In request_detail_screen.dart, lang was added in build() but not in all widget builder methods if it has multiple methods.
    # Let's just make lang a global or pass it, or we can just define `final lang = Provider.of<LanguageProvider>(context);` at the top of every method that uses it.
    
    # We will search for all methods returning a Widget that use `lang.tr` and add `final lang = Provider.of<LanguageProvider>(context);`
    # if it's not already there.
    
    # Let's fix const first. We will just remove `const ` before anything that contains lang.tr.
    content = re.sub(r'const\s+([^,]+lang\.tr)', r'\1', content)
    content = re.sub(r'const\s+(Text\(lang\.tr)', r'\1', content)
    
    # Let's remove const from parent lists: `children: const [` -> `children: [`
    # This might be too broad but it's often the cause.
    # Instead of removing all const [, let's do a more targeted approach.
    
    # Replace `const ` before any widget that contains `lang.tr`.
    lines = content.split('\n')
    for i in range(len(lines)):
        if "lang.tr(" in lines[i] or "lang.currentLanguage" in lines[i]:
            # trace back and remove const if any
            # It's easier to just remove const if it's on the same line
            lines[i] = lines[i].replace("const Text(lang", "Text(lang")
            lines[i] = lines[i].replace("const ", "")
            
            # If the error is from a parent, we might need to remove const on earlier lines.
            # Let's just search up to 5 lines backwards for `const ` and remove it if it's a layout widget.
            for j in range(max(0, i-10), i):
                if re.search(r'const\s+(Column|Row|Padding|Center|SizedBox|TextSpan|Widget|List|EdgeInsets)', lines[j]):
                    lines[j] = re.sub(r'const\s+(Column|Row|Padding|Center|SizedBox|TextSpan|Widget|List|EdgeInsets)', r'\1', lines[j])
                if "children: const [" in lines[j]:
                    lines[j] = lines[j].replace("children: const [", "children: [")
                if "const [" in lines[j]:
                    lines[j] = lines[j].replace("const [", "[")

    # Add `final lang = Provider.of<LanguageProvider>(context);` to methods that use lang.tr but don't have it.
    # Methods usually look like `Widget _buildSomething(BuildContext context) {`
    
    in_method = False
    method_start = -1
    has_lang = False
    for i in range(len(lines)):
        if re.search(r'(Widget|List<Widget>|void)\s+_[a-zA-Z0-9_]+\s*\(.*context.*\)\s*\{', lines[i]):
            in_method = True
            method_start = i
            has_lang = False
        
        if in_method:
            if "Provider.of<LanguageProvider>" in lines[i]:
                has_lang = True
            if "lang.tr" in lines[i] and not has_lang:
                # Insert lang definition right after method start
                lines.insert(method_start + 1, "    final lang = Provider.of<LanguageProvider>(context, listen: false);")
                has_lang = True
                
    content = '\n'.join(lines)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Fixed {filepath}")

for arg in sys.argv[1:]:
    fix_const_and_lang(arg)

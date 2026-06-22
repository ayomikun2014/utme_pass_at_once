import os
import re

files_to_process = [
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\services\unlock_service.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\services\simulator_service.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\study\bookmarked.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\study\performance_analysis.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\study\subject_analytics.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\simulator\simulator_history.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\simulator\simulator.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\providers\unlock_provider.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\lib\features\user\screens\more\account\my_purchase.dart',
    r'c:\Users\USER\Documents\studio\utme_pass_at_once\functions\index.js',
]

for filepath in files_to_process:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove imports of exam_type_utils.dart
    content = re.sub(r"import 'package:utme_pass_at_once/core/utils/exam_type_utils\.dart';\s*\n", "", content)
    
    if filepath.endswith('.js'):
        # Replace calls
        content = re.sub(r'normalizeExamType\(([^)]+)\)', r'String(\1 || "").trim().toLowerCase()', content)
        
        # Remove the function definition (we'll just let the regex catch it if possible, or we remove it manually)
        func_pattern = re.compile(r'/\*\*[\s\S]*?function normalizeExamType\(examType\) \{[\s\S]*?return lower;\n\}\n', re.MULTILINE)
        content = func_pattern.sub('', content)
    else:
        # In Dart
        content = re.sub(r'normalizeExamType\(([^)]+)\)', r'\1.toLowerCase().trim()', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Replacement complete.")

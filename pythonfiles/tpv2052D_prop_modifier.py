new_file_path = '../examples/2d_slipweakening/tpv2052D.i'

with open(new_file_path, 'r') as file:
    content = file.read()

import re

# Using regular expressions to find and replace each parameter with the specified values
modified_content = re.sub(r'nx\s*=\s*\d+', 'nx = 50', content)
modified_content = re.sub(r'ny\s*=\s*\d+', 'ny = 20', modified_content)
modified_content = re.sub(r'xmin\s*=\s*-*\d+', 'xmin = -1600', modified_content)
modified_content = re.sub(r'xmax\s*=\s*-*\d+', 'xmax = 1600', modified_content)
modified_content = re.sub(r'ymin\s*=\s*-*\d+', 'ymin = -800', modified_content)
modified_content = re.sub(r'ymax\s*=\s*-*\d+', 'ymax = 800', modified_content)

# Save the modified content to a new file
modified_file_path = '../examples/2d_slipweakening/tpv2052D_modified.i'

with open(modified_file_path, 'w') as file:
    file.write(modified_content)

modified_file_path

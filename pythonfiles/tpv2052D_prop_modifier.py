new_file_path = '../examples/2d_slipweakening/tpv2052D.i'

with open(new_file_path, 'r') as file:
    content = file.read()

import re

# Using regular expressions to find and replace each parameter with the specified values
# [Mesh]
modified_content = re.sub(r'nx\s*=\s*\d+', 'nx = 50', content)
modified_content = re.sub(r'ny\s*=\s*\d+', 'ny = 20', modified_content)
modified_content = re.sub(r'xmin\s*=\s*-*\d+', 'xmin = -1600', modified_content)
modified_content = re.sub(r'xmax\s*=\s*-*\d+', 'xmax = 1600', modified_content)
modified_content = re.sub(r'ymin\s*=\s*-*\d+', 'ymin = -800', modified_content)
modified_content = re.sub(r'ymax\s*=\s*-*\d+', 'ymax = 800', modified_content)
# [GlobalParam]
modified_content = re.sub(r'q\s*=\s*\d+(\.\d+)?', 'q = 0.2', modified_content)
modified_content = re.sub(r'Dc\s*=\s*\d+(\.\d+)?', 'Dc = 0.1', modified_content)
modified_content = re.sub(r'T2_o\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'T2_o = 100e6', modified_content)
modified_content = re.sub(r'mu_d\s*=\s*\d+(\.\d+)?', 'mu_d = 0.2', modified_content)
modified_content = re.sub(r'len\s*=\s*\d+(\.\d+)?', 'len = 50', modified_content)
# [Materials]
modified_content = re.sub(r'lambda\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'lambda = 20e9', modified_content)
modified_content = re.sub(r'shear_modulus\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'shear_modulus = 20e9', modified_content)
modified_content = re.sub(r'prop_values\s*=\s*\d+(\.\d+)?', 'prop_values = 2700', modified_content)
# [Executioner]
modified_content = re.sub(r'dt\s*=\s*\d+(\.\d+)?', 'dt = 0.001', modified_content)
modified_content = re.sub(r'num_steps\s*=\s*\d+(\.\d+)?', 'num_steps = 30', modified_content)
# [Outputs]
modified_content = re.sub(r'interval\s*=\s*\d+', 'interval = 10', modified_content)

# Save the modified content to a new file
modified_file_path = '../examples/2d_slipweakening/tpv2052D_modified.i'

with open(modified_file_path, 'w') as file:
    file.write(modified_content)

modified_file_path

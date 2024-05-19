import re
import argparse

def create_range_validator(min_value=None, max_value=None):
    """  checks if value between min and max values """
    def validate_range(value):
        try:
            fvalue = float(value)
        except ValueError:
            raise argparse.ArgumentTypeError(f"{value} is not a valid float")
        
        if min_value is not None and fvalue < min_value:
            raise argparse.ArgumentTypeError(f"Value must be greater than or equal to {min_value}")
        
        if max_value is not None and fvalue > max_value:
            raise argparse.ArgumentTypeError(f"Value must be less than or equal to {max_value}")
        
        return fvalue
    return validate_range

def prop_modifier(args, new_file_path):
    
    # new_file_path = '../examples/2d_slipweakening/tpv2052D.i'

    with open(new_file_path, 'r') as file:
        content = file.read()

    # Using regular expressions to find and replace each parameter with the specified values
    # [Mesh]
    modified_content = re.sub(r'nx\s*=\s*\d+', 'nx = '+str(int(args.nx)), content)
    modified_content = re.sub(r'ny\s*=\s*\d+', 'ny = '+str(int(args.ny)), modified_content)
    modified_content = re.sub(r'xmin\s*=\s*-*\d+', 'xmin = '+str((args.xmin)), modified_content)
    modified_content = re.sub(r'xmax\s*=\s*-*\d+', 'xmax = '+str((args.xmax)), modified_content)
    modified_content = re.sub(r'ymin\s*=\s*-*\d+', 'ymin = '+str((args.ymin)), modified_content)
    modified_content = re.sub(r'ymax\s*=\s*-*\d+', 'ymax = '+str((args.ymax)), modified_content)
    # [GlobalParam]
    modified_content = re.sub(r'q\s*=\s*\d+(\.\d+)?', 'q = '+str((args.q)), modified_content)
    modified_content = re.sub(r'Dc\s*=\s*\d+(\.\d+)?', 'Dc = '+str((args.Dc)), modified_content)
    modified_content = re.sub(r'T2_o\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'T2_o = '+str((args.T2_o)), modified_content)
    modified_content = re.sub(r'mu_d\s*=\s*\d+(\.\d+)?', 'mu_d = '+str((args.mu_d)), modified_content)
    modified_content = re.sub(r'len\s*=\s*\d+(\.\d+)?', 'len = '+str((args.len)), modified_content)
    # [Materials]
    modified_content = re.sub(r'lambda\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'lambda = '+str((args.Lambda)), modified_content)
    modified_content = re.sub(r'shear_modulus\s*=\s*\d+(\.\d+)?[eE]?[+-]?\d*', 'shear_modulus = '+str((args.shear_modulus)), modified_content)
    modified_content = re.sub(r'prop_values\s*=\s*\d+(\.\d+)?', 'prop_values = '+str((args.density)), modified_content)
    # [Executioner]
    modified_content = re.sub(r'dt\s*=\s*\d+(\.\d+)?', 'dt = '+str((args.dt)), modified_content)
    modified_content = re.sub(r'num_steps\s*=\s*\d+(\.\d+)?', 'num_steps ='+str(int(args.num_steps)), modified_content)
    # [Outputs]
    modified_content = re.sub(r'interval\s*=\s*\d+', 'interval = '+str(int(args.interval)), modified_content)

    # Save the modified content to a new file
    modified_file_path = '../examples/2d_slipweakening/tpv2052D_modified.i'

    with open(modified_file_path, 'w') as file:
        file.write(modified_content)

    modified_file_path

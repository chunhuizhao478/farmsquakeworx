import argparse
import tpv2052D_prop_functions as func

#%%
if __name__ == "__main__":

    #specify old file path
    new_file_path = '../examples/2d_slipweakening/tpv2052D.i'

    parser = argparse.ArgumentParser(description="Process input file for farms")
    # [Mesh]
    parser.add_argument("--nx", type=func.create_range_validator(0,None), help="Enter value for number of elements along x direction [-]",required=True)
    parser.add_argument("--ny", type=func.create_range_validator(0,None), help="Enter value for number of elements along y direction [-]",required=True)
    parser.add_argument("--xmin", type=func.create_range_validator(None,None), help="minimum x coordinate [m]",required=True)
    parser.add_argument("--xmax", type=func.create_range_validator(None,None), help="maximum x coordinate [m]",required=True)
    parser.add_argument("--ymin", type=func.create_range_validator(None,None), help="minimum y coordinate [m]",required=True)
    parser.add_argument("--ymax", type=func.create_range_validator(None,None), help="maximum y coordinate [m]",required=True)
    # [GlobalParam]
    parser.add_argument("--q", type=func.create_range_validator(0,1), help="damping ratio [-]",required=True)
    parser.add_argument("--Dc", type=func.create_range_validator(0,None), help="charateristic length scale [m]",required=True)
    parser.add_argument("--T2_o", type=func.create_range_validator(0,None), help="initial normal stress [m]",required=True)
    parser.add_argument("--mu_d", type=func.create_range_validator(0,None), help="dynamic friction coefficient [m]",required=True)
    parser.add_argument("--len", type=func.create_range_validator(0,None), help="mesh size [m]",required=True)
    # [Materials]
    parser.add_argument("--Lambda", type=func.create_range_validator(0,None), help="first lamé constant [Pa]",required=True)
    parser.add_argument("--shear_modulus", type=func.create_range_validator(0,None), help="shear modulus [Pa]",required=True)
    parser.add_argument("--density", type=func.create_range_validator(0,None), help="density [kg/m^3]",required=True)
    # [Executioner]
    parser.add_argument("--dt", type=func.create_range_validator(0,None), help="time step [s]",required=True)
    parser.add_argument("--num_steps", type=func.create_range_validator(1,None), help="number of time steps [-]",required=True)
    # [Outputs]
    parser.add_argument("--interval", type=func.create_range_validator(1,None), help="output frequency [-]",required=True)

    args = parser.parse_args()

    func.prop_modifier(args, new_file_path)


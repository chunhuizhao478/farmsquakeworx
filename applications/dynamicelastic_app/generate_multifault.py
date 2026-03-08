#!/usr/bin/env python3
"""
Automated Multi-Fault 2D Pipeline.

Generates a complete MOOSE .i input file for multi-fault dynamic rupture simulations
from a single JSON config. Automates: .geo generation, Gmsh meshing, element extraction,
fault sorting, and .i file rendering.

Usage:
    python generate_multifault.py config.json [--dry-run] [--output-dir DIR]
"""

import argparse
import json
import math
import os
import subprocess
import sys

import meshio
import numpy as np


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "templates")


# ---------------------------------------------------------------------------
# Function objects
# ---------------------------------------------------------------------------

class StaticFrictionFunction:
    """Builds a MOOSE ConstantFunction block for static friction coefficient."""

    def __init__(self, mu_s):
        self.mu_s = mu_s

    def to_moose(self):
        return {
            "type": "ConstantFunction",
            "value": self.mu_s,
        }

    def to_moose_block(self):
        d = self.to_moose()
        lines = ["  [func_static_friction_coeff_mus]"]
        lines.append(f"    type = {d['type']}")
        lines.append(f"    value = {d['value']}")
        lines.append("  []")
        return "\n".join(lines)


class InitialShearStressFunction:
    """Builds a MOOSE ParsedFunction block with nested if() for 2D rectangular patches."""

    def __init__(self, background, patches, domain=None):
        self.background = background
        self.patches = patches
        self.domain = domain
        self._validate()

    def _validate(self):
        if not isinstance(self.background, (int, float)) or self.background <= 0:
            raise ValueError(
                f"Initial shear stress background must be a positive number, got {self.background}"
            )
        for p in self.patches:
            if not isinstance(p.get("value"), (int, float)) or p["value"] <= 0:
                raise ValueError(
                    f"Patch '{p.get('label', 'unnamed')}' value must be a positive number, "
                    f"got {p.get('value')}"
                )
        # Check overlaps
        for i in range(len(self.patches)):
            for j in range(i + 1, len(self.patches)):
                pi, pj = self.patches[i], self.patches[j]
                if _rectangles_overlap(pi, pj):
                    li = pi.get("label", f"index {i}")
                    lj = pj.get("label", f"index {j}")
                    raise ValueError(
                        f"Initial shear stress patch '{li}' "
                        f"(x=[{pi['xmin']},{pi['xmax']}], y=[{pi['ymin']},{pi['ymax']}]) "
                        f"overlaps with patch '{lj}' "
                        f"(x=[{pj['xmin']},{pj['xmax']}], y=[{pj['ymin']},{pj['ymax']}]). "
                        f"Adjust the xmin/xmax/ymin/ymax bounds so patches do not overlap."
                    )
        # Check within domain
        if self.domain:
            d = self.domain
            for p in self.patches:
                label = p.get("label", "unnamed")
                for coord, dmin, dmax, axis in [
                    ("xmin", d["xmin"], d["xmax"], "x"),
                    ("xmax", d["xmin"], d["xmax"], "x"),
                    ("ymin", d["ymin"], d["ymax"], "y"),
                    ("ymax", d["ymin"], d["ymax"], "y"),
                ]:
                    val = p[coord]
                    if val < dmin or val > dmax:
                        raise ValueError(
                            f"Initial shear stress patch '{label}' has {coord}={val} "
                            f"which is outside the domain ({axis}min={dmin}, {axis}max={dmax}). "
                            f"Adjust the patch bounds or expand the domain."
                        )

    def to_moose(self):
        expr = str(float(self.background))
        for p in reversed(self.patches):
            cond = (
                f"x>={p['xmin']} & x<={p['xmax']} "
                f"& y>={p['ymin']} & y<={p['ymax']}"
            )
            expr = f"if({cond}, {float(p['value'])}, {expr})"
        return {
            "type": "ParsedFunction",
            "expression": f"'{expr}'",
        }

    def to_moose_block(self):
        d = self.to_moose()
        lines = ["  [func_initial_strike_shear_stress]"]
        lines.append(f"    type = {d['type']}")
        lines.append(f"    expression = {d['expression']}")
        lines.append("  []")
        return "\n".join(lines)


def _rectangles_overlap(a, b):
    """Check if two axis-aligned rectangles overlap (strict interior overlap)."""
    if a["xmax"] <= b["xmin"] or b["xmax"] <= a["xmin"]:
        return False
    if a["ymax"] <= b["ymin"] or b["ymax"] <= a["ymin"]:
        return False
    return True


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

def _segments_intersect(p1, p2, p3, p4):
    """Check if line segments (p1,p2) and (p3,p4) intersect at an interior point.

    Shared endpoints are allowed (returns False for those).
    Returns (True, intersection_point) or (False, None).
    """
    # Check for shared endpoints — these are junctions, not crossings
    for pa in [p1, p2]:
        for pb in [p3, p4]:
            if abs(pa[0] - pb[0]) < 1e-10 and abs(pa[1] - pb[1]) < 1e-10:
                return False, None

    d1x = p2[0] - p1[0]
    d1y = p2[1] - p1[1]
    d2x = p4[0] - p3[0]
    d2y = p4[1] - p3[1]

    denom = d1x * d2y - d1y * d2x
    if abs(denom) < 1e-14:
        return False, None  # parallel / collinear

    t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / denom
    u = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / denom

    eps = 1e-10
    if eps < t < 1 - eps and eps < u < 1 - eps:
        ix = p1[0] + t * d1x
        iy = p1[1] + t * d1y
        return True, (ix, iy)

    return False, None


def _point_to_segment_dist(px, py, ax, ay, bx, by):
    """Return (distance, closest_point) from point (px,py) to segment (a,b)."""
    dx, dy = bx - ax, by - ay
    len_sq = dx * dx + dy * dy
    if len_sq < 1e-30:
        # Degenerate segment (a == b)
        d = math.hypot(px - ax, py - ay)
        return d, (ax, ay)
    t = ((px - ax) * dx + (py - ay) * dy) / len_sq
    t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy), (cx, cy)


def _min_segment_distance(p1, p2, p3, p4):
    """Minimum distance between segments (p1,p2) and (p3,p4).

    Returns (min_dist, (closest_pt_on_seg1, closest_pt_on_seg2)).
    """
    # Direction vectors
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]

    best = float("inf")
    best_pts = (None, None)

    def _update(dist, pt_a, pt_b):
        nonlocal best, best_pts
        if dist < best:
            best = dist
            best_pts = (pt_a, pt_b)

    # Four endpoint-to-opposite-segment distances
    d, cp = _point_to_segment_dist(p1[0], p1[1], p3[0], p3[1], p4[0], p4[1])
    _update(d, (p1[0], p1[1]), cp)

    d, cp = _point_to_segment_dist(p2[0], p2[1], p3[0], p3[1], p4[0], p4[1])
    _update(d, (p2[0], p2[1]), cp)

    d, cp = _point_to_segment_dist(p3[0], p3[1], p1[0], p1[1], p2[0], p2[1])
    _update(d, cp, (p3[0], p3[1]))

    d, cp = _point_to_segment_dist(p4[0], p4[1], p1[0], p1[1], p2[0], p2[1])
    _update(d, cp, (p4[0], p4[1]))

    # Closest approach of infinite lines, clamped to segment ranges
    denom = d1x * d2y - d1y * d2x
    if abs(denom) > 1e-14:
        rx, ry = p3[0] - p1[0], p3[1] - p1[1]
        t = (rx * d2y - ry * d2x) / denom
        u = (rx * d1y - ry * d1x) / denom
        t = max(0.0, min(1.0, t))
        u = max(0.0, min(1.0, u))
        c1x, c1y = p1[0] + t * d1x, p1[1] + t * d1y
        c2x, c2y = p3[0] + u * d2x, p3[1] + u * d2y
        d = math.hypot(c1x - c2x, c1y - c2y)
        _update(d, (c1x, c1y), (c2x, c2y))

    return best, best_pts


def _is_shared_endpoint(fi, fj, closest_pts):
    """Check if closest_pts correspond to shared endpoints of faults fi/fj."""
    if closest_pts[0] is None:
        return False
    tol = 1e-6
    endpoints_i = [tuple(fi["start"]), tuple(fi["end"])]
    endpoints_j = [tuple(fj["start"]), tuple(fj["end"])]
    pt_on_i, pt_on_j = closest_pts
    for ei in endpoints_i:
        for ej in endpoints_j:
            if (abs(ei[0] - ej[0]) < tol and abs(ei[1] - ej[1]) < tol
                    and abs(pt_on_i[0] - ei[0]) < tol and abs(pt_on_i[1] - ei[1]) < tol
                    and abs(pt_on_j[0] - ej[0]) < tol and abs(pt_on_j[1] - ej[1]) < tol):
                return True
    return False


# ---------------------------------------------------------------------------
# Config validation
# ---------------------------------------------------------------------------

def validate_config(config):
    """Validate the multi-fault config. Raises ValueError with descriptive messages."""
    # Required top-level sections
    required_sections = ["domain", "faults", "physics", "execution", "output"]
    for section in required_sections:
        if section not in config:
            raise ValueError(
                f"Missing required config section: '{section}'. "
                f"The config must include: {', '.join(required_sections)}."
            )

    # Required domain fields
    if "element_size" not in config["domain"]:
        raise ValueError(
            "Missing required field: 'domain.element_size'. "
            "Specify the mesh element size in meters (e.g., 100)."
        )

    # Required physics fields
    required_physics = ["mu_s"]
    for field in required_physics:
        if field not in config["physics"]:
            raise ValueError(
                f"Missing required field: 'physics.{field}'. "
                f"Specify the static friction coefficient (e.g., 0.677)."
            )

    # Faults non-empty
    if not config["faults"]:
        raise ValueError("Config must include at least one fault in 'faults'.")

    domain = config["domain"]

    # Unique fault labels
    labels = [f["label"] for f in config["faults"]]
    for i in range(len(labels)):
        for j in range(i + 1, len(labels)):
            if labels[i] == labels[j]:
                raise ValueError(
                    f"Duplicate fault label '{labels[i]}' found at indices {i} and {j}. "
                    f"Each fault must have a unique label."
                )

    # Faults within domain
    for f in config["faults"]:
        for endpoint_name in ["start", "end"]:
            pt = f[endpoint_name]
            x, y = pt[0], pt[1]
            issues = []
            if x < domain["xmin"] or x > domain["xmax"]:
                issues.append(
                    f"The x-coordinate {x} is outside [xmin={domain['xmin']}, xmax={domain['xmax']}]"
                )
            if y < domain["ymin"] or y > domain["ymax"]:
                issues.append(
                    f"The y-coordinate {y} is outside [ymin={domain['ymin']}, ymax={domain['ymax']}]"
                )
            if issues:
                raise ValueError(
                    f"Fault '{f['label']}' endpoint {endpoint_name}={pt} is outside the domain "
                    f"(xmin={domain['xmin']}, xmax={domain['xmax']}, "
                    f"ymin={domain['ymin']}, ymax={domain['ymax']}). "
                    f"{'. '.join(issues)}. "
                    f"Adjust the fault endpoint or expand the domain."
                )

    # Minimum fault separation distance check
    element_size = domain["element_size"]
    faults = config["faults"]
    for i in range(len(faults)):
        for j in range(i + 1, len(faults)):
            fi, fj = faults[i], faults[j]
            min_dist, closest_pts = _min_segment_distance(
                fi["start"], fi["end"], fj["start"], fj["end"]
            )
            if not _is_shared_endpoint(fi, fj, closest_pts):
                if min_dist < 2 * element_size:
                    pt_a, pt_b = closest_pts
                    mid = ((pt_a[0] + pt_b[0]) / 2, (pt_a[1] + pt_b[1]) / 2)
                    raise ValueError(
                        f"Fault '{fi['label']}' and fault '{fj['label']}' are too close "
                        f"(minimum distance {min_dist:.1f} m at approximately "
                        f"({mid[0]:.0f}, {mid[1]:.0f}), "
                        f"but minimum required separation is {2 * element_size} m "
                        f"(2 × element_size={element_size}). "
                        f"Increase the separation between faults or reduce element_size."
                    )

    # Validate initial_stress_tensor if provided
    if "initial_stress_tensor" in config:
        ist = config["initial_stress_tensor"]
        for comp in ("stress_xx", "stress_xy", "stress_yy"):
            if comp not in ist:
                raise ValueError(
                    f"Missing required field: 'initial_stress_tensor.{comp}'. "
                    f"Specify all three 2D stress components (stress_xx, stress_xy, stress_yy)."
                )


def evaluate_fault_initial_stress(config):
    """Evaluate initial stress state on each fault and report slip potential.

    For each fault segment, rotates the global background stress tensor into
    fault-local coordinates and compares shear traction against frictional
    strength (|sigma_n| * mu_s).

    Returns True if all faults are stable, False if any would slip initially.
    """
    ist = config.get("initial_stress_tensor", {})
    sxx = ist.get("stress_xx", 0.0)
    sxy = ist.get("stress_xy", 0.0)
    syy = ist.get("stress_yy", 0.0)
    mu_s = config["physics"]["mu_s"]
    faults = config["faults"]

    print("\n  Fault Initial Stress Analysis (background stress tensor)")
    print("  " + "-" * 86)
    print(f"  {'Fault':<12} {'Shear (MPa)':>14} {'Normal (MPa)':>14} "
          f"{'Strength (MPa)':>16} {'Slip?':>8}")
    print("  " + "-" * 86)

    any_slip = False
    for fault in faults:
        label = fault["label"]
        sx, sy = fault["start"]
        ex, ey = fault["end"]

        # Fault tangent and normal vectors
        dx, dy = ex - sx, ey - sy
        length = math.sqrt(dx * dx + dy * dy)
        tx, ty = dx / length, dy / length
        # Normal: 90-degree CCW rotation of tangent
        nx, ny = -ty, tx

        # Traction on fault plane: t_i = sigma_ij * n_j
        tn_x = sxx * nx + sxy * ny
        tn_y = sxy * nx + syy * ny

        # Resolve into normal and shear components
        sigma_n = tn_x * nx + tn_y * ny   # normal traction (compression < 0)
        tau = tn_x * tx + tn_y * ty       # shear traction

        # Shear strength (Coulomb): mu_s * |sigma_n| (only if compressive)
        if sigma_n < 0:
            strength = mu_s * abs(sigma_n)
        else:
            strength = 0.0  # tensile normal -> no frictional resistance

        will_slip = abs(tau) >= strength
        if will_slip:
            any_slip = True

        slip_str = "YES" if will_slip else "no"
        print(f"  {label:<12} {tau / 1e6:>14.2f} {sigma_n / 1e6:>14.2f} "
              f"{strength / 1e6:>16.2f} {slip_str:>8}")

    print("  " + "-" * 86)

    if any_slip:
        print("\n  *** Warning ***")
        print("  One or more faults will slip under the background stress alone.")
        print("  Please double check your initial_stress_tensor and mu_s values.")
        print("  Faults should generally be stable (|tau| < mu_s * |sigma_n|)")
        print("  with slip initiated only by the nucleation patch.\n")
    else:
        print(f"\n  All faults are stable under background stress "
              f"(|tau| < mu_s * |sigma_n|).\n")

    return not any_slip


# ---------------------------------------------------------------------------
# Step 2: Generate .geo file
# ---------------------------------------------------------------------------

def generate_geo(config, output_path):
    """Generate a Gmsh .geo file from config domain + faults."""
    domain = config["domain"]
    faults = config["faults"]
    elem_size = domain.get("element_size", 100)

    lines = []
    lines.append(f"lc = {elem_size};")
    lines.append("")

    # Domain corner points
    lines.append(f"Point(1) = {{{domain['xmin']}, {domain['ymin']}, 0.0, lc}};")
    lines.append(f"Point(2) = {{{domain['xmax']}, {domain['ymin']}, 0.0, lc}};")
    lines.append(f"Point(3) = {{{domain['xmax']}, {domain['ymax']}, 0.0, lc}};")
    lines.append(f"Point(4) = {{{domain['xmin']}, {domain['ymax']}, 0.0, lc}};")
    lines.append("")

    # Collect unique fault points (deduplicate shared junctions)
    point_id = 5  # start after domain corners
    point_map = {}  # (x, y) -> point_id
    fault_point_ids = []  # per fault: list of point IDs

    for fault in faults:
        pts = [tuple(fault["start"]), tuple(fault["end"])]
        ids = []
        for p in pts:
            key = (round(p[0], 6), round(p[1], 6))
            if key not in point_map:
                point_map[key] = point_id
                lines.append(f"Point({point_id}) = {{{p[0]}, {p[1]}, 0.0, lc}};")
                point_id += 1
            ids.append(point_map[key])
        fault_point_ids.append(ids)

    lines.append("")

    # Domain boundary lines
    lines.append("Line(1) = {1,2};")
    lines.append("Line(2) = {2,3};")
    lines.append("Line(3) = {3,4};")
    lines.append("Line(4) = {4,1};")
    lines.append("")

    # Fault lines — one line per fault, from start to end
    line_id = 5
    fault_line_ids = []  # per fault: line ID

    for fi, fault in enumerate(faults):
        start_pid = fault_point_ids[fi][0]
        end_pid = fault_point_ids[fi][1]
        lines.append(f"Line({line_id}) = {{{start_pid},{end_pid}}};")
        fault_line_ids.append([line_id])
        line_id += 1

    lines.append("")

    # Surface
    lines.append("Line Loop(1) = {1,2,3,4};")
    lines.append("Plane Surface(2) = {1};")
    lines.append("")

    # Embed points and lines in surface
    all_pt_ids = sorted(point_map.values())
    all_line_ids = sorted(set(lid for lids in fault_line_ids for lid in lids))
    lines.append(f"Point{{{','.join(str(p) for p in all_pt_ids)}}} In Surface{{2}};")
    lines.append(f"Line{{{','.join(str(l) for l in all_line_ids)}}} In Surface{{2}};")
    lines.append("")

    # Physical Curves for faults
    for fi, fault in enumerate(faults):
        lid_str = ",".join(str(l) for l in fault_line_ids[fi])
        lines.append(f'Physical Curve("{fault["label"]}") = {{{lid_str}}};')

    lines.append("")

    # Physical Curves for domain boundaries
    lines.append('Physical Curve("bottom") = {1};')
    lines.append('Physical Curve("right") = {2};')
    lines.append('Physical Curve("top") = {3};')
    lines.append('Physical Curve("left") = {4};')
    lines.append("")

    # Physical Surface
    lines.append('Physical Surface("100") = {2};')
    lines.append("")
    lines.append("Mesh.Algorithm = 6;")

    content = "\n".join(lines) + "\n"
    with open(output_path, "w") as f:
        f.write(content)

    return content


# ---------------------------------------------------------------------------
# Step 3: Run Gmsh
# ---------------------------------------------------------------------------

def run_gmsh(geo_path, msh_path):
    """Run Gmsh to generate mesh. Raises RuntimeError on failure."""
    result = subprocess.run(
        ["gmsh", "-2", geo_path, "-o", msh_path, "-format", "msh2"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Gmsh failed with return code {result.returncode}.\n"
            f"stdout: {result.stdout}\n"
            f"stderr: {result.stderr}"
        )
    return msh_path


# ---------------------------------------------------------------------------
# Step 4: Extract elements per fault
# ---------------------------------------------------------------------------

def _get_physical_curve_nodes(m, label):
    """Get unique node IDs for a named physical curve, supporting multiple meshio versions.

    Tries cell_sets_dict first (older meshio / some mesh files), then falls back to
    field_data + cell_data['gmsh:physical'] (meshio 5.x with msh2).
    """
    if label in m.cell_sets_dict:
        phy_nodal_ind = m.cell_sets_dict[label]["line"]
        return np.unique(np.ravel(m.cells_dict["line"][phy_nodal_ind, :]))

    # Fallback: use field_data to get the physical tag, then filter line cells
    if hasattr(m, "field_data") and label in m.field_data:
        phys_tag = m.field_data[label][0]
        # Find line cells that have this physical tag
        line_cells = m.cells_dict["line"]
        # cell_data is stored per cell block; find the line block index
        phys_data = None
        line_offset = 0
        for ci, cell_block in enumerate(m.cells):
            if cell_block.type == "line":
                phys_data = m.cell_data["gmsh:physical"][ci]
                break
        if phys_data is not None:
            mask = phys_data == phys_tag
            return np.unique(np.ravel(line_cells[mask, :]))

    raise KeyError(
        f"Physical curve '{label}' not found in mesh. "
        f"Available cell_sets: {list(m.cell_sets_dict.keys())}. "
        f"Available field_data: {list(getattr(m, 'field_data', {}).keys())}."
    )


def extract_fault_elements(msh_path, faults):
    """Extract upper/lower elements for each fault from the mesh.

    Returns dict: {fault_label: {"upper": [elem_ids], "lower": [elem_ids],
                                  "upper_coords": [(x_arr, y_arr), ...],
                                  "subdomain_upper": int, "subdomain_lower": int}}
    """
    m = meshio.read(msh_path)
    tria_elem_connect = m.cells_dict["triangle"]
    num_elem = tria_elem_connect.shape[0]

    result = {}

    for fi, fault in enumerate(faults):
        label = fault["label"]
        start = np.array(fault["start"], dtype=float)
        end = np.array(fault["end"], dtype=float)

        # Fault direction and normal
        d_vec = end - start
        d_len = np.linalg.norm(d_vec)
        d_hat = d_vec / d_len
        # Left-normal (points to "upper" side)
        n_hat = np.array([-d_vec[1], d_vec[0]]) / d_len

        # Get physical curve nodes — support both cell_sets_dict and field_data paths
        phy_nodal_arr = _get_physical_curve_nodes(m, label)

        upper_elems = []
        lower_elems = []
        upper_coords_x = []
        upper_coords_y = []

        for elem_ind in range(num_elem):
            elem_connect = tria_elem_connect[elem_ind, :]
            num_on_fault = np.count_nonzero(np.isin(phy_nodal_arr, elem_connect))
            if num_on_fault < 1:
                continue

            coords_x = m.points[elem_connect][:, 0]
            coords_y = m.points[elem_connect][:, 1]
            centroid = np.array([np.mean(coords_x), np.mean(coords_y)])

            # Project ALL element vertices onto the fault direction
            # Reject elements that extend beyond the fault endpoints
            vertex_projs = []
            for vi in range(len(elem_connect)):
                vpt = np.array([coords_x[vi], coords_y[vi]])
                vertex_projs.append(np.dot(vpt - start, d_hat))

            # Element must have at least one vertex within the fault span
            # AND no vertex projecting far beyond the endpoints
            v_min = min(vertex_projs)
            v_max = max(vertex_projs)
            elem_tol = d_len * 0.005  # tight tolerance (0.5% of fault length)
            if v_max < -elem_tol or v_min > d_len + elem_tol:
                continue

            # Centroid-based endpoint check: reject elements whose centroid
            # projects beyond the fault endpoints
            v = centroid - start
            proj = np.dot(v, d_hat)
            if proj < 0 or proj > d_len:
                continue

            # Upper/lower classification by normal dot product
            side = np.dot(v, n_hat)
            if side > 0:
                upper_elems.append(elem_ind)
                upper_coords_x.append(coords_x)
                upper_coords_y.append(coords_y)
            else:
                lower_elems.append(elem_ind)

        subdomain_upper = (2 * fi + 1) * 100  # 100, 300, 500, ...
        subdomain_lower = (2 * fi + 2) * 100  # 200, 400, 600, ...

        result[label] = {
            "upper": upper_elems,
            "lower": lower_elems,
            "upper_coords_x": upper_coords_x,
            "upper_coords_y": upper_coords_y,
            "subdomain_upper": subdomain_upper,
            "subdomain_lower": subdomain_lower,
        }

    return result, m


# ---------------------------------------------------------------------------
# Step 5: Sort elements along fault
# ---------------------------------------------------------------------------

def sort_fault_elements(mesh_obj, faults, fault_elements):
    """Sort upper-side elements along each fault for VectorPostprocessors.

    Returns dict: {fault_label: [sorted_elem_ids]}
    """
    m = mesh_obj
    tria_elem_connect = m.cells_dict["triangle"]
    sorted_result = {}

    for fault in faults:
        label = fault["label"]
        start = np.array(fault["start"], dtype=float)
        end = np.array(fault["end"], dtype=float)
        d_vec = end - start
        d_len = np.linalg.norm(d_vec)
        d_hat = d_vec / d_len

        # Fault line equation: y = k*x + b (or use parametric for general lines)
        fe = fault_elements[label]
        upper_elems = fe["upper"]
        upper_coords_x = fe["upper_coords_x"]
        upper_coords_y = fe["upper_coords_y"]

        # Get physical curve nodes for on-fault check
        phy_nodal_arr = _get_physical_curve_nodes(m, label)

        results = []
        for idx, elem_ind in enumerate(upper_elems):
            elem_connect = tria_elem_connect[elem_ind, :]
            x_vals = upper_coords_x[idx]
            y_vals = upper_coords_y[idx]

            # Find nodes that are on the fault
            on_fault_indices = [
                i for i, node_id in enumerate(elem_connect)
                if node_id in phy_nodal_arr
            ]

            if len(on_fault_indices) == 2:
                avg_x = np.mean([x_vals[i] for i in on_fault_indices])
                avg_y = np.mean([y_vals[i] for i in on_fault_indices])
                avg_pos = np.array([avg_x, avg_y])
                dist = np.dot(avg_pos - start, d_hat)
                results.append((dist, elem_ind))

        results.sort(key=lambda t: t[0])
        sorted_result[label] = [eid for _, eid in results]

    return sorted_result


# ---------------------------------------------------------------------------
# Step 6: Build MOOSE blocks
# ---------------------------------------------------------------------------

def build_functions_block(config):
    """Build the [Functions] block text from config."""
    physics = config["physics"]
    ist = config.get("initial_stress_tensor", {})
    nucl = config.get("nucleation", {})

    friction_func = StaticFrictionFunction(physics["mu_s"])

    # Derive shear/normal stress functions from stress tensor for FarmsMaterialRealAux
    background_shear = ist.get("stress_xy", 70e6)
    patches = []
    if nucl.get("radius", 0) > 0:
        center = nucl.get("center", [0, 0])
        r = nucl["radius"]
        patches.append({
            "xmin": center[0] - r,
            "xmax": center[0] + r,
            "ymin": center[1] - r,
            "ymax": center[1] + r,
            "value": nucl.get("peak_shear_stress", background_shear),
            "label": "nucleation",
        })
    stress_func = InitialShearStressFunction(
        background_shear, patches, domain=config.get("domain")
    )

    lines = ["[Functions]"]
    lines.append(friction_func.to_moose_block())
    lines.append(stress_func.to_moose_block())
    # Normal stress from stress tensor (stress_yy) for FarmsMaterialRealAux
    lines.append("  [func_initial_normal_stress]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {float(ist.get('stress_yy', -120e6)):.10g}")
    lines.append("  []")
    # Background stress tensor component functions
    lines.append("  # Background stress tensor components (for stress tensor rotation mode)")
    lines.append("  [func_initial_stress_xx]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {float(ist.get('stress_xx', -120e6)):.10g}")
    lines.append("  []")
    lines.append("  [func_initial_stress_xy]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {float(background_shear):.10g}")
    lines.append("  []")
    lines.append("  [func_initial_stress_yy]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {float(ist.get('stress_yy', -120e6)):.10g}")
    lines.append("  []")
    lines.append("  [func_zero]")
    lines.append("    type = ConstantFunction")
    lines.append("    value = 0.0")
    lines.append("  []")
    lines.append("[]")
    return "\n".join(lines)


def build_vectorpostprocessors(faults):
    """Build per-fault SideValueSampler VectorPostprocessor blocks."""
    variables = "local_shear_jump local_normal_jump local_shear_jump_rate local_normal_jump_rate local_shear_traction local_normal_traction normal_x normal_y tangent_x tangent_y"

    lines = ["[VectorPostprocessors]"]
    for fi, fault in enumerate(faults):
        label = fault["label"]
        sub_u = (2 * fi + 1) * 100
        sub_l = (2 * fi + 2) * 100
        boundary = f"Block{sub_u}_Block{sub_l}"
        dx = fault["end"][0] - fault["start"][0]
        dy = fault["end"][1] - fault["start"][1]
        sort_by = "x" if abs(dx) >= abs(dy) else "y"
        lines.append(f"  [{label}]")
        lines.append(f"    type = SideValueSampler")
        lines.append(f"    variable = '{variables}'")
        lines.append(f"    boundary = '{boundary}'")
        lines.append(f"    sort_by = {sort_by}")
        lines.append(f"  []")
    lines.append("[]")
    return "\n".join(lines)


def build_param_block(config):
    """Build MOOSE parameter variable declarations."""
    physics = config["physics"]
    execution = config["execution"]
    output = config["output"]
    ist = config.get("initial_stress_tensor", {})
    nucl = config.get("nucleation", {})

    # Exclude keys consumed by Functions block or stress tensor (not used as ${var} in template)
    skip_physics = {"mu_s", "T2_o", "len"}
    params = {}
    params.update({k: v for k, v in physics.items() if k not in skip_physics})
    # len = element_size (same quantity, avoid duplication in config)
    params["len"] = config["domain"]["element_size"]
    # Compute wave speeds from material properties: Vp = sqrt((lambda + 2*mu) / rho), Vs = sqrt(mu / rho)
    rho = physics["density"]
    lam = physics["lambda_o"]
    mu = physics["shear_modulus_o"]
    params["p_wave_speed"] = math.sqrt((lam + 2 * mu) / rho)
    params["shear_wave_speed"] = math.sqrt(mu / rho)
    params.update(execution)
    params["exodus_interval"] = output.get("exodus_interval", 40)
    params["csv_interval"] = output.get("csv_interval", params.get("exodus_interval", 40))

    # Nucleation parameters (used in czm_mat block)
    params["peak_shear_stress"] = nucl.get("peak_shear_stress", 81.6e6)
    nucl_center = nucl.get("center", [-8000, 0])
    params["nucl_center_x"] = nucl_center[0]
    params["nucl_center_y"] = nucl_center[1]
    params["nucl_radius"] = nucl.get("radius", 1500)

    lines = ["#parameters (auto-generated from JSON config)", ""]
    for key, value in sorted(params.items()):
        if isinstance(value, float):
            lines.append(f"{key} = {value:.10g}")
        else:
            lines.append(f"{key} = {value}")
    lines.append("")
    return "\n".join(lines)


def build_mesh_data(config, fault_elements):
    """Build element_ids, subdomain_ids, block_pairs, boundary_list strings."""
    faults = config["faults"]

    all_elem_ids = []
    all_subdomain_ids = []
    block_pairs = []
    boundary_list = []

    for fault in faults:
        label = fault["label"]
        fe = fault_elements[label]
        upper = fe["upper"]
        lower = fe["lower"]
        sub_u = fe["subdomain_upper"]
        sub_l = fe["subdomain_lower"]

        all_elem_ids.extend(upper)
        all_subdomain_ids.extend([sub_u] * len(upper))
        all_elem_ids.extend(lower)
        all_subdomain_ids.extend([sub_l] * len(lower))

        block_pairs.append(f"{sub_u} {sub_l}")
        boundary_list.append(f"Block{sub_u}_Block{sub_l}")

    return {
        "element_ids": " ".join(str(e) for e in all_elem_ids),
        "subdomain_ids": " ".join(str(s) for s in all_subdomain_ids),
        "block_pairs": "; ".join(block_pairs),
        "boundary_list": " ".join(boundary_list),
    }


def get_subdomain_ids_for_faults(faults):
    """Get subdomain ID pairs for N faults."""
    result = {}
    for fi, fault in enumerate(faults):
        sub_u = (2 * fi + 1) * 100
        sub_l = (2 * fi + 2) * 100
        result[fault["label"]] = (sub_u, sub_l)
    return result


def get_block_pairs_string(faults):
    """Get block_pairs string like '100 200; 300 400'."""
    pairs = []
    for fi in range(len(faults)):
        sub_u = (2 * fi + 1) * 100
        sub_l = (2 * fi + 2) * 100
        pairs.append(f"{sub_u} {sub_l}")
    return "; ".join(pairs)


def get_boundary_list_string(faults):
    """Get boundary list string like 'Block100_Block200 Block300_Block400'."""
    boundaries = []
    for fi in range(len(faults)):
        sub_u = (2 * fi + 1) * 100
        sub_l = (2 * fi + 2) * 100
        boundaries.append(f"Block{sub_u}_Block{sub_l}")
    return " ".join(boundaries)


def render_input_file(template_path, config, mesh_data, msh_path):
    """Render the final .i file from template + computed data."""
    with open(template_path, "r") as f:
        template = f.read()

    param_block = build_param_block(config)
    functions_block = build_functions_block(config)
    vpp_block = build_vectorpostprocessors(config["faults"])

    replacements = {
        "__PARAM_BLOCK__": param_block,
        "__MESH_FILE__": msh_path,
        "__ELEMENT_IDS__": mesh_data["element_ids"],
        "__SUBDOMAIN_IDS__": mesh_data["subdomain_ids"],
        "__BLOCK_PAIRS__": mesh_data["block_pairs"],
        "__BOUNDARY_LIST__": mesh_data["boundary_list"],
        "__FUNCTIONS_BLOCK__": functions_block,
        "__VECTORPOSTPROCESSORS__": vpp_block,
    }

    result = template
    for marker, value in replacements.items():
        result = result.replace(marker, str(value))

    return result


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def run_pipeline(config_path, output_dir=None, dry_run=False):
    """Run the full multi-fault pipeline."""
    n_faults = "?"

    def _step(step_num, total, msg):
        print(f"[{step_num}/{total}] {msg}")

    with open(config_path, "r") as f:
        config = json.load(f)
    n_faults = len(config.get("faults", []))

    # Step 1: Validate
    _step(1, 6, f"Validating config ({n_faults} faults)...")
    validate_config(config)
    evaluate_fault_initial_stress(config)
    _step(1, 6, "Config validated OK")

    if output_dir is None:
        output_dir = os.path.join(SCRIPT_DIR, "2d_slipweakening_multifaults")

    os.makedirs(output_dir, exist_ok=True)

    # Step 2 & 3: Mesh generation
    msh_path = config.get("mesh_file")
    if msh_path is None:
        geo_path = os.path.join(output_dir, "output.geo")
        msh_path = os.path.join(output_dir, "output.msh")
        _step(2, 6, f"Generating .geo file: {geo_path}")
        geo_content = generate_geo(config, geo_path)
        _step(2, 6, "Generated .geo OK")
        if dry_run:
            print("=== Generated .geo ===")
            print(geo_content)
            print(f"# Would write .geo to: {geo_path}", file=sys.stderr)
        if not dry_run:
            _step(3, 6, f"Running Gmsh: {geo_path} -> {msh_path}")
            run_gmsh(geo_path, msh_path)
            _step(3, 6, "Gmsh meshing OK")
        else:
            # In dry-run mode, show what would happen but can't proceed without mesh
            print(f"\n# Would run: gmsh -2 {geo_path} -o {msh_path} -format msh2",
                  file=sys.stderr)
            # Build functions block and VPP
            functions_block = build_functions_block(config)
            vpp_block = build_vectorpostprocessors(config["faults"])

            template_path = os.path.join(TEMPLATES_DIR, "multifault_2d.i.template")
            with open(template_path, "r") as f:
                template = f.read()

            param_block = build_param_block(config)
            block_pairs = get_block_pairs_string(config["faults"])
            boundary_list = get_boundary_list_string(config["faults"])

            replacements = {
                "__PARAM_BLOCK__": param_block,
                "__MESH_FILE__": msh_path,
                "__ELEMENT_IDS__": "<requires mesh>",
                "__SUBDOMAIN_IDS__": "<requires mesh>",
                "__BLOCK_PAIRS__": block_pairs,
                "__BOUNDARY_LIST__": boundary_list,
                "__FUNCTIONS_BLOCK__": functions_block,
                "__VECTORPOSTPROCESSORS__": vpp_block,
            }

            result = template
            for marker, value in replacements.items():
                result = result.replace(marker, str(value))

            print("\n=== Generated .i (dry-run, no mesh) ===")
            print(result)
            return
    else:
        _step(2, 6, f"Using existing mesh: {msh_path}")
        _step(3, 6, "Skipped Gmsh (mesh_file provided)")

    # Step 4: Extract elements
    _step(4, 6, "Extracting fault elements from mesh...")
    fault_elements, mesh_obj = extract_fault_elements(msh_path, config["faults"])
    for label, fe in fault_elements.items():
        n_upper = len(fe["upper"])
        n_lower = len(fe["lower"])
        print(f"       {label}: {n_upper} upper + {n_lower} lower elements")
    _step(4, 6, "Fault element extraction OK")

    # Step 5: Sort elements
    _step(5, 6, "Sorting fault elements by subdomain...")
    sorted_elem_ids = sort_fault_elements(mesh_obj, config["faults"], fault_elements)
    _step(5, 6, "Fault element sorting OK")

    # Step 6: Render .i file
    _step(6, 6, "Rendering MOOSE input file...")
    mesh_data = build_mesh_data(config, fault_elements)
    template_path = os.path.join(TEMPLATES_DIR, "multifault_2d.i.template")

    # Make msh_path relative to output_dir for the .i file
    rel_msh = os.path.relpath(msh_path, output_dir)

    rendered = render_input_file(
        template_path, config, mesh_data, rel_msh
    )

    output_i_path = os.path.join(output_dir, "multifault_2d.i")
    if dry_run:
        print("\n=== Generated .i ===")
        print(rendered)
        print(f"\n# Would write to: {output_i_path}", file=sys.stderr)
    else:
        with open(output_i_path, "w") as f:
            f.write(rendered)

    _step(6, 6, f"Generated: {output_i_path}")
    print(f"\nPipeline complete: {n_faults} faults -> {output_i_path}")

    return rendered


def main():
    parser = argparse.ArgumentParser(
        description="Automated Multi-Fault 2D Pipeline"
    )
    parser.add_argument(
        "config",
        help="Path to JSON configuration file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print output to stdout instead of writing files",
    )
    parser.add_argument(
        "--output-dir",
        help="Output directory (default: same as config file)",
    )

    args = parser.parse_args()
    run_pipeline(args.config, args.output_dir, args.dry_run)


if __name__ == "__main__":
    main()

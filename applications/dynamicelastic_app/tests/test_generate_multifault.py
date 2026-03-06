#!/usr/bin/env python3
"""Unit tests for generate_multifault.py."""

"""
python -m unittest discover -s tests -v
showing each test case with ok/FAIL
status
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

# Add parent directory to path so we can import the module under test
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from generate_multifault import (
    InitialShearStressFunction,
    StaticFrictionFunction,
    _is_shared_endpoint,
    _min_segment_distance,
    _rectangles_overlap,
    _segments_intersect,
    build_functions_block,
    build_vectorpostprocessors,
    generate_geo,
    get_block_pairs_string,
    get_boundary_list_string,
    get_subdomain_ids_for_faults,
    render_input_file,
    validate_config,
)

# Points to the dynamicelastic_app directory (parent of tests/)
APP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def _make_base_config(**overrides):
    """Create a minimal valid config, optionally with overrides."""
    config = {
        "domain": {
            "xmin": -26000,
            "xmax": 24000,
            "ymin": -20000,
            "ymax": 20000,
            "element_size": 100,
        },
        "faults": [
            {
                "label": "fault_1",
                "start": [-16000, 0.0],
                "end": [12000, 0.0],
            }
        ],
        "initial_shear_stress": {
            "background": 70.0e6,
            "patches": [],
        },
        "physics": {
            "q": 0.1,
            "Dc": 0.4,
            "T2_o": 120e6,
            "mu_s": 0.677,
            "mu_d": 0.525,
            "len": 100,
            "density": 2670,
            "lambda_o": 3.204e10,
            "shear_modulus_o": 3.204e10,
        },
        "execution": {"dt": 0.0025, "end_time": 12},
        "boundary_conditions": {"p_wave_speed": 6000, "shear_wave_speed": 3464},
        "output": {"exodus_interval": 40},
        "mesh_file": None,
    }
    config.update(overrides)
    return config


# ===================================================================
# Function object tests
# ===================================================================


class TestStaticFrictionFunction(unittest.TestCase):
    def test_constant_friction_generates_correct_moose_block(self):
        func = StaticFrictionFunction(0.677)
        d = func.to_moose()
        self.assertEqual(d["type"], "ConstantFunction")
        self.assertEqual(d["value"], 0.677)

        block = func.to_moose_block()
        self.assertIn("func_static_friction_coeff_mus", block)
        self.assertIn("ConstantFunction", block)
        self.assertIn("0.677", block)


class TestInitialShearStressFunction(unittest.TestCase):
    def test_shear_stress_no_patches(self):
        func = InitialShearStressFunction(70e6, [])
        d = func.to_moose()
        self.assertEqual(d["type"], "ParsedFunction")
        self.assertIn("70000000.0", d["expression"])
        # No if() when no patches
        self.assertNotIn("if(", d["expression"])

    def test_shear_stress_single_2d_patch(self):
        patches = [
            {
                "xmin": -9500,
                "xmax": -6500,
                "ymin": -6500,
                "ymax": 6500,
                "value": 81.6e6,
                "label": "nucleation",
            }
        ]
        func = InitialShearStressFunction(70e6, patches)
        d = func.to_moose()
        expr = d["expression"]
        self.assertIn("if(", expr)
        self.assertIn("x>=-9500", expr)
        self.assertIn("x<=-6500", expr)
        self.assertIn("y>=-6500", expr)
        self.assertIn("y<=6500", expr)
        self.assertIn("81600000.0", expr)
        self.assertIn("70000000.0", expr)

    def test_shear_stress_multiple_patches_nested(self):
        patches = [
            {
                "xmin": -9500,
                "xmax": -6500,
                "ymin": -6500,
                "ymax": 6500,
                "value": 81.6e6,
                "label": "nucleation",
            },
            {
                "xmin": 3000,
                "xmax": 6000,
                "ymin": -3000,
                "ymax": 3000,
                "value": 78e6,
                "label": "elevated",
            },
        ]
        func = InitialShearStressFunction(70e6, patches)
        d = func.to_moose()
        expr = d["expression"]
        # Should have nested if()
        self.assertEqual(expr.count("if("), 2)
        self.assertIn("81600000.0", expr)
        self.assertIn("78000000.0", expr)
        self.assertIn("70000000.0", expr)

    def test_shear_stress_overlapping_patches_raises(self):
        patches = [
            {
                "xmin": -9500,
                "xmax": -6500,
                "ymin": -6500,
                "ymax": 6500,
                "value": 81.6e6,
                "label": "nucleation",
            },
            {
                "xmin": -8000,
                "xmax": -5000,
                "ymin": -3000,
                "ymax": 3000,
                "value": 78e6,
                "label": "elevated",
            },
        ]
        with self.assertRaises(ValueError) as ctx:
            InitialShearStressFunction(70e6, patches)
        self.assertIn("overlaps", str(ctx.exception))
        self.assertIn("nucleation", str(ctx.exception))
        self.assertIn("elevated", str(ctx.exception))

    def test_shear_stress_patch_outside_domain_raises(self):
        domain = {"xmin": -8000, "xmax": 8000, "ymin": -8000, "ymax": 8000}
        patches = [
            {
                "xmin": -9500,
                "xmax": -6500,
                "ymin": -6500,
                "ymax": 6500,
                "value": 81.6e6,
                "label": "nucleation",
            },
        ]
        with self.assertRaises(ValueError) as ctx:
            InitialShearStressFunction(70e6, patches, domain=domain)
        self.assertIn("outside the domain", str(ctx.exception))
        self.assertIn("nucleation", str(ctx.exception))


# ===================================================================
# Config validation tests
# ===================================================================


class TestConfigValidation(unittest.TestCase):
    def test_valid_config_passes(self):
        config = _make_base_config()
        validate_config(config)  # should not raise

    def test_crossing_faults_raises(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-10000, -5000], "end": [10000, 5000]},
                {"label": "fault_2", "start": [-10000, 5000], "end": [10000, -5000]},
            ]
        )
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("too close", str(ctx.exception))

    def test_shared_endpoint_ok(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [0.0, 0.0]},
                {"label": "fault_2", "start": [0.0, 0.0], "end": [10392.3, -6000]},
            ]
        )
        validate_config(config)  # should not raise

    def test_fault_outside_domain_raises(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [30000, 0.0]},
            ]
        )
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("outside the domain", str(ctx.exception))

    def test_missing_physics_section_raises(self):
        config = _make_base_config()
        del config["physics"]
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("Missing required config section: 'physics'", str(ctx.exception))

    def test_missing_mu_s_raises(self):
        config = _make_base_config()
        del config["physics"]["mu_s"]
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("physics.mu_s", str(ctx.exception))

    def test_duplicate_fault_labels_raises(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [0.0, 0.0]},
                {"label": "fault_1", "start": [0.0, 0.0], "end": [10000, -5000]},
            ]
        )
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("Duplicate fault label", str(ctx.exception))

    def test_fault_endpoint_on_other_fault_interior_raises(self):
        """fault_2 starts at (0,0) on fault_1's interior — rejected."""
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [12000, 0.0]},
                {"label": "fault_2", "start": [0.0, 0.0], "end": [10392.3, -6000]},
            ]
        )
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("too close", str(ctx.exception))

    def test_faults_too_close_parallel_raises(self):
        """Two parallel faults separated by less than 2 * element_size."""
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-10000, 0.0], "end": [10000, 0.0]},
                {"label": "fault_2", "start": [-10000, 100.0], "end": [10000, 100.0]},
            ]
        )
        # element_size=100, separation=100 < 2*100=200
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("too close", str(ctx.exception))

    def test_faults_sufficient_separation_ok(self):
        """Two faults separated by exactly 2 * element_size — passes."""
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-10000, 0.0], "end": [10000, 0.0]},
                {"label": "fault_2", "start": [-10000, 200.0], "end": [10000, 200.0]},
            ]
        )
        # element_size=100, separation=200 == 2*100 — not strictly less, so passes
        validate_config(config)  # should not raise

    def test_missing_element_size_raises(self):
        config = _make_base_config()
        del config["domain"]["element_size"]
        with self.assertRaises(ValueError) as ctx:
            validate_config(config)
        self.assertIn("domain.element_size", str(ctx.exception))


# ===================================================================
# Geo generation tests
# ===================================================================


class TestGeoGeneration(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_geo_single_fault(self):
        config = _make_base_config()
        geo_path = os.path.join(self.tmpdir, "test.geo")
        content = generate_geo(config, geo_path)

        # Check domain points
        self.assertIn("Point(1)", content)
        self.assertIn("Point(4)", content)
        # Check fault point
        self.assertIn("Point(5)", content)
        self.assertIn("Point(6)", content)
        # Check lines
        self.assertIn("Line(1)", content)
        self.assertIn("Line(5)", content)
        # Check Physical Curve for fault
        self.assertIn('Physical Curve("fault_1")', content)
        # Check domain boundaries
        self.assertIn('Physical Curve("bottom")', content)
        self.assertIn('Physical Curve("right")', content)
        self.assertIn('Physical Curve("top")', content)
        self.assertIn('Physical Curve("left")', content)
        # Check surface
        self.assertIn('Physical Surface("100")', content)
        self.assertIn("Mesh.Algorithm = 6", content)

    def test_geo_two_faults_with_shared_point(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [0.0, 0.0]},
                {"label": "fault_2", "start": [0.0, 0.0], "end": [10392.3, -6000]},
            ]
        )
        geo_path = os.path.join(self.tmpdir, "test.geo")
        content = generate_geo(config, geo_path)

        # Each fault is a single line from start to end (no junction splitting)
        self.assertIn('Physical Curve("fault_1")', content)
        self.assertIn('Physical Curve("fault_2")', content)
        # fault_2 start (0,0) is shared endpoint with fault_1 end
        # each fault is still one line — no comma in Physical Curve
        fault_1_line = [
            l for l in content.split("\n") if 'Physical Curve("fault_1")' in l
        ][0]
        # Single line ID, no comma
        self.assertNotIn(",", fault_1_line)
        # The shared point (0,0) should still be embedded in the surface
        self.assertIn("Point{", content)

    def test_geo_three_faults(self):
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [-5000, 0.0]},
                {"label": "fault_2", "start": [0.0, 5000], "end": [10000, 5000]},
                {"label": "fault_3", "start": [0.0, -5000], "end": [10000, -5000]},
            ]
        )
        geo_path = os.path.join(self.tmpdir, "test.geo")
        content = generate_geo(config, geo_path)

        self.assertIn('Physical Curve("fault_1")', content)
        self.assertIn('Physical Curve("fault_2")', content)
        self.assertIn('Physical Curve("fault_3")', content)

    def test_geo_file_written(self):
        config = _make_base_config()
        geo_path = os.path.join(self.tmpdir, "test.geo")
        generate_geo(config, geo_path)
        self.assertTrue(os.path.exists(geo_path))
        with open(geo_path) as f:
            content = f.read()
        self.assertIn("lc = 100", content)


# ===================================================================
# Subdomain assignment tests
# ===================================================================


class TestSubdomainAssignment(unittest.TestCase):
    def test_subdomain_ids_two_faults(self):
        faults = [
            {"label": "fault_1"},
            {"label": "fault_2"},
        ]
        ids = get_subdomain_ids_for_faults(faults)
        self.assertEqual(ids["fault_1"], (100, 200))
        self.assertEqual(ids["fault_2"], (300, 400))

    def test_subdomain_ids_three_faults(self):
        faults = [
            {"label": "fault_1"},
            {"label": "fault_2"},
            {"label": "fault_3"},
        ]
        ids = get_subdomain_ids_for_faults(faults)
        self.assertEqual(ids["fault_1"], (100, 200))
        self.assertEqual(ids["fault_2"], (300, 400))
        self.assertEqual(ids["fault_3"], (500, 600))

    def test_block_pairs_ordering(self):
        faults = [
            {"label": "fault_1"},
            {"label": "fault_2"},
            {"label": "fault_3"},
        ]
        ids = get_subdomain_ids_for_faults(faults)
        for label, (upper, lower) in ids.items():
            self.assertLess(upper, lower, f"Block pair for {label}: {upper} >= {lower}")


# ===================================================================
# N-fault boundary propagation tests
# ===================================================================


class TestBoundaryPropagation(unittest.TestCase):
    def test_boundary_list_two_faults(self):
        faults = [{"label": "fault_1"}, {"label": "fault_2"}]
        result = get_boundary_list_string(faults)
        self.assertEqual(result, "Block100_Block200 Block300_Block400")

    def test_boundary_list_three_faults(self):
        faults = [{"label": "fault_1"}, {"label": "fault_2"}, {"label": "fault_3"}]
        result = get_boundary_list_string(faults)
        self.assertEqual(
            result, "Block100_Block200 Block300_Block400 Block500_Block600"
        )

    def test_block_pairs_two_faults(self):
        faults = [{"label": "fault_1"}, {"label": "fault_2"}]
        result = get_block_pairs_string(faults)
        self.assertEqual(result, "100 200; 300 400")

    def test_block_pairs_three_faults(self):
        faults = [{"label": "fault_1"}, {"label": "fault_2"}, {"label": "fault_3"}]
        result = get_block_pairs_string(faults)
        self.assertEqual(result, "100 200; 300 400; 500 600")


# ===================================================================
# VPP generation tests
# ===================================================================


class TestVPPGeneration(unittest.TestCase):
    def test_vpp_per_fault_naming(self):
        faults = [
            {"label": "fault_1", "start": [-16000, 0.0], "end": [12000, 0.0]},
            {"label": "fault_2", "start": [0, -200], "end": [0, -6000]},
        ]
        result = build_vectorpostprocessors(faults)

        self.assertIn("[fault_1]", result)
        self.assertIn("[fault_2]", result)
        self.assertIn("type = SideValueSampler", result)
        self.assertIn("boundary = 'Block100_Block200'", result)
        self.assertIn("boundary = 'Block300_Block400'", result)
        self.assertIn("sort_by = x", result)
        self.assertIn("sort_by = y", result)

    def test_vpp_three_faults_produces_3_blocks(self):
        faults = [
            {"label": "fault_1", "start": [-16000, 0.0], "end": [12000, 0.0]},
            {"label": "fault_2", "start": [200, -200], "end": [10392.3, -6000]},
            {"label": "fault_3", "start": [200, 200], "end": [10392.3, 6000]},
        ]
        result = build_vectorpostprocessors(faults)

        # 1 block per fault = 3 total
        block_count = result.count("type = SideValueSampler")
        self.assertEqual(block_count, 3)


# ===================================================================
# Template rendering tests
# ===================================================================


class TestTemplateRendering(unittest.TestCase):
    def test_all_placeholders_replaced(self):
        template_path = os.path.join(APP_DIR, "templates", "multifault_2d.i.template")
        config = _make_base_config(
            faults=[
                {"label": "fault_1", "start": [-16000, 0.0], "end": [12000, 0.0]},
                {"label": "fault_2", "start": [200, -200], "end": [10392.3, -6000]},
            ]
        )
        config["initial_shear_stress"] = {
            "background": 70e6,
            "patches": [
                {
                    "xmin": -9500,
                    "xmax": -6500,
                    "ymin": -6500,
                    "ymax": 6500,
                    "value": 81.6e6,
                    "label": "nucleation",
                }
            ],
        }
        config["output"] = {"exodus_interval": 40, "csv_interval": 40}

        mesh_data = {
            "element_ids": "1 2 3 4 5",
            "subdomain_ids": "100 100 200 200 300",
            "block_pairs": "100 200; 300 400",
            "boundary_list": "Block100_Block200 Block300_Block400",
        }

        rendered = render_input_file(
            template_path, config, mesh_data, "output.msh"
        )

        # No __XX__ markers should remain
        self.assertNotIn("__PARAM_BLOCK__", rendered)
        self.assertNotIn("__MESH_FILE__", rendered)
        self.assertNotIn("__ELEMENT_IDS__", rendered)
        self.assertNotIn("__SUBDOMAIN_IDS__", rendered)
        self.assertNotIn("__BLOCK_PAIRS__", rendered)
        self.assertNotIn("__BOUNDARY_LIST__", rendered)
        self.assertNotIn("__FUNCTIONS_BLOCK__", rendered)
        self.assertNotIn("__VECTORPOSTPROCESSORS__", rendered)

        # Check content was substituted
        self.assertIn("output.msh", rendered)
        self.assertIn("100 200; 300 400", rendered)
        self.assertIn("Block100_Block200 Block300_Block400", rendered)
        self.assertIn("[func_static_friction_coeff_mus]", rendered)
        self.assertIn("[func_initial_strike_shear_stress]", rendered)
        self.assertIn("[func_initial_normal_stress]", rendered)
        self.assertIn("FarmsMaterialRealAux", rendered)
        self.assertIn("local_shear_jump", rendered)
        self.assertIn("SideValueSampler", rendered)
        self.assertIn("[fault_1]", rendered)
        self.assertIn("[fault_2]", rendered)
        self.assertIn("csv_interval", rendered)


# ===================================================================
# Segment intersection tests
# ===================================================================


class TestSegmentIntersection(unittest.TestCase):
    def test_crossing_segments(self):
        crosses, pt = _segments_intersect([-1, -1], [1, 1], [-1, 1], [1, -1])
        self.assertTrue(crosses)
        self.assertAlmostEqual(pt[0], 0.0, places=5)
        self.assertAlmostEqual(pt[1], 0.0, places=5)

    def test_shared_endpoint_not_crossing(self):
        crosses, _ = _segments_intersect([-1, 0], [0, 0], [0, 0], [1, -1])
        self.assertFalse(crosses)

    def test_parallel_segments(self):
        crosses, _ = _segments_intersect([0, 0], [1, 0], [0, 1], [1, 1])
        self.assertFalse(crosses)

    def test_non_intersecting(self):
        crosses, _ = _segments_intersect([0, 0], [1, 0], [2, 1], [3, 1])
        self.assertFalse(crosses)


# ===================================================================
# Rectangle overlap tests
# ===================================================================


class TestRectangleOverlap(unittest.TestCase):
    def test_overlapping(self):
        a = {"xmin": 0, "xmax": 10, "ymin": 0, "ymax": 10}
        b = {"xmin": 5, "xmax": 15, "ymin": 5, "ymax": 15}
        self.assertTrue(_rectangles_overlap(a, b))

    def test_non_overlapping(self):
        a = {"xmin": 0, "xmax": 5, "ymin": 0, "ymax": 5}
        b = {"xmin": 10, "xmax": 15, "ymin": 10, "ymax": 15}
        self.assertFalse(_rectangles_overlap(a, b))

    def test_touching_edge(self):
        a = {"xmin": 0, "xmax": 5, "ymin": 0, "ymax": 5}
        b = {"xmin": 5, "xmax": 10, "ymin": 0, "ymax": 5}
        self.assertFalse(_rectangles_overlap(a, b))


# ===================================================================
# Integration tests (require gmsh)
# ===================================================================


def _gmsh_available():
    """Check if gmsh is available."""
    try:
        import subprocess

        result = subprocess.run(["gmsh", "--version"], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False


@unittest.skipUnless(_gmsh_available(), "gmsh not available")
class TestIntegration(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir)

    def test_full_pipeline_tpv14_config(self):
        """End-to-end with 2-fault TPV14 config."""
        from generate_multifault import run_pipeline

        config_path = os.path.join(APP_DIR, "config", "example_config_multifault.json")
        # Copy config to tmpdir so output goes there
        tmp_config = os.path.join(self.tmpdir, "config.json")
        with open(config_path) as f:
            config = json.load(f)
        with open(tmp_config, "w") as f:
            json.dump(config, f)

        rendered = run_pipeline(tmp_config, output_dir=self.tmpdir)

        # Check files were created
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "output.geo")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "output.msh")))
        self.assertTrue(os.path.exists(os.path.join(self.tmpdir, "multifault_2d.i")))

        # Check no placeholders remain
        self.assertNotIn("__", rendered)

        # Check key content
        self.assertIn("Block100_Block200", rendered)
        self.assertIn("Block300_Block400", rendered)
        self.assertIn("100 200; 300 400", rendered)

    def test_full_pipeline_single_fault(self):
        """Single horizontal fault, validates simple planar fault case."""
        from generate_multifault import run_pipeline

        config = {
            "domain": {
                "xmin": -15000,
                "xmax": 15000,
                "ymin": -15000,
                "ymax": 15000,
                "element_size": 200,
            },
            "faults": [
                {"label": "fault_1", "start": [-12000, 0.0], "end": [12000, 0.0]}
            ],
            "initial_shear_stress": {
                "background": 70e6,
                "patches": [],
            },
            "physics": {
                "q": 0.2,
                "Dc": 0.4,
                "T2_o": 120e6,
                "mu_s": 0.677,
                "mu_d": 0.525,
                "len": 200,
                "density": 2670,
                "lambda_o": 3.204e10,
                "shear_modulus_o": 3.204e10,
            },
            "execution": {"dt": 0.01, "end_time": 12},
            "boundary_conditions": {"p_wave_speed": 6000, "shear_wave_speed": 3464},
            "output": {"exodus_interval": 10},
            "mesh_file": None,
        }
        tmp_config = os.path.join(self.tmpdir, "config.json")
        with open(tmp_config, "w") as f:
            json.dump(config, f)

        rendered = run_pipeline(tmp_config, output_dir=self.tmpdir)

        self.assertNotIn("__", rendered)
        self.assertIn("Block100_Block200", rendered)
        self.assertNotIn("Block300", rendered)  # only 1 fault


if __name__ == "__main__":
    unittest.main()

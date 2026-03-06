#!/usr/bin/env python3
"""Unit tests for generate_input.py"""

"""
python -m unittest discover -s tests -v
showing each test case with ok/FAIL
status
"""


import json
import os
import sys
import tempfile
import unittest

# Add parent directory to path so we can import the module under test
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from generate_input import (
    deep_merge,
    flatten_params,
    format_value,
    generate,
    generate_param_block,
    load_defaults,
    render_template,
    resolve_preset_key,
    validate_params,
)

# Points to the dynamicelastic_app directory (parent of tests/)
APP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DEFAULTS_PATH = os.path.join(APP_DIR, "config", "defaults.json")


class TestResolvePresetKey(unittest.TestCase):
    def test_tpv205_2d_default_is_tria(self):
        self.assertEqual(resolve_preset_key("tpv205_2d"), "tpv205_2d_tria")

    def test_tpv205_2d_tria(self):
        self.assertEqual(resolve_preset_key("tpv205_2d", "tria"), "tpv205_2d_tria")

    def test_tpv205_2d_quad(self):
        self.assertEqual(resolve_preset_key("tpv205_2d", "quad"), "tpv205_2d_quad")

    def test_tpv205_2d_invalid_variant(self):
        with self.assertRaises(ValueError) as ctx:
            resolve_preset_key("tpv205_2d", "hex")
        self.assertIn("hex", str(ctx.exception))

    def test_tpv205_3d(self):
        self.assertEqual(resolve_preset_key("tpv205_3d"), "tpv205_3d")

    def test_tpv26_3d(self):
        self.assertEqual(resolve_preset_key("tpv26_3d"), "tpv26_3d")

    def test_unknown_benchmark(self):
        with self.assertRaises(ValueError) as ctx:
            resolve_preset_key("invalid")
        self.assertIn("Unknown benchmark", str(ctx.exception))

    def test_3d_ignores_mesh_variant(self):
        # Should not raise, just warn to stderr
        result = resolve_preset_key("tpv205_3d", "tet")
        self.assertEqual(result, "tpv205_3d")


class TestDeepMerge(unittest.TestCase):
    def test_simple_override(self):
        base = {"a": 1, "b": 2}
        overrides = {"b": 3}
        result = deep_merge(base, overrides)
        self.assertEqual(result, {"a": 1, "b": 3})

    def test_nested_override(self):
        base = {"cat": {"x": 1, "y": 2}, "other": 10}
        overrides = {"cat": {"y": 99}}
        result = deep_merge(base, overrides)
        self.assertEqual(result, {"cat": {"x": 1, "y": 99}, "other": 10})

    def test_add_new_key(self):
        base = {"a": 1}
        overrides = {"b": 2}
        result = deep_merge(base, overrides)
        self.assertEqual(result, {"a": 1, "b": 2})

    def test_does_not_mutate_base(self):
        base = {"cat": {"x": 1}}
        overrides = {"cat": {"x": 99}}
        deep_merge(base, overrides)
        self.assertEqual(base, {"cat": {"x": 1}})

    def test_deep_nested(self):
        base = {"a": {"b": {"c": 1, "d": 2}}}
        overrides = {"a": {"b": {"c": 10}}}
        result = deep_merge(base, overrides)
        self.assertEqual(result, {"a": {"b": {"c": 10, "d": 2}}})


class TestValidateParams(unittest.TestCase):
    def _base_params(self):
        return {
            "slip_weakening": {"q": 0.2, "Dc": 0.4, "len": 200},
            "material": {
                "density": 2670,
                "lambda_o": 3.204e10,
                "shear_modulus_o": 3.204e10,
            },
            "execution": {"dt": 0.01, "end_time": 12},
            "output": {"exodus_interval": 10},
        }

    def test_valid_params_pass(self):
        # Should not raise
        validate_params(self._base_params())

    def test_q_out_of_range(self):
        params = self._base_params()
        params["slip_weakening"]["q"] = 1.5
        with self.assertRaises(ValueError) as ctx:
            validate_params(params)
        self.assertIn("q", str(ctx.exception))

    def test_negative_Dc(self):
        params = self._base_params()
        params["slip_weakening"]["Dc"] = -0.1
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_zero_dt(self):
        params = self._base_params()
        params["execution"]["dt"] = 0
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_negative_density(self):
        params = self._base_params()
        params["material"]["density"] = -100
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_invalid_exodus_interval(self):
        params = self._base_params()
        params["output"]["exodus_interval"] = -5
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_float_exodus_interval(self):
        params = self._base_params()
        params["output"]["exodus_interval"] = 10.5
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_empty_params_pass(self):
        # No categories at all — should not raise
        validate_params({})

    def test_multiple_errors(self):
        params = self._base_params()
        params["slip_weakening"]["q"] = -1
        params["execution"]["dt"] = -0.01
        with self.assertRaises(ValueError) as ctx:
            validate_params(params)
        msg = str(ctx.exception)
        self.assertIn("q", msg)
        self.assertIn("dt", msg)

    def test_negative_Cd_constant(self):
        params = self._base_params()
        params["cdb_model"] = {"Cd_constant": -1}
        with self.assertRaises(ValueError):
            validate_params(params)

    def test_zero_Cd_constant_is_valid(self):
        params = self._base_params()
        params["cdb_model"] = {"Cd_constant": 0}
        validate_params(params)  # Should not raise


class TestFlattenParams(unittest.TestCase):
    def test_basic_flatten(self):
        params = {
            "template": "test.i.template",
            "output_dir": "out",
            "material": {"density": 2670, "lambda_o": 3.204e10},
            "execution": {"dt": 0.01},
        }
        flat = flatten_params(params)
        self.assertEqual(flat, {"density": 2670, "lambda_o": 3.204e10, "dt": 0.01})

    def test_skips_metadata_keys(self):
        params = {
            "template": "x.i.template",
            "output_dir": "dir",
            "output_filename": "out.i",
            "material": {"density": 100},
        }
        flat = flatten_params(params)
        self.assertNotIn("template", flat)
        self.assertNotIn("output_dir", flat)
        self.assertNotIn("output_filename", flat)
        self.assertIn("density", flat)


class TestFormatValue(unittest.TestCase):
    def test_bool_true(self):
        self.assertEqual(format_value(True), "true")

    def test_bool_false(self):
        self.assertEqual(format_value(False), "false")

    def test_integer(self):
        self.assertEqual(format_value(2670), "2670")

    def test_small_float(self):
        self.assertEqual(format_value(0.4), "0.4")

    def test_scientific_notation_large(self):
        result = format_value(3.204e10)
        self.assertIn("e", result.lower() or "E" in result)
        self.assertAlmostEqual(float(result), 3.204e10, places=2)

    def test_scientific_notation_small(self):
        result = format_value(1e-10)
        self.assertAlmostEqual(float(result), 1e-10, places=20)

    def test_string(self):
        self.assertEqual(format_value("../mesh/test.msh"), "../mesh/test.msh")

    def test_zero_float(self):
        result = format_value(0.0)
        self.assertEqual(float(result), 0.0)

    def test_negative_float(self):
        result = format_value(-0.169029)
        self.assertAlmostEqual(float(result), -0.169029, places=6)

    def test_precision_preserved(self):
        result = format_value(1.073206)
        self.assertAlmostEqual(float(result), 1.073206, places=6)


class TestGenerateParamBlock(unittest.TestCase):
    def test_basic_output(self):
        flat = {"dt": 0.01, "density": 2670}
        block = generate_param_block(flat)
        self.assertIn("density = 2670", block)
        self.assertIn("dt = 0.01", block)
        self.assertIn("#parameters", block)

    def test_sorted_output(self):
        flat = {"z_param": 1, "a_param": 2}
        block = generate_param_block(flat)
        a_pos = block.index("a_param")
        z_pos = block.index("z_param")
        self.assertLess(a_pos, z_pos)

    def test_bool_formatting(self):
        flat = {"use_tapering": True}
        block = generate_param_block(flat)
        self.assertIn("use_tapering = true", block)


class TestRenderTemplate(unittest.TestCase):
    def test_replaces_param_block(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".template", delete=False
        ) as f:
            f.write("__PARAM_BLOCK__\n[Mesh]\n  file = '${mesh_file}'\n[]")
            f.flush()
            result = render_template(f.name, "mesh_file = test.msh\n")
            self.assertIn("mesh_file = test.msh", result)
            self.assertNotIn("__PARAM_BLOCK__", result)
            self.assertIn("${mesh_file}", result)
        os.unlink(f.name)

    def test_missing_marker_raises(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".template", delete=False
        ) as f:
            f.write("[Mesh]\n  file = test.msh\n[]")
            f.flush()
            with self.assertRaises(ValueError):
                render_template(f.name, "param = value")
        os.unlink(f.name)


class TestLoadDefaults(unittest.TestCase):
    def test_has_common_and_benchmarks(self):
        defaults = load_defaults(DEFAULTS_PATH)
        self.assertIn("common", defaults)
        self.assertIn("benchmarks", defaults)

    def test_common_has_material(self):
        defaults = load_defaults(DEFAULTS_PATH)
        self.assertIn("material", defaults["common"])
        mat = defaults["common"]["material"]
        self.assertEqual(mat["density"], 2670)
        self.assertAlmostEqual(mat["lambda_o"], 3.204e10)
        self.assertAlmostEqual(mat["shear_modulus_o"], 3.204e10)

    def test_common_has_end_time(self):
        defaults = load_defaults(DEFAULTS_PATH)
        self.assertIn("execution", defaults["common"])
        self.assertEqual(defaults["common"]["execution"]["end_time"], 12)

    def test_loads_all_presets(self):
        defaults = load_defaults(DEFAULTS_PATH)
        benchmarks = defaults["benchmarks"]
        self.assertIn("tpv205_2d_tria", benchmarks)
        self.assertIn("tpv205_2d_quad", benchmarks)
        self.assertIn("tpv205_3d", benchmarks)
        self.assertIn("tpv26_3d", benchmarks)

    def test_preset_has_required_keys(self):
        defaults = load_defaults(DEFAULTS_PATH)
        for key, preset in defaults["benchmarks"].items():
            self.assertIn("template", preset, f"{key} missing 'template'")
            self.assertIn("output_dir", preset, f"{key} missing 'output_dir'")
            self.assertIn("execution", preset, f"{key} missing 'execution'")
        # material is in common, not duplicated in benchmarks
        self.assertIn("material", defaults["common"])

    def test_merged_preset_has_material(self):
        """Verify that material from common merges into each benchmark."""
        defaults = load_defaults(DEFAULTS_PATH)
        common = defaults["common"]
        for key, preset in defaults["benchmarks"].items():
            merged = deep_merge(common, preset)
            self.assertIn("material", merged, f"{key} missing 'material' after merge")
            self.assertEqual(merged["material"]["density"], 2670)

    def test_merged_preset_has_end_time_and_dt(self):
        """Verify common end_time merges with benchmark dt."""
        defaults = load_defaults(DEFAULTS_PATH)
        common = defaults["common"]
        for key, preset in defaults["benchmarks"].items():
            merged = deep_merge(common, preset)
            self.assertIn("end_time", merged["execution"])
            self.assertIn("dt", merged["execution"])

    def test_file_not_found(self):
        with self.assertRaises(FileNotFoundError):
            load_defaults("/nonexistent/path.json")


class TestGenerate(unittest.TestCase):
    """Integration tests for the full generate pipeline."""

    def _write_config(self, config_dict):
        f = tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, dir=APP_DIR
        )
        json.dump(config_dict, f)
        f.close()
        return f.name

    def test_tpv205_2d_default(self):
        config_path = self._write_config({"benchmark": "tpv205_2d"})
        try:
            output_path, rendered = generate(config_path)
            self.assertIn("tpv2052D_tria.i", output_path)
            self.assertIn("q = 0.2", rendered)
            self.assertIn("Dc = 0.4", rendered)
            self.assertIn("density = 2670", rendered)
            self.assertNotIn("__PARAM_BLOCK__", rendered)
        finally:
            os.unlink(config_path)

    def test_tpv205_2d_quad(self):
        config_path = self._write_config(
            {"benchmark": "tpv205_2d", "mesh_variant": "quad"}
        )
        try:
            output_path, rendered = generate(config_path)
            self.assertIn("tpv2052D_quad.i", output_path)
            self.assertIn("q = 0.1", rendered)
            self.assertIn("nx = 400", rendered)
        finally:
            os.unlink(config_path)

    def test_tpv26_3d_with_overrides(self):
        config_path = self._write_config(
            {
                "benchmark": "tpv26_3d",
                "overrides": {
                    "slip_weakening": {"Dc": 0.5},
                    "execution": {"end_time": 6.0},
                },
            }
        )
        try:
            output_path, rendered = generate(config_path)
            self.assertIn("tpv263D_tet.i", output_path)
            self.assertIn("Dc = 0.5", rendered)
            self.assertIn("end_time = 6", rendered)
            # Unchanged defaults should still be present
            self.assertIn("mu_d = 0.12", rendered)
            self.assertIn("mu_s = 0.18", rendered)
        finally:
            os.unlink(config_path)

    def test_tpv205_2d_has_mu_s_and_initial_shear_stress(self):
        config_path = self._write_config({"benchmark": "tpv205_2d"})
        try:
            output_path, rendered = generate(config_path)
            # mu_s should appear in param block and be substituted in Functions
            self.assertIn("mu_s = 0.677", rendered)
            # initial_shear_stress values should appear in param block
            self.assertIn("T1_o = 70000000", rendered)
            self.assertIn("T1_o_elevated = 78000000", rendered)
            self.assertIn("T1_o_nucleation = 81600000", rendered)
            self.assertIn("T1_o_reduced = 62000000", rendered)
            # Hardcoded values should NOT appear in Functions block
            self.assertNotIn("y = '10000 0.677 10000.0'", rendered)
            self.assertNotIn("y = ' 70.0e6 78.0e6", rendered)
        finally:
            os.unlink(config_path)

    def test_missing_benchmark_raises(self):
        config_path = self._write_config({"overrides": {}})
        try:
            with self.assertRaises(ValueError) as ctx:
                generate(config_path)
            self.assertIn("benchmark", str(ctx.exception))
        finally:
            os.unlink(config_path)

    def test_invalid_benchmark_raises(self):
        config_path = self._write_config({"benchmark": "nonexistent"})
        try:
            with self.assertRaises(ValueError):
                generate(config_path)
        finally:
            os.unlink(config_path)

    def test_output_dir_override(self):
        config_path = self._write_config({"benchmark": "tpv205_2d"})
        try:
            output_path, _ = generate(config_path, output_dir_override="/tmp/test_out")
            self.assertTrue(output_path.startswith("/tmp/test_out"))
        finally:
            os.unlink(config_path)

    def test_output_filename_override(self):
        config_path = self._write_config(
            {"benchmark": "tpv205_2d", "output_filename": "custom_name.i"}
        )
        try:
            output_path, _ = generate(config_path)
            self.assertIn("custom_name.i", output_path)
        finally:
            os.unlink(config_path)

    def test_validation_failure_in_generate(self):
        config_path = self._write_config(
            {
                "benchmark": "tpv205_2d",
                "overrides": {
                    "slip_weakening": {"q": 5.0},
                },
            }
        )
        try:
            with self.assertRaises(ValueError) as ctx:
                generate(config_path)
            self.assertIn("q", str(ctx.exception))
        finally:
            os.unlink(config_path)

    def test_tpv205_3d_default(self):
        config_path = self._write_config({"benchmark": "tpv205_3d"})
        try:
            output_path, rendered = generate(config_path)
            self.assertIn("tpv2053D_tet.i", output_path)
            self.assertIn("T3_o = 0", rendered)
            self.assertIn("checkpoint_num_files = 2", rendered)
        finally:
            os.unlink(config_path)


class TestThreeLayerMerge(unittest.TestCase):
    """Test the 3-layer merge: common -> benchmark -> user overrides."""

    def _make_defaults(self, tmpdir):
        defaults = {
            "common": {
                "material": {
                    "density": 2670,
                    "lambda_o": 3.204e10,
                    "shear_modulus_o": 3.204e10,
                },
                "execution": {"end_time": 12},
            },
            "benchmarks": {
                "tpv205_2d_tria": {
                    "template": "tpv2052D_tria.i.template",
                    "output_dir": "2d_slipweakening_tpv205",
                    "output_filename": "tpv2052D_tria.i",
                    "slip_weakening": {"q": 0.2, "Dc": 0.4},
                    "execution": {"dt": 0.01},
                },
            },
        }
        path = os.path.join(tmpdir, "defaults.json")
        with open(path, "w") as f:
            json.dump(defaults, f)
        return path

    def test_common_values_present_without_overrides(self):
        """material from common should appear in merged params."""
        config_path = None
        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                defaults_path = self._make_defaults(tmpdir)
                # Create a minimal template
                tpl_dir = os.path.join(tmpdir, "templates")
                os.makedirs(tpl_dir)
                with open(os.path.join(tpl_dir, "tpv2052D_tria.i.template"), "w") as f:
                    f.write("__PARAM_BLOCK__\ntest")
                config_path = os.path.join(tmpdir, "config.json")
                with open(config_path, "w") as f:
                    json.dump({"benchmark": "tpv205_2d"}, f)
                # Patch TEMPLATES_DIR for this test
                import generate_input

                orig_templates = generate_input.TEMPLATES_DIR
                generate_input.TEMPLATES_DIR = tpl_dir
                try:
                    _, rendered = generate(config_path, defaults_path=defaults_path)
                    self.assertIn("density = 2670", rendered)
                    self.assertIn("end_time = 12", rendered)
                    self.assertIn("dt = 0.01", rendered)
                    self.assertIn("q = 0.2", rendered)
                finally:
                    generate_input.TEMPLATES_DIR = orig_templates
        except Exception:
            raise

    def test_user_overrides_take_precedence(self):
        """User overrides should override both common and benchmark values."""
        with tempfile.TemporaryDirectory() as tmpdir:
            defaults_path = self._make_defaults(tmpdir)
            tpl_dir = os.path.join(tmpdir, "templates")
            os.makedirs(tpl_dir)
            with open(os.path.join(tpl_dir, "tpv2052D_tria.i.template"), "w") as f:
                f.write("__PARAM_BLOCK__\ntest")
            config_path = os.path.join(tmpdir, "config.json")
            with open(config_path, "w") as f:
                json.dump(
                    {
                        "benchmark": "tpv205_2d",
                        "overrides": {
                            "material": {"density": 3000},
                            "execution": {"end_time": 6.0},
                        },
                    },
                    f,
                )
            import generate_input

            orig_templates = generate_input.TEMPLATES_DIR
            generate_input.TEMPLATES_DIR = tpl_dir
            try:
                _, rendered = generate(config_path, defaults_path=defaults_path)
                self.assertIn("density = 3000", rendered)
                self.assertIn("end_time = 6", rendered)
                # benchmark dt should still come through
                self.assertIn("dt = 0.01", rendered)
                # common lambda_o should still come through
                self.assertIn("lambda_o", rendered)
            finally:
                generate_input.TEMPLATES_DIR = orig_templates

    def test_benchmark_overrides_common(self):
        """Benchmark-specific execution.dt should not clobber common end_time."""
        defaults = load_defaults(DEFAULTS_PATH)
        common = defaults["common"]
        benchmark = defaults["benchmarks"]["tpv205_2d_tria"]
        merged = deep_merge(common, benchmark)
        # end_time from common
        self.assertEqual(merged["execution"]["end_time"], 12)
        # dt from benchmark
        self.assertEqual(merged["execution"]["dt"], 0.01)


if __name__ == "__main__":
    unittest.main()

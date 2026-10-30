import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.normalize_catalog_routine_dump import missing_terminators, normalize


class RoutineDumpNormalizerTests(unittest.TestCase):
    def test_adds_only_missing_outer_statement_terminator(self):
        source = (
            "CREATE OR REPLACE FUNCTION private.one() RETURNS trigger LANGUAGE plpgsql "
            "SECURITY DEFINER SET search_path TO '' AS $function$ BEGIN NULL; END $function$\n\n"
            "CREATE OR REPLACE FUNCTION private.two() RETURNS integer LANGUAGE sql "
            "AS $function$ SELECT 1 $function$;\n"
        )
        result = normalize(source)
        self.assertEqual(len(missing_terminators(source)), 1)
        self.assertIn("END $function$;\n\nCREATE OR REPLACE FUNCTION private.two()", result)
        self.assertIn("SECURITY DEFINER SET search_path TO ''", result)
        self.assertIn("BEGIN NULL; END", result)
        self.assertEqual(missing_terminators(result), [])

    def test_rejects_unbalanced_outer_dollar_quote(self):
        source = "CREATE FUNCTION private.broken() RETURNS void AS $function$ BEGIN NULL;"
        with self.assertRaisesRegex(ValueError, "Unbalanced outer dollar quote"):
            missing_terminators(source)


if __name__ == "__main__":
    unittest.main()

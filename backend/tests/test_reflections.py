"""
Unit tests for the solo (single-user) reflection analysis.

Covers the demo/fallback payloads (always available, no model needed) and the
defensive default-filling that guarantees the app can decode a thin model response.

Run with pytest (`pytest backend/tests`) or standalone
(`python tests/test_reflections.py`). No third-party deps.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import analysis  # noqa: E402

MODES = ["decode", "prep", "reflect"]

# The keys the iOS PresenceSoloResponse decoder needs (reframe is optional).
REQUIRED = {
    "summary": {"headline": str},
    "translation": {"what_they_may_have_meant": str, "their_possible_need": str},
    "your_part": str,
    "suggested_next": str,
    "confidence": str,
}


def _check(node, schema, path=""):
    problems = []
    if isinstance(schema, dict):
        if not isinstance(node, dict):
            return [f"{path or '<root>'}: expected object"]
        for k, sub in schema.items():
            p = f"{path}.{k}" if path else k
            if k not in node:
                problems.append(f"MISSING {p}")
            else:
                problems += _check(node[k], sub, p)
    else:
        if not isinstance(node, schema):
            problems.append(f"WRONG-TYPE {path}: {type(node).__name__} != {schema.__name__}")
    return problems


def test_demo_reflection_each_mode_is_contract_shaped():
    for mode in MODES:
        body = analysis.demo_reflection(mode)
        problems = _check(body, REQUIRED)
        assert not problems, f"{mode}: {problems}"


def test_demo_reflection_unknown_mode_falls_back_to_decode():
    assert analysis.demo_reflection("nonsense") == analysis.demo_reflection("decode")


def test_demo_reflection_content_differs_by_mode():
    heads = {m: analysis.demo_reflection(m)["summary"]["headline"] for m in MODES}
    assert len(set(heads.values())) == len(MODES), "each mode should read differently"


def test_fill_defaults_completes_a_thin_response():
    thin = {"summary": {}}  # everything else missing
    filled = analysis._fill_reflection_defaults(thin)
    assert _check(filled, REQUIRED) == []
    assert filled["translation"]["what_they_may_have_meant"] == ""
    assert filled["confidence"] == "low"


def test_fill_defaults_preserves_real_values():
    body = {
        "summary": {"headline": "kept"},
        "translation": {"what_they_may_have_meant": "a", "their_possible_need": "b"},
        "your_part": "c", "suggested_next": "d", "confidence": "medium",
    }
    filled = analysis._fill_reflection_defaults(dict(body))
    assert filled["summary"]["headline"] == "kept"
    assert filled["confidence"] == "medium"
    assert filled["suggested_next"] == "d"


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items())
             if k.startswith("test_") and callable(v)]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"PASS {t.__name__}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {t.__name__}: {e}")
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"ERROR {t.__name__}: {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failed}/{len(tests)} passed")
    sys.exit(1 if failed else 0)

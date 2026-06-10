"""
Unit tests for signals.py — the *measured* core of the analyze pipeline
(word_balance, interruptions, key-moment grounding). These are the numbers the
product treats as facts, so they need coverage independent of any LLM.

Runs with pytest (`pytest backend/tests`) or standalone (`python tests/test_signals.py`)
— no third-party dependencies required.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import signals  # noqa: E402

P1, P2 = "You", "Your partner"


# --------------------------------------------------------------------------- #
# parse_labeled_transcript
# --------------------------------------------------------------------------- #

def test_parse_aliases_and_continuation():
    text = ("You: I feel unheard\n"
            "Partner: I hear you\n"
            "and I want to help")
    turns = signals.parse_labeled_transcript(text, P1, P2)
    assert len(turns) == 2
    assert turns[0]["speaker"] == "You"
    assert turns[0]["text"] == "I feel unheard"
    # "Partner" aliases to P2, and the no-colon line folds into the prior turn.
    assert turns[1]["speaker"] == "Your partner"
    assert turns[1]["text"] == "I hear you and I want to help"


def test_parse_empty_returns_empty():
    assert signals.parse_labeled_transcript("", P1, P2) == []
    assert signals.parse_labeled_transcript(None, P1, P2) == []


def test_parse_unknown_name_kept_as_is():
    turns = signals.parse_labeled_transcript("Sam: hi there", P1, P2)
    assert turns[0]["speaker"] == "Sam"


# --------------------------------------------------------------------------- #
# speaker_label_map
# --------------------------------------------------------------------------- #

def test_label_map_orders_by_first_appearance():
    turns = [{"speaker": "B"}, {"speaker": "A"}, {"speaker": "B"}]
    label_map, order = signals.speaker_label_map(turns, P1, P2)
    assert label_map == {"B": P1, "A": P2}
    assert order == ["B", "A"]


def test_label_map_single_speaker():
    label_map, order = signals.speaker_label_map([{"speaker": "A"}], P1, P2)
    assert label_map == {"A": P1}


# --------------------------------------------------------------------------- #
# word_balance
# --------------------------------------------------------------------------- #

def test_word_balance_counts_words_per_speaker():
    turns = signals.parse_labeled_transcript(
        "You: I feel unheard\nPartner: I hear you and I want to help", P1, P2)
    wb = signals.word_balance(turns, P1, P2)
    # 3 words vs 8 words -> 27 / 73
    assert wb["participant_one_percent"] == 27
    assert wb["participant_two_percent"] == 73
    assert wb["label"] == "Mostly Your partner"


def test_word_balance_even_label():
    turns = signals.parse_labeled_transcript("You: a b c\nPartner: d e f", P1, P2)
    wb = signals.word_balance(turns, P1, P2)
    assert wb["participant_one_percent"] == 50
    assert wb["label"] == "Fairly even"


def test_word_balance_none_with_single_speaker():
    turns = signals.parse_labeled_transcript("You: only me talking here", P1, P2)
    assert signals.word_balance(turns, P1, P2) is None


# --------------------------------------------------------------------------- #
# interruptions
# --------------------------------------------------------------------------- #

def test_interruption_attributed_to_interrupter():
    spans = [
        {"speaker": "S1", "start_ms": 0, "end_ms": 1000},
        {"speaker": "S2", "start_ms": 800, "end_ms": 1500},  # starts while S1 talking
    ]
    res = signals.interruptions(spans, P1, P2)
    assert res["total"] == 1
    assert res["participant_one"] == 0   # S1 -> You
    assert res["participant_two"] == 1   # S2 -> Your partner (the interrupter)
    assert res["label"] == "Mostly from your partner"


def test_no_interruption_when_turns_dont_overlap():
    spans = [
        {"speaker": "S1", "start_ms": 0, "end_ms": 1000},
        {"speaker": "S2", "start_ms": 1200, "end_ms": 2000},
    ]
    res = signals.interruptions(spans, P1, P2)
    assert res["total"] == 0
    assert res["label"] == "No interruptions"


def test_interruptions_none_without_spans():
    assert signals.interruptions(None, P1, P2) is None
    assert signals.interruptions([{"speaker": "S1", "start_ms": 0, "end_ms": 9}], P1, P2) is None


# --------------------------------------------------------------------------- #
# ground_key_moments
# --------------------------------------------------------------------------- #

def test_ground_snaps_timestamp_and_speaker_to_turn():
    turns = [{"speaker": "S1", "start_ms": 5000, "end_ms": 6000,
              "text": "I can see why that felt lonely"}]
    label_map = {"S1": "You"}
    moments = [{"quote": "I can see why that felt lonely",
                "timestamp_ms": 0, "speaker": "?", "title": "x",
                "type": "positive", "explanation": "y"}]
    grounded = signals.ground_key_moments(moments, turns, label_map)
    assert grounded[0]["timestamp_ms"] == 5000
    assert grounded[0]["speaker"] == "You"


def test_ground_leaves_unmatched_quote_untouched():
    turns = [{"speaker": "S1", "start_ms": 5000, "end_ms": 6000, "text": "hello"}]
    moments = [{"quote": "totally different line", "timestamp_ms": 123, "speaker": "Z"}]
    grounded = signals.ground_key_moments(moments, turns, {"S1": "You"})
    assert grounded[0]["timestamp_ms"] == 123
    assert grounded[0]["speaker"] == "Z"


# --------------------------------------------------------------------------- #
# render_transcript
# --------------------------------------------------------------------------- #

def test_render_includes_timestamp_and_label():
    turns = [{"speaker": "S1", "start_ms": 5000, "end_ms": 6000, "text": "hi"}]
    rendered = signals.render_transcript(turns, {"S1": "You"})
    assert rendered == "[5000ms] You: hi"


def test_render_without_timestamps_or_labels():
    turns = [{"speaker": None, "start_ms": None, "end_ms": None, "text": "hi"}]
    assert signals.render_transcript(turns) == "hi"


# --------------------------------------------------------------------------- #
# standalone runner (so it works even without pytest installed)
# --------------------------------------------------------------------------- #

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

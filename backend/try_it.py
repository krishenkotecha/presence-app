"""
Test the conversation review on YOUR OWN transcript, using your local Ollama model.
No web server, no audio needed — calls the analysis engine directly with pasted text.

  # ensure Ollama is running and a model is pulled:  ollama pull qwen3
  python try_it.py                 # paste a transcript in the terminal
  python try_it.py mychat.txt      # or read it from a file

Forces the LOCAL (Ollama) backend so nothing leaves your machine.
Override the model with:  export RELINT_MODEL=qwen3:30b
"""

import os
import sys

os.environ.setdefault("RELINT_BACKEND", "local")

import httpx        # noqa: E402
import analysis     # noqa: E402

DEFAULT_P1_DEF = "Stay calm and feel understood before we try to solve anything."
DEFAULT_P2_DEF = "Feel heard first, then leave with a clear plan we both believe in."


def ollama_root():
    return analysis.LOCAL_BASE_URL.rsplit("/v1", 1)[0]


def check_server():
    if analysis.BACKEND != "local":
        return
    root = ollama_root()
    try:
        tags = httpx.get(f"{root}/api/tags", timeout=3.0).json().get("models", [])
    except Exception:
        print(f"\n[!] Can't reach a local LLM server at {root}.")
        print("    Start Ollama and pull a model, then re-run:\n        ollama pull qwen3")
        print("    (Ollama serves automatically at http://localhost:11434)\n")
        sys.exit(1)
    names = [m.get("name", "") for m in tags]
    print(f"  server: {root}  |  model: {analysis.MODEL}")
    if names and not any(n == analysis.MODEL or n.startswith(analysis.MODEL + ":") for n in names):
        print(f"  [!] '{analysis.MODEL}' not pulled. Available: {', '.join(names) or '(none)'}")
        print(f"      Pull it:  ollama pull {analysis.MODEL}\n")


def read_transcript():
    if len(sys.argv) > 1:
        path = sys.argv[1]
        if not os.path.exists(path):
            print(f"[!] file not found: {path}")
            sys.exit(1)
        return open(path).read().strip()
    print("\nPaste the transcript (one line per turn, name first).")
    print("When done: Ctrl-D (Mac/Linux) or Ctrl-Z then Enter (Windows).\n")
    return sys.stdin.read().strip()


def print_review(model, p):
    line = "-" * 66
    print(f"\n{line}\nCONVERSATION REVIEW  (via {model}, confidence={p.get('confidence')})\n{line}")
    print(f"\nHEADLINE\n  {p['summary']['headline']}")
    print(f"SUB\n  {p['summary']['subheadline']}")
    print(f"\nSHARED SUCCESS: {p.get('shared_success', '')}")
    m = p["metrics"]
    print("\nMETRICS  (best-effort estimates from text)")
    print(f"  word balance : {m['word_balance']['participant_one_percent']}/"
          f"{m['word_balance']['participant_two_percent']}  ({m['word_balance']['label']})")
    print(f"  interruptions: {m['interruptions']['total']}  ({m['interruptions']['label']})")
    print(f"  connection   : {m['connection_score']['score']}  ({m['connection_score']['delta_label']})")
    print(f"  repairs      : {m['repair_attempts']['total']}  ({m['repair_attempts']['label']})")
    print("\nKEY MOMENTS")
    for km in p["key_moments"]:
        print(f"  [{km['type']}] {km['title']} — \"{km['quote']}\" ({km['speaker']})")
    print("\nUNMET NEEDS")
    for n in p["unmet_needs"]:
        print(f"  - {n['person']}: {n['need']}")
    print("\nNEXT TIME")
    for n in p["next_time"]:
        print(f"  - {n['person']}: {n['try']}")
    print()


def main():
    print(f"\nbackend: {analysis.current_backend()}")
    check_server()

    p1 = input("Participant one label [You]: ").strip() or "You"
    p2 = input("Participant two label [Your partner]: ").strip() or "Your partner"
    p1_def = input(f"{p1}'s success definition:\n  [{DEFAULT_P1_DEF}]\n  > ").strip() or DEFAULT_P1_DEF
    p2_def = input(f"{p2}'s success definition:\n  [{DEFAULT_P2_DEF}]\n  > ").strip() or DEFAULT_P2_DEF

    transcript = read_transcript()
    if not transcript:
        print("[!] no transcript provided.")
        sys.exit(1)

    meta = {"p1_label": p1, "p2_label": p2, "p1_def": p1_def, "p2_def": p2_def, "duration": 0}
    print("\nanalyzing... (first call may be slow while the model loads)")

    import signals
    turns = signals.parse_labeled_transcript(transcript, p1, p2)
    label_map, _ = signals.speaker_label_map(turns, p1, p2)
    llm_transcript = signals.render_transcript(turns, label_map) if turns else transcript

    try:
        body = analysis.generate_review(meta, llm_transcript)
    except Exception as e:  # noqa: BLE001
        print(f"\n[!] analysis failed: {e}")
        sys.exit(1)

    # Computed word_balance from the labels (interruptions need audio timing).
    wb = signals.word_balance(turns, p1, p2)
    if wb:
        body["metrics"]["word_balance"] = wb
    body["key_moments"] = signals.ground_key_moments(body.get("key_moments", []), turns, label_map)
    body["shared_success"] = body.get("shared_success", "")
    print_review(analysis.MODEL, body)


if __name__ == "__main__":
    main()

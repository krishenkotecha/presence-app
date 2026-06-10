"""
Discovery resources — a curated catalog (videos, talks, articles, exercises) that aids
understanding of self and others, plus topic-based contextual matching.

The seed below is a STARTER set: `url` points to a search for the exact title+creator so
the links always resolve, and `verified=0` flags that the team should replace each with the
canonical URL during editorial curation. The durable value here is the topic-matching engine,
which surfaces the right resource for what a user keeps reaching for — not the seed itself.

`axis` = whether the resource mostly helps understanding of "self", "other", or "both".
"""

import re
from urllib.parse import quote_plus


def _search_url(title, creator, video=False):
    q = quote_plus(f"{creator} {title}".strip())
    base = "https://www.youtube.com/results?search_query=" if video else "https://www.google.com/search?q="
    return base + q


def _r(title, creator, kind, topics, axis, description):
    return {
        "title": title, "creator": creator, "kind": kind,
        "topics": topics, "axis": axis, "description": description,
        "url": _search_url(title, creator, video=kind in ("video", "talk")),
        "verified": 0,
    }


# Starter catalog — well-known, reputable sources spanning the topic vocabulary.
SEED = [
    _r("Brené Brown on Empathy (RSA Short)", "Brené Brown", "video",
       ["empathy", "listening", "connection"], "both",
       "A 3-minute classic on what empathy actually is — and how it differs from sympathy."),
    _r("The secret to desire in a long-term relationship (TED)", "Esther Perel", "talk",
       ["desire", "meaning", "autonomy"], "other",
       "How closeness and desire pull in different directions, and what keeps a relationship alive."),
    _r("The Four Horsemen: criticism, contempt, defensiveness, stonewalling", "The Gottman Institute", "article",
       ["conflict", "criticism", "defensiveness", "repair"], "both",
       "The four communication patterns that most predict disconnection — and their antidotes."),
    _r("Making and receiving repair attempts", "The Gottman Institute", "article",
       ["repair", "conflict", "connection"], "both",
       "How small repair attempts rescue a hard conversation, and how to receive one."),
    _r("Bids for connection: the building blocks of intimacy", "The Gottman Institute", "article",
       ["connection", "bids", "attention"], "both",
       "The tiny everyday bids for attention that, turned toward, build closeness over time."),
    _r("Nonviolent Communication: an introduction", "Marshall Rosenberg", "talk",
       ["needs", "feelings", "listening"], "both",
       "Translating judgments and demands into the feelings and unmet needs underneath them."),
    _r("Feelings & needs inventory", "Center for Nonviolent Communication", "exercise",
       ["needs", "feelings", "self-awareness"], "self",
       "A reference list to help name what you're actually feeling and needing in a moment."),
    _r("Hold Me Tight: the pursue–withdraw cycle", "Sue Johnson", "article",
       ["attachment", "pursue-withdraw", "needs"], "other",
       "How attachment fears drive the chase-and-retreat loop, and how to step out of it."),
    _r("Self-Compassion: the three elements", "Kristin Neff", "video",
       ["self-compassion", "self-awareness", "regulation"], "self",
       "Treating yourself with the kindness you'd offer a friend — the ground of steadier relating."),
    _r("RAIN: a practice for difficult emotions", "Tara Brach", "exercise",
       ["regulation", "self-awareness"], "self",
       "Recognize, Allow, Investigate, Nurture — a short practice for staying regulated under stress."),
]


# topic -> keywords that imply it (matched against a user's recent needs/headlines text).
TOPIC_KEYWORDS = {
    "needs": ["need", "unmet", "reassur", "understood", "heard", "seen", "valued", "appreciat"],
    "listening": ["listen", "hear", "reflect", "interrupt", "talk over"],
    "repair": ["repair", "reconnect", "apolog", "sorry", "make up", "reset"],
    "conflict": ["fight", "argu", "tension", "conflict", "blame", "criticism", "defensive"],
    "attachment": ["alone", "abandon", "distance", "withdraw", "pursue", "anxious", "clingy", "lonely"],
    "self-awareness": ["my reaction", "i felt", "i got", "trigger", "pattern", "myself", "overwhelm"],
    "regulation": ["calm", "overwhelm", "flooded", "escalat", "breathe", "reset", "sharp"],
    "connection": ["connect", "close", "lonely", "unseen", "distant", "bid"],
    "desire": ["desire", "spark", "bored", "routine", "passion"],
    "meaning": ["meaning", "purpose", "point", "why are we"],
    "empathy": ["empathy", "their side", "perspective", "understand them"],
    "self-compassion": ["hard on myself", "guilt", "shame", "not good enough", "self-critical"],
}


def topics_for_text(text):
    """Infer which resource topics a chunk of reflection text points at."""
    t = (text or "").lower()
    found = set()
    for topic, kws in TOPIC_KEYWORDS.items():
        if any(k in t for k in kws):
            found.add(topic)
    return found


def rank(catalog, wanted_topics, axis=None, limit=5):
    """Score catalog rows by topic overlap with what the user keeps reaching for."""
    wanted = set(wanted_topics or [])
    scored = []
    for r in catalog:
        rtopics = set(r.get("topics", []))
        overlap = len(rtopics & wanted)
        if axis and r.get("axis") not in (axis, "both"):
            continue
        scored.append((overlap, r))
    # When nothing matches, fall back to a gentle starter set (stable order).
    scored.sort(key=lambda x: (-x[0], x[1].get("title", "")))
    if wanted and all(s == 0 for s, _ in scored):
        scored = [(0, r) for r in catalog if (not axis or r.get("axis") in (axis, "both"))]
    return [r for _, r in scored[:limit]]

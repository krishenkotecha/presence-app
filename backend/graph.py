"""
Context graph — an internal (not user-facing) knowledge graph of a person's social life.

Think of it as a private Wikipedia for one person: every relationship is an article, every
conversation links to the relationship it's about and to the themes it touches, and themes are
hub articles that link conversations *across* relationships over time. The ego ("self") is the
hub all relationships connect to.

  self ──part_of── relationship ──about── conversation ──touches── theme
                                                              (themes recur across relationships)

This representation is projected into a human-readable "baseball card / scouting report":
strengths ("good at X") and growth areas ("needs work on Y"), derived from the graph's
recurring, cross-relationship themes plus behavioural outcomes from the event log.

Stored as a lightweight property graph in SQLite (graph_nodes + graph_edges). Node ids are
deterministic natural keys so ingestion is idempotent.
"""

import uuid
from collections import defaultdict
from datetime import datetime, timezone

import resources


def _now():
    return datetime.now(timezone.utc).isoformat()


def _facet_list(d):
    return [{"label": k, "count": v} for k, v in sorted(d.items(), key=lambda x: -x[1])]


# theme -> how a recurring growth area is phrased on the card
GROWTH = {
    "needs": "Naming what you need before the conversation drifts to logistics",
    "conflict": "Staying out of criticism and defensiveness when it heats up",
    "defensiveness": "Catching the first defensive turn",
    "attachment": "Noticing the pursue–withdraw pull",
    "pursue-withdraw": "Noticing the pursue–withdraw pull",
    "regulation": "Staying regulated when you feel flooded",
    "listening": "Reflecting back what you heard before responding",
    "connection": "Turning toward bids instead of away",
    "self-awareness": "Pausing to notice your own reaction first",
    "self-compassion": "Easing up on the self-criticism",
    "repair": "Initiating repair sooner",
    "empathy": "Sitting with their perspective before solving",
    "desire": "Keeping curiosity alive in the routine",
    "meaning": "Reconnecting to what the relationship is for",
    "feelings": "Naming the feeling, not just the facts",
    "bids": "Turning toward small bids for connection",
}

# event signal -> a strength on the card (kind, positive-values, label)
STRENGTH_SIGNALS = [
    ("tried_it", {"yes"}, "Acts on what they learn"),
    ("went_better", {"yes"}, "Their follow-through tends to land"),
    ("rings_true", {"yes"}, "Self-aware — recognizes their own patterns"),
    ("response_use", {"own_words"}, "Speaks in their own voice, not scripts"),
    ("had_real_conversation", {"yes"}, "Takes it back to the real relationship"),
]

# WHY — the underlying need/reason a conversation is really about.
NEED_KEYWORDS = {
    "to feel heard": ["unseen", "unheard", "not listening", "doesn't hear", "ignored", "talk over"],
    "to feel valued": ["valued", "appreciat", "effort", "taken for granted", "unappreciated"],
    "reassurance": ["reassur", "alone", "abandon", "insecure", "am i enough"],
    "autonomy": ["space", "controlled", "pressured", "smothered", "my own", "independence"],
    "fairness": ["unfair", "fair", "equal", "share the load", "carrying it all", "chores"],
    "security": ["safe", "security", "commit", "stability", "uncertain about us"],
    "respect": ["respect", "dismiss", "belittl", "talked down"],
    "connection": ["close", "connect", "distant", "drift", "lonely"],
}

# HOW — the manner / dynamics of the conversation, with valence.
MANNER_KEYWORDS = {
    "defensiveness": ["defensive", "that's not what i", "excuse", "justify", "wasn't my fault"],
    "criticism": ["criticiz", "blame", "you always", "you never", "attacked"],
    "withdrawal": ["shut down", "withdrew", "stonewall", "silent", "walked away", "went quiet"],
    "reflecting": ["reflected", "listened", "heard them", "paraphrase", "repeated back", "mirrored"],
    "soft start-up": ["gently", "calmly", "eased in", "without blaming", "soft start"],
    "repair": ["apolog", "repair", "made up", "took responsibility", "reconnect"],
    "naming feelings": ["named the feeling", "how i felt", "shared my feeling", "was vulnerable"],
}
MANNER_VALENCE = {
    "defensiveness": "destructive", "criticism": "destructive", "withdrawal": "destructive",
    "reflecting": "constructive", "soft start-up": "constructive",
    "repair": "constructive", "naming feelings": "constructive",
}
MANNER_STRENGTH = {
    "reflecting": "Reflects back what they heard", "repair": "Initiates repair",
    "soft start-up": "Opens hard talks gently", "naming feelings": "Names feelings, not just facts",
}
MANNER_GROWTH = {
    "defensiveness": "Catching defensiveness in the moment",
    "criticism": "Swapping criticism for a soft start-up",
    "withdrawal": "Staying present instead of withdrawing",
}

# How a PARTNER's manner reads on their mirror card (third-person).
PARTNER_STRENGTH = {
    "reflecting": "Listens and reflects back", "repair": "Repairs after a rupture",
    "soft start-up": "Opens hard things gently", "naming feelings": "Names how they feel",
}
PARTNER_WATCH = {
    "defensiveness": "Gets defensive under stress", "criticism": "Can slip into criticism",
    "withdrawal": "Tends to withdraw / go quiet",
}


def _match(text, lexicon):
    t = (text or "").lower()
    return {label for label, kws in lexicon.items() if any(k in t for k in kws)}


def _needs_for_text(text):
    return _match(text, NEED_KEYWORDS)


def _manners_for_text(text):
    return _match(text, MANNER_KEYWORDS)


# --------------------------------------------------------------------------- #
# Ingestion (idempotent upserts)
# --------------------------------------------------------------------------- #

def _node_id(user_id, kind, key):
    return f"{user_id}|{kind}|{str(key).strip().lower()}"


def _upsert_node(conn, node_id, user_id, kind, label, occurred_at=None):
    conn.execute(
        "INSERT OR IGNORE INTO graph_nodes (node_id,user_id,type,label,created_at,occurred_at) "
        "VALUES (?,?,?,?,?,?)",
        (node_id, user_id, kind, label, _now(), occurred_at),
    )


def _add_edge(conn, user_id, src, dst, etype, perspective=None):
    eid = f"{src}>{etype}:{perspective or ''}>{dst}"
    conn.execute(
        "INSERT OR IGNORE INTO graph_edges (edge_id,user_id,src_id,dst_id,type,perspective,created_at) "
        "VALUES (?,?,?,?,?,?,?)",
        (eid, user_id, src, dst, etype, perspective, _now()),
    )


def ingest(conn, user_id, conversation_id, relationship_label, text, themes=None,
           occurred_at=None, location=None, manner_text=None, need_text=None,
           self_need_text=None, other_manner_text=None, continues=None):
    """Add one conversation to the person's context graph — the full who/what/where/when/why/how.

    who   = relationship (other) + self        what  = themes
    where = location                            when  = occurred_at
    why   = needs (default perspective: the *other's* need, from need_text)
    how   = manners (default perspective: how *you* showed up, from manner_text/text)
    """
    rel = (relationship_label or "someone").strip().lower() or "someone"
    themes = themes if themes is not None else sorted(resources.topics_for_text(text or ""))

    self_id = _node_id(user_id, "self", "me")
    rel_id = _node_id(user_id, "relationship", rel)
    conv_id = _node_id(user_id, "conversation", conversation_id)

    _upsert_node(conn, self_id, user_id, "self", "me")
    _upsert_node(conn, rel_id, user_id, "relationship", rel)
    _upsert_node(conn, conv_id, user_id, "conversation", str(conversation_id),
                 occurred_at=occurred_at or _now())

    _add_edge(conn, user_id, rel_id, self_id, "part_of")
    _add_edge(conn, user_id, conv_id, rel_id, "about")
    for th in themes:
        th_id = _node_id(user_id, "theme", th)
        _upsert_node(conn, th_id, user_id, "theme", th)
        _add_edge(conn, user_id, conv_id, th_id, "touches")

    place = None
    if location and location.strip():
        place = location.strip().lower()
        place_id = _node_id(user_id, "place", place)
        _upsert_node(conn, place_id, user_id, "place", place)
        _add_edge(conn, user_id, conv_id, place_id, "at")

    # WHY — the need underneath. The other person's need (default) ...
    needs = sorted(_needs_for_text(need_text if need_text is not None else text))
    for need in needs:
        nid = _node_id(user_id, "need", need)
        _upsert_node(conn, nid, user_id, "need", need)
        _add_edge(conn, user_id, conv_id, nid, "why", perspective="other")
    # ... and your own need (internal why), when provided
    self_needs = sorted(_needs_for_text(self_need_text or ""))
    for need in self_needs:
        nid = _node_id(user_id, "need", need)
        _upsert_node(conn, nid, user_id, "need", need)
        _add_edge(conn, user_id, conv_id, nid, "why", perspective="self")

    # HOW — the manner you showed up in (default: self)
    manners = sorted(_manners_for_text(manner_text if manner_text is not None else text))
    for manner in manners:
        mid = _node_id(user_id, "manner", manner)
        _upsert_node(conn, mid, user_id, "manner", manner)
        _add_edge(conn, user_id, conv_id, mid, "how", perspective="self")

    # BETWEEN conversations — this one continues an earlier one (same thread of relating)
    if continues:
        prior_id = _node_id(user_id, "conversation", continues)
        _upsert_node(conn, prior_id, user_id, "conversation", str(continues))
        _add_edge(conn, user_id, conv_id, prior_id, "continues")

    return {"relationship": rel, "themes": themes, "place": place,
            "needs": needs, "self_needs": self_needs, "manners": manners,
            "conversation_node": conv_id}


# --------------------------------------------------------------------------- #
# Read helpers
# --------------------------------------------------------------------------- #

def _load(conn, user_id):
    nodes = conn.execute(
        "SELECT node_id, type, label FROM graph_nodes WHERE user_id=?", (user_id,)).fetchall()
    edges = conn.execute(
        "SELECT src_id, dst_id, type, perspective FROM graph_edges WHERE user_id=?", (user_id,)).fetchall()
    label = {n["node_id"]: n["label"] for n in nodes}
    about = {}            # conv_id -> rel_id
    conv_themes = defaultdict(list)   # conv_id -> [theme_id]
    for e in edges:
        if e["type"] == "about":
            about[e["src_id"]] = e["dst_id"]
        elif e["type"] == "touches":
            conv_themes[e["src_id"]].append(e["dst_id"])
    return nodes, edges, label, about, conv_themes


def dump(conn, user_id):
    nodes, edges, _, _, _ = _load(conn, user_id)
    return {"nodes": [dict(n) for n in nodes], "edges": [dict(e) for e in edges]}


def relationship_article(conn, user_id, rel_label):
    """The 'Wikipedia article' for one relationship: its conversations and recurring themes."""
    rel = (rel_label or "").strip().lower()
    rel_id = _node_id(user_id, "relationship", rel)
    _, _, label, about, conv_themes = _load(conn, user_id)
    convs = [c for c, r in about.items() if r == rel_id]
    theme_count = defaultdict(int)
    for c in convs:
        for th in conv_themes.get(c, []):
            theme_count[label[th]] += 1
    top = sorted(theme_count.items(), key=lambda x: -x[1])
    return {
        "relationship": rel,
        "conversation_count": len(convs),
        "themes": [{"theme": t, "count": n} for t, n in top],
    }


# --------------------------------------------------------------------------- #
# Who / what / where / when / why / how
# --------------------------------------------------------------------------- #

def conversation_facets(conn, user_id, conversation_id):
    """The full 5W1H of a single conversation."""
    conv_id = _node_id(user_id, "conversation", conversation_id)
    nmeta = {n["node_id"]: (n["type"], n["label"]) for n in conn.execute(
        "SELECT node_id,type,label FROM graph_nodes WHERE user_id=?", (user_id,))}
    occ = conn.execute("SELECT occurred_at FROM graph_nodes WHERE node_id=?", (conv_id,)).fetchone()
    out = {"conversation_id": conversation_id,
           "who": [], "what": [], "where": None,
           "when": occ["occurred_at"] if occ else None,
           "why": {"other": [], "self": []}, "how": {"self": [], "other": []}}
    for e in conn.execute(
            "SELECT dst_id,type,perspective FROM graph_edges WHERE user_id=? AND src_id=?",
            (user_id, conv_id)):
        t, lbl = nmeta.get(e["dst_id"], (None, None))
        if t == "relationship":
            out["who"].append(lbl)
        elif t == "theme":
            out["what"].append(lbl)
        elif t == "place":
            out["where"] = lbl
        elif t == "need":
            out["why"].setdefault(e["perspective"] or "other", []).append(lbl)
        elif t == "manner":
            out["how"].setdefault(e["perspective"] or "self", []).append(lbl)
    out["who"].append("self")   # always present internally
    return out


# --------------------------------------------------------------------------- #
# WITHIN a conversation — moment-by-moment 5W1H (turns / shifts)
# --------------------------------------------------------------------------- #

def add_moment(conn, user_id, conversation_id, text, seq=0, offset_ms=None,
               speaker="you", valence="neutral"):
    """A moment/turn inside a conversation — its own who/what/why/how at a point in time.
    The moment's facets roll up into the conversation graph, with perspective from the speaker
    (you → self/internal, them → other/between-people), so internal & report views reflect them."""
    mid = uuid.uuid4().hex[:12]
    conn.execute(
        "INSERT INTO moments (moment_id,user_id,conversation_id,seq,offset_ms,speaker,text,valence,created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        (mid, user_id, conversation_id, seq, offset_ms, speaker, text, valence, _now()),
    )

    themes = sorted(resources.topics_for_text(text))
    needs = sorted(_needs_for_text(text))
    manners = sorted(_manners_for_text(text))

    # roll the moment's facets up into the conversation graph
    persp = "self" if str(speaker).strip().lower() in ("you", "me", "self", "i") else "other"
    conv_id = _node_id(user_id, "conversation", conversation_id)
    _upsert_node(conn, conv_id, user_id, "conversation", str(conversation_id))
    for th in themes:
        th_id = _node_id(user_id, "theme", th)
        _upsert_node(conn, th_id, user_id, "theme", th)
        _add_edge(conn, user_id, conv_id, th_id, "touches")
    for need in needs:
        nid = _node_id(user_id, "need", need)
        _upsert_node(conn, nid, user_id, "need", need)
        _add_edge(conn, user_id, conv_id, nid, "why", perspective=persp)
    for manner in manners:
        m_id = _node_id(user_id, "manner", manner)
        _upsert_node(conn, m_id, user_id, "manner", manner)
        _add_edge(conn, user_id, conv_id, m_id, "how", perspective=persp)

    return {"moment_id": mid, "what": themes, "why": needs, "how": manners, "perspective": persp}


def conversation_moments(conn, user_id, conversation_id):
    """The within-conversation timeline: each moment's 5W1H. Where/when come from the
    conversation itself; who/what/why/how are per moment."""
    cf = conversation_facets(conn, user_id, conversation_id)
    rows = conn.execute(
        "SELECT seq,offset_ms,speaker,text,valence FROM moments "
        "WHERE user_id=? AND conversation_id=? ORDER BY seq ASC, created_at ASC",
        (user_id, conversation_id)).fetchall()
    moments = []
    for r in rows:
        moments.append({
            "seq": r["seq"],
            "who": r["speaker"],                 # who spoke
            "when": r["offset_ms"],              # when within the conversation
            "what": sorted(resources.topics_for_text(r["text"])),
            "why": sorted(_needs_for_text(r["text"])),
            "how": sorted(_manners_for_text(r["text"])),
            "valence": r["valence"],
            "text": r["text"],
        })
    return {"conversation_id": conversation_id, "where": cf["where"], "when": cf["when"],
            "who": cf["who"], "moments": moments}


# --------------------------------------------------------------------------- #
# BETWEEN conversations — continuation + shared-facet links
# --------------------------------------------------------------------------- #

def conversation_links(conn, user_id, conversation_id):
    """How a conversation connects to others: continuation chain + others that share who/what/
    where/why/how."""
    conv_id = _node_id(user_id, "conversation", conversation_id)
    nmeta = {n["node_id"]: (n["type"], n["label"]) for n in conn.execute(
        "SELECT node_id,type,label FROM graph_nodes WHERE user_id=?", (user_id,))}
    facets = defaultdict(set)            # conversation node -> set(facet node ids)
    continues_out, continued_by = [], []
    for e in conn.execute(
            "SELECT src_id,dst_id,type FROM graph_edges WHERE user_id=? "
            "AND type IN ('touches','why','how','at','about','continues')", (user_id,)):
        if e["type"] == "continues":
            if e["src_id"] == conv_id:
                continues_out.append(nmeta.get(e["dst_id"], (None, e["dst_id"]))[1])
            if e["dst_id"] == conv_id:
                continued_by.append(nmeta.get(e["src_id"], (None, e["src_id"]))[1])
        elif nmeta.get(e["src_id"], (None,))[0] == "conversation":
            facets[e["src_id"]].add(e["dst_id"])

    target = facets.get(conv_id, set())
    related = []
    for c, fset in facets.items():
        if c == conv_id:
            continue
        shared = target & fset
        if shared:
            related.append({
                "conversation": nmeta.get(c, (None, c))[1],
                "shares": sorted(nmeta.get(s, (None, s))[1] for s in shared),
            })
    related.sort(key=lambda x: -len(x["shares"]))
    return {"conversation_id": conversation_id,
            "continues": continues_out, "continued_by": continued_by,
            "related": related[:10]}


# --------------------------------------------------------------------------- #
# INTERNAL — the intrapersonal map (how you show up, what you need)
# --------------------------------------------------------------------------- #

def internal_map(conn, user_id):
    needs, manners = _facet_profiles(conn, user_id)
    constructive = {k: v for k, v in manners["self"].items() if MANNER_VALENCE.get(k) == "constructive"}
    destructive = {k: v for k, v in manners["self"].items() if MANNER_VALENCE.get(k) == "destructive"}
    pattern = None
    if destructive:
        top = max(destructive.items(), key=lambda x: x[1])
        pattern = MANNER_GROWTH.get(top[0], f"a tendency toward {top[0]}")
    return {
        "user_id": user_id,
        "how_you_show_up": {"constructive": _facet_list(constructive),
                            "destructive": _facet_list(destructive)},
        "your_needs": _facet_list(needs["self"]),
        "recurring_pattern": pattern,
    }


def _facet_profiles(conn, user_id):
    """Aggregate why (needs) and how (manners) across conversations, split by perspective —
    'self' is the internal lens, 'other' is between-people."""
    nmeta = {n["node_id"]: (n["type"], n["label"]) for n in conn.execute(
        "SELECT node_id,type,label FROM graph_nodes WHERE user_id=?", (user_id,))}
    needs = {"self": defaultdict(int), "other": defaultdict(int)}
    manners = {"self": defaultdict(int), "other": defaultdict(int)}
    for e in conn.execute(
            "SELECT dst_id,type,perspective FROM graph_edges WHERE user_id=? AND type IN ('why','how')",
            (user_id,)):
        t, lbl = nmeta.get(e["dst_id"], (None, None))
        persp = e["perspective"] or ("other" if e["type"] == "why" else "self")
        if t == "need":
            needs[persp][lbl] += 1
        elif t == "manner":
            manners[persp][lbl] += 1
    return needs, manners


# --------------------------------------------------------------------------- #
# Spatio-temporal layer — cadence, connection points, nudge points
# --------------------------------------------------------------------------- #

DRIFT_DAYS = 60          # ~2 months without contact -> a reconnect nudge
RECURRING_MIN = 2        # a theme seen this many times in a relationship -> worth naming


def _parse(iso):
    if not iso:
        return None
    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except Exception:
        return None


def _ago(dt, ref):
    """Human relative time: 'today', '5 days ago', '3 weeks ago', '~8 months ago'."""
    if dt is None:
        return "at some point"
    d = (ref - dt).days
    if d <= 0:
        return "today"
    if d < 14:
        return f"{d} day{'s' if d != 1 else ''} ago"
    if d < 60:
        return f"{d // 7} weeks ago"
    if d < 365:
        m = max(1, round(d / 30))
        return f"~{m} month{'s' if m != 1 else ''} ago"
    y = round(d / 365, 1)
    return f"~{y} years ago"


def _temporal(conn, user_id, ref=None):
    """Per-relationship conversation timelines (parsed datetimes) + connection-point set."""
    ref = ref or datetime.now(timezone.utc)
    nodes = conn.execute(
        "SELECT node_id,label,occurred_at,created_at FROM graph_nodes "
        "WHERE user_id=? AND type='conversation'", (user_id,)).fetchall()
    conv_time, conv_label = {}, {}
    for n in nodes:
        conv_time[n["node_id"]] = _parse(n["occurred_at"]) or _parse(n["created_at"])
        conv_label[n["node_id"]] = n["label"]          # == conversation_id / reflection_id
    about = {e["src_id"]: e["dst_id"] for e in conn.execute(
        "SELECT src_id,dst_id FROM graph_edges WHERE user_id=? AND type='about'", (user_id,))}
    rlabel = {n["node_id"]: n["label"] for n in conn.execute(
        "SELECT node_id,label FROM graph_nodes WHERE user_id=? AND type='relationship'", (user_id,))}
    # connection points: conversations that the user reported went better
    conn_set = {r["reflection_id"] for r in conn.execute(
        "SELECT DISTINCT reflection_id FROM events WHERE user_id=? AND kind='went_better' AND value='yes'",
        (user_id,)) if r["reflection_id"]}

    per_rel = defaultdict(list)
    for cnode, rel in about.items():
        per_rel[rel].append({
            "when": conv_time.get(cnode),
            "conversation_id": conv_label.get(cnode),
            "connection_point": conv_label.get(cnode) in conn_set,
        })
    for rel in per_rel:
        per_rel[rel].sort(key=lambda x: (x["when"] or ref))
    return ref, per_rel, rlabel


def _rel_stats(entries, ref):
    times = [e["when"] for e in entries if e["when"]]
    if not times:
        return {}
    gaps = [(times[i] - times[i - 1]).days for i in range(1, len(times))]
    avg_gap = round(sum(gaps) / len(gaps)) if gaps else None
    return {
        "first_contact": times[0].isoformat(),
        "last_contact": times[-1].isoformat(),
        "days_since_last": (ref - times[-1]).days,
        "conversation_count": len(times),
        "cadence_days": avg_gap,
        "recent_gap_days": gaps[-1] if gaps else None,
    }


def timeline(conn, user_id, rel_label, ref=None):
    """The relationship's conversation history over time — 'I talked with X ~8 months ago, then
    ~2 months ago' — with gaps and connection points."""
    ref = ref or datetime.now(timezone.utc)
    rel = (rel_label or "").strip().lower()
    rel_id = _node_id(user_id, "relationship", rel)
    _, per_rel, _ = _temporal(conn, user_id, ref)
    entries = per_rel.get(rel_id, [])
    out, prev = [], None
    for e in entries:
        out.append({
            "occurred_at": e["when"].isoformat() if e["when"] else None,
            "ago": _ago(e["when"], ref),
            "gap_days_since_prev": (e["when"] - prev).days if (e["when"] and prev) else None,
            "connection_point": e["connection_point"],
        })
        prev = e["when"] or prev
    return {"relationship": rel, **_rel_stats(entries, ref), "entries": out}


# --------------------------------------------------------------------------- #
# Spatial layer — where conversations happen
# --------------------------------------------------------------------------- #

HARD_THEMES = {"conflict", "defensiveness", "regulation"}


def _spatial(conn, user_id):
    at = {e["src_id"]: e["dst_id"] for e in conn.execute(
        "SELECT src_id,dst_id FROM graph_edges WHERE user_id=? AND type='at'", (user_id,))}
    plabel = {n["node_id"]: n["label"] for n in conn.execute(
        "SELECT node_id,label FROM graph_nodes WHERE user_id=? AND type='place'", (user_id,))}
    return at, plabel


def _conv_place_map(conn, user_id):
    """conversation_id (label) -> place label."""
    conv_label = {n["node_id"]: n["label"] for n in conn.execute(
        "SELECT node_id,label FROM graph_nodes WHERE user_id=? AND type='conversation'", (user_id,))}
    at, plabel = _spatial(conn, user_id)
    return {conv_label.get(cnode): plabel.get(pnode) for cnode, pnode in at.items()}


def _place_stats(conn, user_id):
    """Per-place: how many conversations, how often they went well, top themes, who with."""
    _, _, label, about, conv_themes = _load(conn, user_id)
    rlabel = {n["node_id"]: n["label"] for n in conn.execute(
        "SELECT node_id,label FROM graph_nodes WHERE user_id=? AND type='relationship'", (user_id,))}
    conv_label = {n["node_id"]: n["label"] for n in conn.execute(
        "SELECT node_id,label FROM graph_nodes WHERE user_id=? AND type='conversation'", (user_id,))}
    at, plabel = _spatial(conn, user_id)
    conn_set = {r["reflection_id"] for r in conn.execute(
        "SELECT DISTINCT reflection_id FROM events WHERE user_id=? AND kind='went_better' AND value='yes'",
        (user_id,)) if r["reflection_id"]}

    agg = {}
    for cnode, pnode in at.items():
        p = plabel.get(pnode, pnode)
        d = agg.setdefault(p, {"conversations": 0, "connection": 0,
                               "_themes": defaultdict(int), "_rels": set()})
        d["conversations"] += 1
        if conv_label.get(cnode) in conn_set:
            d["connection"] += 1
        for th in conv_themes.get(cnode, []):
            d["_themes"][label[th]] += 1
        rel = about.get(cnode)
        if rel:
            d["_rels"].add(rlabel.get(rel, rel))

    out = []
    for p, d in agg.items():
        top = [t for t, _ in sorted(d["_themes"].items(), key=lambda x: -x[1])[:3]]
        out.append({
            "place": p,
            "conversations": d["conversations"],
            "connection_rate": round(d["connection"] / d["conversations"], 2) if d["conversations"] else 0.0,
            "top_themes": top,
            "relationships": sorted(d["_rels"]),
        })
    out.sort(key=lambda x: -x["conversations"])
    return out


def places(conn, user_id):
    return {"user_id": user_id, "places": _place_stats(conn, user_id)}


# --------------------------------------------------------------------------- #
# Nudges (temporal + spatial)
# --------------------------------------------------------------------------- #

def nudges(conn, user_id, ref=None):
    """Where to attend: drifting relationships, dropping cadence, recurring themes, and the
    settings (places) that help or hurt — plus connection points worth reinforcing."""
    ref = ref or datetime.now(timezone.utc)
    _, per_rel, rlabel = _temporal(conn, user_id, ref)
    _, _, label, about, conv_themes = _load(conn, user_id)
    cmap = _conv_place_map(conn, user_id)

    items, connection_points = [], []
    for rel_id, entries in per_rel.items():
        rel = rlabel.get(rel_id, rel_id)
        stats = _rel_stats(entries, ref)
        if not stats:
            continue
        last = _parse(stats["last_contact"])
        dsl = stats["days_since_last"]

        # 1) drift / reconnect
        if dsl >= DRIFT_DAYS:
            since = _ago(last, ref).replace(" ago", "")
            items.append({
                "type": "reconnect", "relationship": rel,
                "message": f"It's been {since} since you talked with {rel} — worth reaching out?",
                "evidence": f"{dsl} days since last conversation",
            })
        # 2) cadence dropping (talking less than you used to)
        elif stats.get("cadence_days") and stats.get("recent_gap_days") \
                and stats["recent_gap_days"] > 2 * max(1, stats["cadence_days"]):
            items.append({
                "type": "cadence", "relationship": rel,
                "message": f"You're talking with {rel} less than you used to.",
                "evidence": f"recent gap {stats['recent_gap_days']}d vs usual ~{stats['cadence_days']}d",
            })

        # 3) recurring unresolved theme in this relationship
        rel_convs = [c for c, r in about.items() if r == rel_id]
        theme_count = defaultdict(int)
        for c in rel_convs:
            for th in conv_themes.get(c, []):
                theme_count[label[th]] += 1
        for th, cnt in sorted(theme_count.items(), key=lambda x: -x[1]):
            if cnt >= RECURRING_MIN:
                items.append({
                    "type": "recurring", "relationship": rel,
                    "message": f"The '{th}' pattern with {rel} keeps coming up — might be worth naming directly.",
                    "evidence": f"appeared in {cnt} conversations with {rel}",
                })
                break  # one recurring nudge per relationship

        # connection points to reinforce (annotated with where it happened)
        for e in entries:
            if e["connection_point"]:
                cp = {
                    "relationship": rel,
                    "when": _ago(e["when"], ref),
                    "note": f"A moment that went well with {rel}.",
                }
                place = cmap.get(e["conversation_id"])
                if place:
                    cp["place"] = place
                connection_points.append(cp)

    # 4) spatial nudges — the settings that help or hurt
    for p in _place_stats(conn, user_id):
        if p["conversations"] < 2:
            continue
        if p["connection_rate"] >= 0.5:
            items.append({
                "type": "setting", "place": p["place"],
                "message": f"Conversations at {p['place']} tend to go well — a good setting for the harder ones.",
                "evidence": f"{round(p['connection_rate'] * 100)}% went well across {p['conversations']} there",
            })
        elif p["top_themes"] and p["top_themes"][0] in HARD_THEMES:
            items.append({
                "type": "setting", "place": p["place"],
                "message": f"Hard moments tend to happen at {p['place']} — a different setting might help.",
                "evidence": f"'{p['top_themes'][0]}' is the most common theme there ({p['conversations']} conversations)",
            })

    return {"user_id": user_id, "as_of": ref.isoformat(),
            "nudges": items, "connection_points": connection_points}


# --------------------------------------------------------------------------- #
# The scouting report (baseball card)
# --------------------------------------------------------------------------- #

def _strengths_from_events(conn, user_id):
    out = []
    for kind, positive, label_ in STRENGTH_SIGNALS:
        rows = conn.execute(
            "SELECT value, COUNT(*) AS c FROM events WHERE user_id=? AND kind=? GROUP BY value",
            (user_id, kind)).fetchall()
        total = sum(r["c"] for r in rows)
        pos = sum(r["c"] for r in rows if r["value"] in positive)
        if total >= 2 and pos / total >= 0.6:
            out.append({"label": label_, "evidence": f"{round(100 * pos / total)}% across {total} check-ins"})
    return out


def scouting_report(conn, user_id):
    nodes, edges, label, about, conv_themes = _load(conn, user_id)
    ref, per_rel, _ = _temporal(conn, user_id)

    # theme frequency + how many distinct relationships each theme spans
    theme_count = defaultdict(int)
    theme_rels = defaultdict(set)
    for conv, themes in conv_themes.items():
        rel = about.get(conv)
        for th in themes:
            theme_count[th] += 1
            if rel:
                theme_rels[th].add(rel)

    # signature themes: the personal patterns — cross-relationship spread first, then frequency
    signature = sorted(theme_count, key=lambda t: (len(theme_rels[t]), theme_count[t]), reverse=True)

    # per-relationship summary
    rel_convs = defaultdict(int)
    for conv, rel in about.items():
        rel_convs[rel] += 1
    relationships = []
    for rid, c in sorted(rel_convs.items(), key=lambda x: -x[1]):
        th_for_rel = defaultdict(int)
        for conv, rel in about.items():
            if rel == rid:
                for th in conv_themes.get(conv, []):
                    th_for_rel[label[th]] += 1
        top = [t for t, _ in sorted(th_for_rel.items(), key=lambda x: -x[1])[:3]]
        stats = _rel_stats(per_rel.get(rid, []), ref)
        relationships.append({
            "label": label[rid], "conversations": c, "top_themes": top,
            "last_contact_ago": _ago(_parse(stats.get("last_contact")), ref) if stats else None,
            "days_since_last": stats.get("days_since_last"),
            "cadence_days": stats.get("cadence_days"),
        })

    signature_themes = [{
        "theme": label[t],
        "count": theme_count[t],
        "relationships": sorted(label[r] for r in theme_rels[t]),
    } for t in signature[:5]]

    growth_areas = []
    for t in signature[:3]:
        lbl = label[t]
        phrasing = GROWTH.get(lbl, f"Working through what '{lbl}' keeps bringing up")
        spread = len(theme_rels[t])
        ev = f"came up in {theme_count[t]} conversation" + ("s" if theme_count[t] != 1 else "")
        if spread > 1:
            ev += f", across {spread} relationships"
        growth_areas.append({"label": phrasing, "evidence": ev})

    strengths = _strengths_from_events(conn, user_id)

    # WHY / HOW — internal (self) manner & need patterns; between-people (other) needs.
    needs, manners = _facet_profiles(conn, user_id)
    # strengths from constructive ways you show up
    for m, cnt in sorted(manners["self"].items(), key=lambda x: -x[1]):
        if cnt >= 2 and MANNER_VALENCE.get(m) == "constructive" and m in MANNER_STRENGTH:
            strengths.append({"label": MANNER_STRENGTH[m], "evidence": f"in {cnt} conversations"})
    # growth from a recurring destructive manner (how) ...
    for m, cnt in sorted(manners["self"].items(), key=lambda x: -x[1]):
        if cnt >= 2 and MANNER_VALENCE.get(m) == "destructive" and m in MANNER_GROWTH:
            growth_areas.append({"label": MANNER_GROWTH[m], "evidence": f"showed up {cnt} times in how you engaged"})
            break
    # ... and a recurring unmet need (why) on the other side
    for need, cnt in sorted(needs["other"].items(), key=lambda x: -x[1]):
        if cnt >= 2:
            growth_areas.append({"label": f"Meeting the need '{need}' before it festers",
                                 "evidence": f"'{need}' came up in {cnt} conversations"})
            break

    conv_total = len(about)
    if conv_total == 0:
        summary = "Not enough conversations yet to scout — come back after a few."
    else:
        s = strengths[0]["label"].lower() if strengths else "showing up and reflecting"
        g = growth_areas[0]["label"].lower() if growth_areas else "staying with it"
        summary = f"Good at {s}; working on {g}."

    n = nudges(conn, user_id, ref)

    return {
        "user_id": user_id,
        "as_of": ref.isoformat(),
        "conversations_scouted": conv_total,
        "summary": summary,
        "strengths": strengths[:4],
        "growth_areas": growth_areas[:4],
        "signature_themes": signature_themes,
        "relationships": relationships,
        "places": _place_stats(conn, user_id)[:5],
        # the 5W1H aggregate — internal (how you show up, what you need) vs between-people
        "how_you_show_up": {            # HOW, internal
            "constructive": _facet_list({k: v for k, v in manners["self"].items()
                                         if MANNER_VALENCE.get(k) == "constructive"}),
            "destructive": _facet_list({k: v for k, v in manners["self"].items()
                                        if MANNER_VALENCE.get(k) == "destructive"}),
        },
        "their_needs": _facet_list(needs["other"]),   # WHY, between-people
        "your_needs": _facet_list(needs["self"]),      # WHY, internal
        "nudges": n["nudges"],
        "connection_points": n["connection_points"],
    }

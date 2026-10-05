"""Per-model Claude rates for the cost tracker.

Source: https://platform.claude.com/docs/en/about-claude/pricing (model pricing
table, fetched 2026-10-05). USD per 1,000,000 tokens, Anthropic first-party API.
Bedrock and Vertex are partner-priced, so figures for them are estimates.

Every rate below is copied from that table, not derived from the input price:
the cache-read ratio differs by model (0.025x on Fable 5.1, 0.05x on Opus 5.5,
0.1x elsewhere), so a "read = input / 10" shortcut is wrong for current models.

Lookup is by exact model id after stripping date / platform decorations. A model
id that is not in the table is reported as unpriced; it is never priced as its
nearest-looking neighbour, because that is how a new release silently inherits
an old release's price.
"""
import hashlib
import json
import os
import re

# (input, output, cache write 5m, cache write 1h, cache read)
RATES = {
    "claude-fable-5-1":  (10.00, 50.00, 12.50, 20.00, 0.25),
    "claude-mythos-5-1": (10.00, 50.00, 12.50, 20.00, 0.25),
    "claude-fable-5":    (10.00, 50.00, 12.50, 20.00, 1.00),
    "claude-mythos-5":   (10.00, 50.00, 12.50, 20.00, 1.00),
    "claude-opus-5-5":   (4.00, 20.00, 5.00, 8.00, 0.20),
    "claude-opus-5":     (5.00, 25.00, 6.25, 10.00, 0.50),
    "claude-opus-4-8":   (5.00, 25.00, 6.25, 10.00, 0.50),
    "claude-opus-4-7":   (5.00, 25.00, 6.25, 10.00, 0.50),
    "claude-opus-4-6":   (5.00, 25.00, 6.25, 10.00, 0.50),
    "claude-opus-4-5":   (5.00, 25.00, 6.25, 10.00, 0.50),
    # Opus 4 / 4.1 are retired on the first-party API but appear in old
    # transcripts and databases, at the old Opus price.
    "claude-opus-4-1":   (15.00, 75.00, 18.75, 30.00, 1.50),
    "claude-opus-4":     (15.00, 75.00, 18.75, 30.00, 1.50),
    "claude-sonnet-5-5": (2.00, 10.00, 2.50, 4.00, 0.20),
    "claude-sonnet-5":   (2.00, 10.00, 2.50, 4.00, 0.20),
    "claude-sonnet-4-6": (3.00, 15.00, 3.75, 6.00, 0.30),
    "claude-sonnet-4-5": (3.00, 15.00, 3.75, 6.00, 0.30),
    "claude-sonnet-4":   (3.00, 15.00, 3.75, 6.00, 0.30),
    "claude-haiku-4-5":  (1.00, 5.00, 1.25, 2.00, 0.10),
    "claude-3-5-haiku":  (0.80, 4.00, 1.00, 1.60, 0.08),
    # Claude Code's id for messages it generates locally (API errors,
    # interruptions). Never sent to the API, never billed.
    "<synthetic>":       (0.0, 0.0, 0.0, 0.0, 0.0),
}

# Fast mode (`usage.speed == "fast"`). The pricing page lists Opus 5.5 at
# $8 / $40 and Opus 5 / 4.8 at $10 / $50 (2x standard) and says the caching
# multipliers apply on top, so every rate for the row doubles.
FAST_MULTIPLIER = {"claude-opus-5-5": 2.0, "claude-opus-5": 2.0, "claude-opus-4-8": 2.0}

# Bedrock ids: "anthropic.claude-..." or "us.anthropic.claude-...".
_PREFIX = re.compile(r"^(?:[a-z]{2,6}\.)?anthropic\.")
# "[1m]" context tags, Vertex "@20251101", Bedrock "-v1:0", API "-20251001".
_SUFFIX = re.compile(r"(?:\[[^\]]*\]|@\d{8}|-v\d+(?::\d+)?|-\d{8})$")


class Pricing(object):
    """A rate table plus the warning raised while loading it, if any."""

    def __init__(self, rates, fast, warning=None):
        self.rates = rates
        self.fast = fast
        self.warning = warning

    def fingerprint(self):
        blob = json.dumps([sorted(self.rates.items()), sorted(self.fast.items())])
        return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:12]


def normalize(model):
    m = (model or "").strip().lower()
    m = _PREFIX.sub("", m)
    previous = None
    while previous != m:
        previous = m
        m = _SUFFIX.sub("", m)
    return m


def _valid_row(value):
    return (
        isinstance(value, (list, tuple))
        and len(value) == 5
        and all(isinstance(x, (int, float)) and not isinstance(x, bool) and x >= 0
                for x in value)
    )


def load_pricing(path=None):
    """Built-in table, merged with the CLAUDE_COST_PRICING override file.

    The override is a JSON object of exact model ids to
    [input, output, cache_write_5m, cache_write_1h, cache_read], e.g.
    {"claude-opus-6": [4, 20, 5, 8, 0.2]}. A malformed file must not stop
    collection, so it is ignored, and the warning surfaces in --status.
    """
    path = path if path is not None else os.environ.get("CLAUDE_COST_PRICING")
    rates = dict(RATES)
    if not path:
        return Pricing(rates, dict(FAST_MULTIPLIER))
    try:
        with open(path, "r", encoding="utf-8") as fh:
            cfg = json.load(fh)
        if not isinstance(cfg, dict) or not cfg:
            raise ValueError("expected a JSON object of model id -> 5 rates")
        bad = [k for k, v in cfg.items() if not _valid_row(v)]
        if bad:
            raise ValueError("rows need 5 non-negative numbers: " + ", ".join(sorted(bad)[:5]))
        for key, value in cfg.items():
            rates[normalize(key)] = tuple(float(x) for x in value)
        return Pricing(rates, dict(FAST_MULTIPLIER))
    except (OSError, ValueError) as exc:
        return Pricing(rates, dict(FAST_MULTIPLIER),
                       warning="CLAUDE_COST_PRICING ignored (%s): %s" % (path, exc))


def lookup(model, pricing):
    key = normalize(model)
    return key if key in pricing.rates else None


def cost_usd(model, speed, in_tok, out_tok, cache_w, cache_w_1h, cache_r, pricing):
    """Return (usd, priced_as). Both are None when the model is not in the table.

    `cache_w` is all cache creation; `cache_w_1h` is the part written with the
    1-hour TTL, and the remainder is billed as 5-minute writes.
    """
    key = lookup(model, pricing)
    if key is None:
        return None, None
    p_in, p_out, p_w5, p_w1h, p_read = pricing.rates[key]
    w_1h = min(max(cache_w_1h, 0), cache_w)
    usd = (in_tok * p_in + out_tok * p_out + (cache_w - w_1h) * p_w5
           + w_1h * p_w1h + cache_r * p_read) / 1_000_000
    priced_as = key
    if speed == "fast" and key in pricing.fast:
        usd *= pricing.fast[key]
        priced_as = key + ":fast"
    return round(usd, 6), priced_as


def components(model, speed, in_tok, out_tok, cache_w, cache_w_1h, cache_r, pricing):
    """USD split into input / output / write 5m / write 1h / read, or None."""
    key = lookup(model, pricing)
    if key is None:
        return None
    mult = pricing.fast.get(key, 1.0) if speed == "fast" else 1.0
    p_in, p_out, p_w5, p_w1h, p_read = pricing.rates[key]
    w_1h = min(max(cache_w_1h, 0), cache_w)
    parts = (in_tok * p_in, out_tok * p_out, (cache_w - w_1h) * p_w5,
             w_1h * p_w1h, cache_r * p_read)
    return tuple(p * mult / 1_000_000 for p in parts)

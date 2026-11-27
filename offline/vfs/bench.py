#!/usr/bin/env python3
"""Time a fixed list of wiki requests. Usage: bench.py PORT [REPS] [WARMUPS]"""
import json, re, statistics, sys, time, urllib.request

URLS = [
    ("Main page", "index.php/Main_Page", "MediaWiki has been installed"),
    ("Falcon 9", "index.php/Falcon_9", "549054"),
    ("Item:Q1", "index.php/Item:Q1", "two-stage orbital rocket"),
    ("WbProperty:P1", "index.php/WbProperty:P1", "mass"),
    ("Property:Has mass", "index.php/Property:Has_mass", "Number"),
    ("Statement test", "index.php/Statement_test", "550,000"),
    ("Special:Search", "index.php?search=rocket&title=Special:Search&fulltext=1", "mw-search-result-heading"),
    ("Special:Ask", "index.php?title=Special:Ask&q=%5B%5BHas+mass%3A%3A%2B%5D%5D&po=%3FHas+mass", "Falcon 9"),
    ("Special:Browse", "index.php/Special:Browse/:Falcon_9", "Falcon"),
    ("Special:RecentChanges", "index.php/Special:RecentChanges", "Statement test"),
    ("history", "index.php?title=Falcon_9&action=history", "Admin"),
    ("Special:AllPages", "index.php/Special:AllPages", "Electron"),
    ("Special:Version", "index.php/Special:Version", "Semantic MediaWiki"),
    ("api ask", "api.php?action=ask&query=%5B%5BHas%20mass::%3E30000%5D%5D%7C%3FHas%20mass&format=json", '"Has mass":[549054]'),
    ("api wbgetentities", "api.php?action=wbgetentities&ids=Q1&format=json", '"id":"Q1"'),
    ("api wbsearch", "api.php?action=wbsearchentities&search=Falc&language=en&format=json", '"id":"Q1"'),
    ("api parse #ask", "api.php?action=parse&text=%7B%7B%23ask:%5B%5BHas%20mass::%2B%5D%5D%7C%3FHas%20mass%7D%7D&contentmodel=wikitext&prop=text&format=json", "12,500"),
    ("load.php startup", "load.php?lang=en&modules=startup&only=scripts&raw=1&skin=vector-2022", "mw.loader"),
    ("load.php jquery+mw", "load.php?lang=en&modules=jquery%7Cmediawiki.base&skin=vector-2022", "jQuery"),
    ("load.php wikibase ui", "load.php?lang=en&modules=wikibase.entityPage.entityLoaded%7Cwikibase.ui.entityViewInit&skin=vector-2022", "wikibase"),
    ("load.php smw styles", "load.php?lang=en&modules=ext.smw.styles&only=styles&skin=vector-2022", "smw"),
]
BAD = re.compile(r"Fatal error|exception of type|DBReadOnlyError|attempt to write a readonly|Warning</b>|unable to open", re.I)

def get(port, path):
    t = time.perf_counter()
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/{path}", timeout=120) as r:
            body, code = r.read().decode("utf-8", "replace"), r.status
    except urllib.error.HTTPError as e:
        body, code = e.read().decode("utf-8", "replace"), e.code
    return time.perf_counter() - t, code, body

def main():
    port = int(sys.argv[1]); reps = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    warm = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({})))
    cold, _, _ = get(port, URLS[0][1])
    out = {"cold_first_request_ms": round(cold * 1000), "rows": {}}
    for _ in range(warm):
        for _, path, _ in URLS: get(port, path)
    for name, path, key in URLS:
        ts, ok = [], True
        for _ in range(reps):
            t, code, body = get(port, path)
            ts.append(t * 1000)
            ok = ok and code == 200 and key in body and not BAD.search(body)
        out["rows"][name] = {"median_ms": round(statistics.median(ts), 1), "min_ms": round(min(ts), 1), "ok": ok}
    meds = [r["median_ms"] for r in out["rows"].values()]
    out["median_of_medians_ms"] = round(statistics.median(meds), 1)
    out["sum_of_medians_ms"] = round(sum(meds), 1)
    out["all_ok"] = all(r["ok"] for r in out["rows"].values())
    try:
        out["opcache"] = json.loads(get(port, "opstatus.php")[2])
    except Exception as e:
        out["opcache"] = str(e)
    json.dump(out, sys.stdout, indent=1)

if __name__ == "__main__":
    main()

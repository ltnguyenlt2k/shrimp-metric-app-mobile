"""Download Roboflow Universe datasets listed below into data/raw/roboflow/.

The API key is read from ~/.config/shrimpmetric/roboflow.key (never stored in the repo).
    python registry/fetch_roboflow.py
"""
import hashlib
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "data/raw/roboflow"
KEY_FILE = Path.home() / ".config/shrimpmetric/roboflow.key"
PROJECTS = [  # workspace, project, preferred version (None = newest)
    ("jala-apjmn", "vannamei-shrimp", 8),
    ("thenho", "shrimp-size", None),
    ("thenho", "merge_project-mucyd", None),
    ("thenho", "img-smkzh", None),
    ("thenho", "shrimpsizefromcameraclaibration", None),
    ("taikisgroup2", "counting-pl-baby-shrimp", 1),
    ("taikis-group", "plcounting", 5),
    ("espol-magof", "shrimp-object-tracking-and-counting", 7),
]


def export_link(url, key):
    """Roboflow builds an export on first request; poll until it is ready."""
    for _ in range(40):
        export = get(url, key)
        if "export" in export:
            return export["export"]["link"]
        time.sleep(6)
    raise KeyError("export not ready")


def get(url, key):
    request = urllib.request.Request(f"{url}?api_key={key}", headers={"User-Agent": "dataset-fetch"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def main():
    key = KEY_FILE.read_text().strip()
    TARGET.mkdir(parents=True, exist_ok=True)
    report = []
    for workspace, project, wanted in PROJECTS + [tuple(a.split("/")) + (None,) for a in sys.argv[1:]]:
        entry = {"workspace": workspace, "project": project}
        try:
            info = get(f"https://api.roboflow.com/{workspace}/{project}", key)
            meta = info.get("project", {})
            versions = sorted(int(v["id"].split("/")[-1]) for v in info.get("versions", []))
            entry.update(type=meta.get("type"), license=meta.get("license"), images=meta.get("images"),
                         classes=meta.get("classes"), versions=versions)
            if not versions:
                raise RuntimeError("no downloadable version")
            version = wanted if wanted in versions else versions[-1]
            formats = ["coco-segmentation", "coco"] if "segmentation" in str(meta.get("type")) else ["coco"]
            for fmt in formats:
                try:
                    link = export_link(f"https://api.roboflow.com/{workspace}/{project}/{version}/{fmt}", key)
                    break
                except (urllib.error.HTTPError, KeyError) as error:
                    entry.setdefault("format_errors", []).append(f"{fmt}: {error}")
            else:
                raise RuntimeError("no export link")
            path = TARGET / f"{workspace}--{project}-v{version}-{fmt}.zip"
            if not path.exists():
                urllib.request.urlretrieve(link, path)
            entry.update(version=version, format=fmt, file=str(path.relative_to(ROOT)),
                         bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        except Exception as error:  # report and continue with the next project
            entry["error"] = str(error).replace(key, "***")
        report.append(entry)
        print(json.dumps(entry, ensure_ascii=False), flush=True)
    (TARGET / "fetch-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

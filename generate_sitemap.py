#!/usr/bin/env python3
"""Generate an XML sitemap from all index.html files in a directory tree."""

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def git_log_date(file_path: Path, git_root: Path) -> str:
    """Return the last commit date of a file in ISO 8601 short form, or today as fallback."""
    try:
        # Resolve the real path (follows symlinks) so git can find it
        real_path = file_path.resolve()

        # Try relative path from git root (works when inside the repo)
        rel = real_path.relative_to(git_root)
        git_path = str(rel)

        # Try absolute path as fallback
        if not subprocess.run(
            ["git", "log", "-1", "--format=%ad", "--date=short", "--", git_path],
            cwd=str(git_root), capture_output=True, text=True
        ).stdout.strip():
            git_path = str(real_path)

        result = subprocess.run(
            ["git", "log", "-1", "--format=%ad", "--date=short", "--", git_path],
            cwd=str(git_root), capture_output=True, text=True
        )
        date_str = result.stdout.strip()
        if date_str:
            return date_str
    except (ValueError, subprocess.SubprocessError, OSError):
        pass
    return datetime.now().strftime("%Y-%m-%d")


def find_git_root(start: Path) -> Path | None:
    """Walk up from start looking for a .git directory. Returns None if not found."""
    candidate = start
    while candidate != candidate.parent:
        if (candidate / ".git").exists():
            return candidate
        candidate = candidate.parent
    return None


def generate_sitemap(directory: str, base_url: str, output: str = "sitemap.xml") -> None:
    """Scan directory for index.html files and write an XML sitemap."""
    dir_path = Path(directory).resolve()
    if not dir_path.is_dir():
        print(f"Error: '{directory}' is not a valid directory.", file=sys.stderr)
        sys.exit(1)

    if not base_url.endswith("/"):
        base_url += "/"

    # Find the git repo root
    env_git_root = os.environ.get("SITEMAP_GIT_ROOT")
    if env_git_root:
        git_root = Path(env_git_root).resolve()
    else:
        git_root = find_git_root(dir_path)

    locs = []
    for root, _dirs, files in os.walk(dir_path, followlinks=True):
        if "index.html" in files:
            file_path = Path(root) / "index.html"
            rel_path = file_path.relative_to(dir_path).with_suffix("")
            # Strip trailing 'index' so the URL is clean
            url_path = rel_path.as_posix()
            if url_path.endswith("/index"):
                url_path = url_path[:-6]
            elif url_path == "index":
                url_path = ""
            url = base_url + url_path.lstrip("/")
            lastmod = git_log_date(file_path, git_root) if git_root else None
            locs.append((url, lastmod))

    if not locs:
        print("No index.html files found.", file=sys.stderr)
        sys.exit(1)

    # Sort for deterministic output
    locs.sort(key=lambda x: x[0])

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for url, lastmod in locs:
        lines.append("  <url>")
        lines.append(f"    <loc>{url}</loc>")
        if lastmod:
            lines.append(f"    <lastmod>{lastmod}</lastmod>")
        lines.append("  </url>")
    lines.append("</urlset>")

    sitemap = "\n".join(lines) + "\n"

    out_path = Path(output)
    out_path.write_text(sitemap, encoding="utf-8")
    print(f"Sitemap written to {out_path} ({len(locs)} URLs)")


def main():
    parser = argparse.ArgumentParser(description="Generate a sitemap from index.html files.")
    parser.add_argument("directory", help="Root directory to scan")
    parser.add_argument("-u", "--url", required=True, help="Base URL of the site (e.g. https://example.com)")
    parser.add_argument("-o", "--output", default="sitemap.xml", help="Output file path (default: sitemap.xml)")
    parser.add_argument("--git-root", help="Path to the git repository root (optional)")
    args = parser.parse_args()

    # Allow overriding git root via command line
    if args.git_root:
        os.environ["SITEMAP_GIT_ROOT"] = args.git_root

    generate_sitemap(args.directory, args.url, args.output)


if __name__ == "__main__":
    main()

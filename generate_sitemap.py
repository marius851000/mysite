#!/usr/bin/env python3
"""Generate an XML sitemap from all index.html files in a directory tree."""

import argparse
import os
import sys

from pathlib import Path
from urllib.parse import urljoin


def generate_sitemap(directory: str, base_url: str, output: str = "sitemap.xml") -> None:
    """Scan directory for index.html files and write an XML sitemap."""
    dir_path = Path(directory).resolve()
    if not dir_path.is_dir():
        print(f"Error: '{directory}' is not a valid directory.", file=sys.stderr)
        sys.exit(1)

    if not base_url.endswith("/"):
        base_url += "/"

    locs = []
    for root, _dirs, files in os.walk(dir_path, followlinks=True):
        if "index.html" in files:
            file_path = Path(root) / "index.html"
            rel_path = file_path.relative_to(dir_path).with_suffix("")
            # Strip trailing 'index' so the URL is clean (e.g. /blog/cairnsave not /blog/cairnsave/index)
            url_path = rel_path.as_posix()
            if url_path.endswith("/index"):
                url_path = url_path[:-6]
            elif url_path == "index":
                url_path = ""
            url = base_url + url_path.lstrip("/")
            locs.append(url)

    if not locs:
        print("No index.html files found.", file=sys.stderr)
        sys.exit(1)

    # Sort for deterministic output
    locs.sort(key=lambda x: x[0])

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]
    for url in locs:
        lines.append("  <url>")
        lines.append(f"    <loc>{url}</loc>")
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
    args = parser.parse_args()
    generate_sitemap(args.directory, args.url, args.output)


if __name__ == "__main__":
    main()

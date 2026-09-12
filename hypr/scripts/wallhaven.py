#!/usr/bin/env python3
"""
Wallhaven & Local Wallpaper helper for Carbon Shell.
Subcommands:
  search [--sort toplist|date_added] [--query <query>] [--page <n>]
  list-local [--query <query>]
  download <url> <filename>
  apply <path>
"""

import sys
import os
import re
import json
import urllib.request
import urllib.parse
import subprocess

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
WP_APPLY_SCRIPT = os.path.expanduser("~/.config/hypr/scripts/wp-apply.sh")
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"


def search(sort="toplist", query="", page=1):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    
    params = {
        "purity": "100",  # SFW
        "sorting": sort,
        "ratios": "landscape",
        "page": str(page),
    }
    if query and query.strip():
        params["q"] = query.strip()
    
    url = f"https://wallhaven.cc/api/v1/search?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    
    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            data = json.loads(response.read().decode("utf-8"))
            items = []
            for entry in data.get("data", []):
                wall_id = entry.get("id")
                res = entry.get("resolution", "HD")
                full_path = entry.get("path")
                file_type = entry.get("file_type", "image/jpeg")
                ext = "png" if "png" in file_type else "jpg"
                filename = f"wallhaven-{wall_id}.{ext}"
                
                thumbs = entry.get("thumbs", {})
                thumb_url = thumbs.get("large") or thumbs.get("small") or full_path
                
                items.append({
                    "id": wall_id,
                    "resolution": res,
                    "category": entry.get("category", "general"),
                    "thumb": thumb_url,
                    "url": full_path,
                    "filename": filename,
                    "is_local": False,
                    "exists": os.path.isfile(os.path.join(WALLPAPER_DIR, filename))
                })
            
            print(json.dumps({"success": True, "data": items}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e), "data": []}))


def list_local(query=""):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    cache_dir = os.path.expanduser("~/.cache/carbon/wp-thumbs")
    
    valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
    entries = []
    
    try:
        filenames = os.listdir(WALLPAPER_DIR)
    except OSError:
        filenames = []
        
    for fname in filenames:
        ext = os.path.splitext(fname)[1].lower()
        if ext not in valid_exts:
            continue
        
        full_path = os.path.join(WALLPAPER_DIR, fname)
        if not os.path.isfile(full_path):
            continue
            
        if query and query.strip().lower() not in fname.lower():
            continue
            
        try:
            mtime = os.path.getmtime(full_path)
        except OSError:
            mtime = 0
            
        # Check thumbnail cache
        safe_thumb_name = fname.replace(".", "_") + ".png"
        thumb_cached_path = os.path.join(cache_dir, safe_thumb_name)
        if os.path.isfile(thumb_cached_path) and os.path.getsize(thumb_cached_path) > 0:
            thumb_url = f"file://{thumb_cached_path}"
        else:
            thumb_url = f"file://{full_path}"
            
        # Check if resolution is in filename
        res = "HD"
        m = re.search(r"(\d{3,5}x\d{3,5})", fname)
        if m:
            res = m.group(1)
            
        entries.append({
            "id": fname,
            "resolution": res,
            "category": "local",
            "thumb": thumb_url,
            "url": f"file://{full_path}",
            "path": full_path,
            "filename": fname,
            "mtime": mtime,
            "is_local": True
        })
        
    entries.sort(key=lambda x: x["mtime"], reverse=True)
    print(json.dumps({"success": True, "data": entries}))


LIVE_WALLPAPER_DIR = os.path.expanduser("~/Pictures/Live_Wallpapers")

def list_live(query=""):
    os.makedirs(LIVE_WALLPAPER_DIR, exist_ok=True)
    cache_dir = os.path.expanduser("~/.cache/carbon/wp-thumbs")
    os.makedirs(cache_dir, exist_ok=True)

    valid_exts = {".mp4", ".gif", ".m4v", ".webm", ".mkv"}
    entries = []

    try:
        filenames = os.listdir(LIVE_WALLPAPER_DIR)
    except OSError:
        filenames = []

    for fname in filenames:
        ext = os.path.splitext(fname)[1].lower()
        if ext not in valid_exts:
            continue

        full_path = os.path.join(LIVE_WALLPAPER_DIR, fname)
        if not os.path.isfile(full_path):
            continue

        if query and query.strip().lower() not in fname.lower():
            continue

        try:
            mtime = os.path.getmtime(full_path)
        except OSError:
            mtime = 0

        # Thumbnail extraction for live wallpaper
        safe_thumb_name = "live_" + fname.replace(".", "_") + ".png"
        thumb_cached_path = os.path.join(cache_dir, safe_thumb_name)
        if not (os.path.isfile(thumb_cached_path) and os.path.getsize(thumb_cached_path) > 0):
            try:
                if ext in {".mp4", ".m4v", ".webm", ".mkv"}:
                    subprocess.run(
                        ["ffmpeg", "-y", "-i", full_path, "-vframes", "1", "-ss", "00:00:00.500", "-vf", "scale=400:-1", thumb_cached_path],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4
                    )
                elif ext == ".gif":
                    subprocess.run(
                        ["magick", f"{full_path}[0]", "-resize", "400x", thumb_cached_path],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4
                    )
            except Exception:
                pass

        if os.path.isfile(thumb_cached_path) and os.path.getsize(thumb_cached_path) > 0:
            thumb_url = f"file://{thumb_cached_path}"
        else:
            thumb_url = f"file://{full_path}"

        res = "LIVE"
        m = re.search(r"(\d{3,5}x\d{3,5})", fname)
        if m:
            res = m.group(1)

        entries.append({
            "id": "live_" + fname,
            "resolution": res,
            "category": "live",
            "thumb": thumb_url,
            "url": f"file://{full_path}",
            "path": full_path,
            "filename": fname,
            "mtime": mtime,
            "is_local": True,
            "is_live": True
        })

    entries.sort(key=lambda x: x["mtime"], reverse=True)
    print(json.dumps({"success": True, "data": entries}))


def download(url, filename):
    os.makedirs(WALLPAPER_DIR, exist_ok=True)
    dest_path = os.path.join(WALLPAPER_DIR, os.path.basename(filename))
    
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=25) as response, open(dest_path, "wb") as out_file:
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                out_file.write(chunk)
        
        if os.path.isfile(WP_APPLY_SCRIPT):
            subprocess.run(["sh", WP_APPLY_SCRIPT, dest_path], check=False)
            
        print(json.dumps({"success": True, "path": dest_path}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))


def apply_local(path):
    if os.path.isfile(path) and os.path.isfile(WP_APPLY_SCRIPT):
        subprocess.run(["sh", WP_APPLY_SCRIPT, path], check=False)
        print(json.dumps({"success": True, "path": path}))
    else:
        print(json.dumps({"success": False, "error": "File not found"}))


def main():
    if len(sys.argv) < 2:
        print("Usage: wallhaven.py <search|list-local|download|apply> [args...]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "search":
        sort = "toplist"
        query = ""
        page = 1
        
        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--sort" and i + 1 < len(sys.argv):
                sort = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--query" and i + 1 < len(sys.argv):
                query = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--page" and i + 1 < len(sys.argv):
                try:
                    page = int(sys.argv[i + 1])
                except ValueError:
                    page = 1
                i += 2
            else:
                i += 1
        search(sort=sort, query=query, page=page)

    elif cmd in ("list-local", "local"):
        query = ""
        if len(sys.argv) > 2 and sys.argv[2] == "--query" and len(sys.argv) > 3:
            query = sys.argv[3]
        elif len(sys.argv) > 2:
            query = sys.argv[2]
        list_local(query=query)

    elif cmd in ("list-live", "live"):
        query = ""
        if len(sys.argv) > 2 and sys.argv[2] == "--query" and len(sys.argv) > 3:
            query = sys.argv[3]
        elif len(sys.argv) > 2:
            query = sys.argv[2]
        list_live(query=query)

    elif cmd == "download":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Missing url or filename"}))
            sys.exit(1)
        url = sys.argv[2]
        filename = sys.argv[3]
        download(url, filename)

    elif cmd == "apply":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing path"}))
            sys.exit(1)
        apply_local(sys.argv[2])

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()

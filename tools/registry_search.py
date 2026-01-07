#!/usr/bin/env python3
"""
OmniScript - Registry Search Tool
Advanced search capabilities across container registries with caching and rate limiting.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Optional

# Configuration
CACHE_DIR = Path(os.environ.get('OS_DATA_DIR', Path.home() / '.omniscript')) / 'cache' / 'python'
CACHE_TTL = 3600  # 1 hour

@dataclass
class ImageResult:
    """Container image search result."""
    name: str
    registry: str
    description: str
    stars: int = 0
    pulls: int = 0
    official: bool = False
    latest_tag: str = "latest"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class RegistrySearcher:
    """Search across multiple container registries."""

    def __init__(self, use_cache: bool = True):
        self.use_cache = use_cache
        CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def _get_cached(self, key: str) -> Optional[Any]:
        """Get cached data if valid."""
        if not self.use_cache:
            return None

        cache_file = CACHE_DIR / f"{key}.json"
        if cache_file.exists():
            try:
                with open(cache_file) as f:
                    data = json.load(f)
                cached_at = datetime.fromisoformat(data.get('cached_at', '1970-01-01'))
                if datetime.now() - cached_at < timedelta(seconds=CACHE_TTL):
                    return data.get('data')
            except (json.JSONDecodeError, KeyError):
                pass
        return None

    def _set_cached(self, key: str, data: Any) -> None:
        """Cache data."""
        cache_file = CACHE_DIR / f"{key}.json"
        with open(cache_file, 'w') as f:
            json.dump({
                'cached_at': datetime.now().isoformat(),
                'data': data
            }, f)

    def _http_get(self, url: str, headers: Optional[dict] = None) -> Optional[dict]:
        """Make HTTP GET request."""
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'OmniScript/1.0')
        if headers:
            for k, v in headers.items():
                req.add_header(k, v)

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                return json.loads(response.read().decode())
        except (urllib.error.URLError, json.JSONDecodeError) as e:
            print(f"Error fetching {url}: {e}", file=sys.stderr)
            return None

    def search_docker_hub(self, term: str, limit: int = 25) -> list[ImageResult]:
        """Search Docker Hub."""
        cache_key = f"dockerhub_{term}_{limit}"
        cached = self._get_cached(cache_key)
        if cached:
            return [ImageResult(**r) for r in cached]

        url = f"https://hub.docker.com/v2/search/repositories/?query={urllib.parse.quote(term)}&page_size={limit}"
        data = self._http_get(url)

        if not data or 'results' not in data:
            return []

        results = []
        for item in data['results']:
            result = ImageResult(
                name=item.get('repo_name', ''),
                registry='docker.io',
                description=(item.get('short_description') or '')[:100],
                stars=item.get('star_count', 0),
                pulls=item.get('pull_count', 0),
                official=item.get('is_official', False)
            )
            results.append(result)

        self._set_cached(cache_key, [r.to_dict() for r in results])
        return results

    def search_quay(self, term: str, limit: int = 25) -> list[ImageResult]:
        """Search Quay.io."""
        cache_key = f"quay_{term}_{limit}"
        cached = self._get_cached(cache_key)
        if cached:
            return [ImageResult(**r) for r in cached]

        url = f"https://quay.io/api/v1/find/repositories?query={urllib.parse.quote(term)}&page=1"
        data = self._http_get(url)

        if not data or 'results' not in data:
            return []

        results = []
        for item in data['results'][:limit]:
            namespace = item.get('namespace', {}).get('name', '')
            name = item.get('name', '')
            result = ImageResult(
                name=f"quay.io/{namespace}/{name}",
                registry='quay.io',
                description=(item.get('description') or '')[:100],
                stars=0,
                pulls=0
            )
            results.append(result)

        self._set_cached(cache_key, [r.to_dict() for r in results])
        return results

    def get_tags(self, image: str, limit: int = 50) -> list[str]:
        """Get available tags for an image."""
        # Parse image
        if '/' not in image:
            image = f"library/{image}"

        cache_key = f"tags_{image.replace('/', '_')}_{limit}"
        cached = self._get_cached(cache_key)
        if cached:
            return cached

        url = f"https://hub.docker.com/v2/repositories/{image}/tags?page_size={limit}"
        data = self._http_get(url)

        if not data or 'results' not in data:
            return []

        tags = [t['name'] for t in data['results'] if 'name' in t]
        self._set_cached(cache_key, tags)
        return tags

    def get_best_tag(self, image: str) -> str:
        """Get the best (latest stable) tag for an image."""
        tags = self.get_tags(image)

        if not tags:
            return "latest"

        # Exclude patterns
        exclude = {'latest', 'edge', 'nightly', 'dev', 'develop', 'master',
                   'main', 'unstable', 'beta', 'alpha', 'rc', 'test', 'testing'}

        # Filter to semver-like tags
        semver_pattern = re.compile(r'^v?\d+(\.\d+)?(\.\d+)?(-[\w]+)?$')
        valid_tags = [t for t in tags
                      if t.lower() not in exclude
                      and semver_pattern.match(t)]

        if not valid_tags:
            return tags[0] if tags else "latest"

        # Sort by version (basic semver sort)
        def version_key(tag):
            t = tag.lstrip('v')
            parts = re.split(r'[-.]', t)
            result = []
            for p in parts[:4]:
                try:
                    result.append(int(p))
                except ValueError:
                    result.append(0)
            while len(result) < 4:
                result.append(0)
            return result

        valid_tags.sort(key=version_key, reverse=True)
        return valid_tags[0]

    def search_all(self, term: str, limit: int = 10) -> dict[str, list[ImageResult]]:
        """Search all registries."""
        return {
            'docker_hub': self.search_docker_hub(term, limit),
            'quay': self.search_quay(term, limit)
        }


def main():
    parser = argparse.ArgumentParser(description='OmniScript Registry Search Tool')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Search command
    search_parser = subparsers.add_parser('search', help='Search for images')
    search_parser.add_argument('term', help='Search term')
    search_parser.add_argument('-r', '--registry', choices=['all', 'docker', 'quay'],
                              default='all', help='Registry to search')
    search_parser.add_argument('-l', '--limit', type=int, default=10, help='Result limit')
    search_parser.add_argument('--json', action='store_true', help='Output as JSON')

    # Tags command
    tags_parser = subparsers.add_parser('tags', help='Get image tags')
    tags_parser.add_argument('image', help='Image name')
    tags_parser.add_argument('-l', '--limit', type=int, default=50, help='Tag limit')
    tags_parser.add_argument('--json', action='store_true', help='Output as JSON')

    # Best-tag command
    best_parser = subparsers.add_parser('best-tag', help='Get best tag for image')
    best_parser.add_argument('image', help='Image name')

    # Clear cache
    subparsers.add_parser('clear-cache', help='Clear cache')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    searcher = RegistrySearcher()

    if args.command == 'search':
        if args.registry == 'all':
            results = searcher.search_all(args.term, args.limit)
            if args.json:
                print(json.dumps({k: [r.to_dict() for r in v] for k, v in results.items()}, indent=2))
            else:
                for registry, items in results.items():
                    print(f"\n=== {registry.upper()} ===")
                    for r in items:
                        stars = f"★{r.stars}" if r.stars else ""
                        official = "[OFFICIAL]" if r.official else ""
                        print(f"  {r.name} {stars} {official}")
                        if r.description:
                            print(f"    {r.description[:60]}...")
        else:
            if args.registry == 'docker':
                results = searcher.search_docker_hub(args.term, args.limit)
            else:
                results = searcher.search_quay(args.term, args.limit)

            if args.json:
                print(json.dumps([r.to_dict() for r in results], indent=2))
            else:
                for r in results:
                    stars = f"★{r.stars}" if r.stars else ""
                    print(f"{r.name} {stars} - {r.description[:50]}")

    elif args.command == 'tags':
        tags = searcher.get_tags(args.image, args.limit)
        if args.json:
            print(json.dumps(tags))
        else:
            for tag in tags:
                print(tag)

    elif args.command == 'best-tag':
        tag = searcher.get_best_tag(args.image)
        print(tag)

    elif args.command == 'clear-cache':
        import shutil
        if CACHE_DIR.exists():
            shutil.rmtree(CACHE_DIR)
            print("Cache cleared")


if __name__ == '__main__':
    main()

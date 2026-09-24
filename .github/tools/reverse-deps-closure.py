#!/usr/bin/env python3
"""Worst-case reverse-dependency closure of a capability across ALT repositories.

Answers the question a replacement package has to answer before it ships: if
every package of the repository were installed, how many would `apt-get remove`
take down together with this library — that is, how large the automatic restore
in %postun can ever get.

Reads `apt-cache dumpavail`, so it reports the envelope of the configured
repositories, not of the current machine. The installed closure is whatever
`libdecor-restore consumers` prints.

    ./reverse-deps-closure.py 'libdecor-0.so.0()(64bit)'
    ./reverse-deps-closure.py 'libdecor-0.so.0()(64bit)' --skip-prefix libdecor
"""
import argparse
import collections
import subprocess
import sys


def load_repository():
    """Return (depends, provides_of, providers) parsed from apt-cache dumpavail."""
    dumpavail = subprocess.run(
        ["apt-cache", "dumpavail"], capture_output=True, text=True, check=True
    ).stdout

    depends = {}
    provides_of = {}
    providers = collections.defaultdict(set)
    name = None

    for line in dumpavail.splitlines():
        if line.startswith("Package: "):
            name = line[9:].strip()
            depends.setdefault(name, set())
            provides_of.setdefault(name, set())
        elif not name:
            continue
        elif line.startswith("Depends: "):
            for dep in line[9:].split(","):
                for alternative in dep.split("|"):
                    parts = alternative.strip().split()
                    # A capability is the first token; a version constraint
                    # follows it in its own parentheses after a space. Splitting
                    # on "(" would mangle soname capabilities such as
                    # libdecor-0.so.0()(64bit).
                    if parts:
                        depends[name].add(parts[0])
        elif line.startswith("Provides: "):
            for provided in line[10:].split(","):
                parts = provided.strip().split()
                if parts:
                    provides_of[name].add(parts[0])
                    providers[parts[0]].add(name)

    for package in depends:
        providers[package].add(package)

    return depends, provides_of, providers


def closure(capability, skip_prefix, depends, provides_of, providers):
    """Breadth-first reverse-dependency closure, returned level by level."""
    rdeps = collections.defaultdict(set)
    for package, capabilities in depends.items():
        for one in capabilities:
            rdeps[one].add(package)

    def keep(package):
        return not (skip_prefix and package.startswith(skip_prefix))

    frontier = {p for p in rdeps.get(capability, set()) if keep(p)}
    seen = set(frontier)
    levels = [sorted(frontier)] if frontier else []

    while frontier:
        following = set()
        for package in frontier:
            # Dependents reach a package by its name, or by a capability only
            # this package provides.
            reachable_by = {package} | {
                c for c in provides_of.get(package, set()) if len(providers[c]) == 1
            }
            for one in reachable_by:
                for dependent in rdeps.get(one, set()):
                    if dependent not in seen and keep(dependent):
                        following.add(dependent)
        seen |= following
        if following:
            levels.append(sorted(following))
        frontier = following

    return seen, levels


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capability", help="e.g. 'libdecor-0.so.0()(64bit)'")
    parser.add_argument(
        "--skip-prefix",
        default="",
        help="ignore packages whose name starts with this (the library itself)",
    )
    args = parser.parse_args()

    depends, provides_of, providers = load_repository()
    seen, levels = closure(
        args.capability, args.skip_prefix, depends, provides_of, providers
    )

    print(f"пакетов в репозиториях: {len(depends)}")
    print(f"замыкание: {len(seen)} пакетов, уровней: {len(levels)}")
    print()
    for number, level in enumerate(levels, 1):
        shown = ", ".join(level[:14])
        more = f" … и ещё {len(level) - 14}" if len(level) > 14 else ""
        print(f"уровень {number} ({len(level)}): {shown}{more}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

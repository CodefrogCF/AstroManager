#!/usr/bin/env python3
"""Build AstroManager's offline catalog from OpenNGC.

Source: https://github.com/mattiaverga/OpenNGC
Release: v20260501
License: CC BY-SA 4.0

The resulting JSON is an adapted dataset, not the original
OpenNGC CSV. Retain attribution and license information.
"""

import csv
import io
import json
import math
import re
import urllib.request
from pathlib import Path

VERSION = "v20260501"

BASE_URL = (
    "https://raw.githubusercontent.com/"
    f"mattiaverga/OpenNGC/{VERSION}/"
)

FILES = (
    "database_files/NGC.csv",
    "database_files/addendum.csv",
)

OUTPUT = Path("assets/catalog/openngc_20260501.json")
LICENSE_OUTPUT = Path("assets/catalog/LICENSE-OpenNGC.txt")

REJECT_TYPES = {"NonEx", "Dup"}

GALAXIES = {"G", "GPair", "GTrpl", "GGroup"}
CLUSTERS = {"OCl", "GCl", "Cl+N", "*Ass"}
NEBULAE = {"PN", "HII", "DrkN", "EmN", "Neb", "RfN", "SNR"}
STARS = {"*", "**", "Nova"}


def download_text(path):
    url = BASE_URL + path
    print(f"Downloading {url}")

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "AstroManager-CatalogBuilder/1.0"},
    )

    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8-sig")


def parse_ra(value):
    hours, minutes, seconds = map(float, value.split(":"))

    if not (
        0 <= hours <= 24
        and 0 <= minutes < 60
        and 0 <= seconds < 60
    ):
        raise ValueError(f"Invalid RA: {value}")

    return ((hours + minutes / 60 + seconds / 3600) * 15) % 360


def parse_dec(value):
    sign = -1 if value.startswith("-") else 1
    components = value.lstrip("+-").split(":")

    degrees, minutes, seconds = map(float, components)

    result = sign * (
        degrees + minutes / 60 + seconds / 3600
    )

    if (
        not -90 <= result <= 90
        or not 0 <= minutes < 60
        or not 0 <= seconds < 60
    ):
        raise ValueError(f"Invalid Dec: {value}")

    return result


def optional_float(value):
    if not value or not value.strip():
        return None

    result = float(value.strip())
    return result if math.isfinite(result) else None


def category_for(source_type):
    if source_type in GALAXIES:
        return "galaxy"
    if source_type in CLUSTERS:
        return "cluster"
    if source_type in NEBULAE:
        return "nebula"
    if source_type in STARS:
        return "star"
    return "other"


def display_name(identifier):
    match = re.fullmatch(
        r"(NGC|IC|M)(\d+)(.*)",
        identifier,
        re.IGNORECASE,
    )

    if match:
        prefix, number, suffix = match.groups()
        return f"{prefix.upper()} {int(number)}{suffix}"

    return identifier


def optional_messier_number(value):
    if not value or not value.strip():
        return None

    number = int(value.strip())

    if not 1 <= number <= 110:
        raise ValueError(f"Invalid Messier number: {value}")

    return number


def parse_row(row):
    identifier = row["Name"].strip()
    source_type = row["Type"].strip()

    if source_type in REJECT_TYPES:
        return None

    ra = row["RA"].strip()
    dec = row["Dec"].strip()

    if not identifier or not ra or not dec:
        return None

    ra_degrees = round(parse_ra(ra), 8)
    dec_degrees = round(parse_dec(dec), 8)

    messier = optional_messier_number(row["M"])

    names = row["Common names"].strip()
    aliases = [identifier, display_name(identifier)]

    if messier is not None:
        aliases.extend([
            f"M{messier}",
            f"M {messier}",
        ])

    for column, prefix in (("NGC", "NGC"), ("IC", "IC")):
        identifiers = row[column].strip()

        if not identifiers:
            continue

        for number in identifiers.split(","):
            number = number.strip()

            if number.isdigit():
                aliases.extend([
                    f"{prefix}{int(number)}",
                    f"{prefix} {int(number)}",
                ])

    other_identifiers = row["Identifiers"].strip()

    if other_identifiers:
        aliases.extend(
            identifier.strip()
            for identifier in other_identifiers.split(",")
            if identifier.strip()
        )

    return {
        "id": identifier,
        "designation": display_name(identifier),
        "category": category_for(source_type),
        "sourceType": source_type,
        "raDegrees": ra_degrees,
        "decDegrees": dec_degrees,
        "constellation": row["Const"].strip(),
        "visualMagnitude": optional_float(row["V-Mag"]),
        "majorAxisArcmin": optional_float(row["MajAx"]),
        "minorAxisArcmin": optional_float(row["MinAx"]),
        "messierNumber": messier,
        "commonNames": names,
        "aliases": ", ".join(dict.fromkeys(aliases)),
    }


def main():
    objects = {}
    skipped = 0

    for path in FILES:
        csv_text = download_text(path)

        reader = csv.DictReader(
            io.StringIO(csv_text),
            delimiter=";",
        )

        for row in reader:
            entry = parse_row(row)

            if entry is None:
                skipped += 1
                continue

            identifier = entry["id"]

            if identifier in objects:
                raise ValueError(
                    f"Duplicate catalog identifier: {identifier}"
                )

            objects[identifier] = entry

    records = sorted(
        objects.values(),
        key=lambda item: item["id"],
    )

    if len(records) < 10000:
        raise RuntimeError(
            "Catalog is unexpectedly small. "
            "Check the downloaded source files."
        )

    messier_numbers = {
        item["messierNumber"]
        for item in records
        if item["messierNumber"] is not None
    }

    if len(messier_numbers) < 100:
        raise RuntimeError(
            "Messier cross-references appear incomplete."
        )

    bundle = {
        "version": VERSION,
        "source": "OpenNGC",
        "license": "CC-BY-SA-4.0",
        "objects": records,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    OUTPUT.write_text(
        json.dumps(
            bundle,
            ensure_ascii=False,
            separators=(",", ":"),
            allow_nan=False,
        ),
        encoding="utf-8",
    )

    LICENSE_OUTPUT.write_text(
        download_text("LICENSES/CC-BY-SA-4.0.txt"),
        encoding="utf-8",
    )

    print(f"Catalog version: {VERSION}")
    print(f"Objects: {len(records)}")
    print(f"Skipped entries: {skipped}")
    print(f"Messier references: {len(messier_numbers)}")
    print(f"Output: {OUTPUT}")
    print(f"License: {LICENSE_OUTPUT}")

    for messier in (31, 42, 45):
        matches = [
            item for item in records
            if item["messierNumber"] == messier
        ]

        print(
            f"M{messier}: "
            + ", ".join(
                item["designation"] for item in matches
            )
        )


if __name__ == "__main__":
    main()
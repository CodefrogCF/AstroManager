"""Build the bundled clear, moonless zenith-based Bortle estimate grid."""

import argparse
import hashlib
import json
import math
from pathlib import Path
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.transform import from_origin
from rasterio.vrt import WarpedVRT
from rasterio.windows import Window
from scipy.signal import fftconvolve


SOURCE_SHA256 = "e6edde68952052f8c53050e2ce7082bab08ddd0e15a696f999215e2d57194c53"
DATASET_YEAR = 2024
NORTH = 75
SOUTH = -60
MODEL_CELLS_PER_DEGREE = 60
OUTPUT_CELLS_PER_DEGREE = 20
BAND_DEGREES = 5
RADIUS_KM = 300
KM_PER_DEGREE = math.pi * 6371.0088 / 180


def light_kernel(latitude):
    """Area-weighted approximation of the published First Rig zenith fit."""
    height_km = KM_PER_DEGREE / MODEL_CELLS_PER_DEGREE
    width_km = height_km * math.cos(math.radians(latitude))
    rx = math.ceil(RADIUS_KM / width_km)
    ry = math.ceil(RADIUS_KM / height_km)
    x = np.arange(-rx, rx + 1, dtype=np.float32) * width_km
    y = np.arange(-ry, ry + 1, dtype=np.float32) * height_km
    distance = np.hypot(y[:, None], x[None, :])
    # Saturate the point-source approximation below 1 km, including the
    # observer's own cell. This also avoids a singularity at its center.
    bounded = np.maximum(distance, 1)
    alpha = 2.47 * (bounded / 350) ** 0.158
    weights = np.where(distance <= RADIUS_KM, bounded**-alpha, 0)
    return weights * (width_km * height_km), rx, ry


def bortle_codes(weighted_radiance):
    """Map typical zenith brightness to First Rig's published bins."""
    zlr = np.maximum(weighted_radiance, 0) / 66.89
    brightness = 21.83 - 2.5 * np.log10(1 + zlr * 10 ** (-0.4 * (22 - 21.83)))
    # 8 represents 8–9, which the zenith fit does not distinguish.
    limits = [-21.6, -21.3, -20.4, -19.1, -18.4, -18.0]
    return np.digitize(-brightness, limits, right=True).astype(np.uint8) + 2


def model_band(grid, y, rows, latitude):
    kernel, rx, ry = light_kernel(latitude)
    start = max(0, y - ry)
    end = min(grid.height, y + rows + ry)
    raw = grid.read(1, window=Window(0, start, grid.width, end - start))
    valid = np.isfinite(raw) & (raw >= 0)
    # The stored samples of this pinned GeoTIFF match the original radiance
    # units. The raster's scale tag is intended for the OpenLandMap series.
    radiance = np.where(valid, raw, 0)
    padded = np.pad(
        radiance,
        ((start - (y - ry), y + rows + ry - end), (0, 0)),
    )
    padded = np.pad(padded, ((0, 0), (rx, rx)), mode="wrap")
    weighted = fftconvolve(padded, kernel, mode="valid")
    stride = MODEL_CELLS_PER_DEGREE // OUTPUT_CELLS_PER_DEGREE
    centers = slice(stride // 2, None, stride)
    covered = valid[y - start:y - start + rows][centers, centers]
    codes = bortle_codes(weighted[centers, centers])
    codes[~covered] = 0
    return codes


def write_entry(archive, name, content):
    # Constant ZIP metadata keeps the output reproducible.
    entry = ZipInfo(name)
    archive.writestr(entry, content, compress_type=ZIP_DEFLATED, compresslevel=9)


def generate(source, output):
    with source.open("rb") as input_file:
        digest = hashlib.file_digest(input_file, "sha256").hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError("The input does not match the documented VIIRS 2024 GeoTIFF.")
    output.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=output.parent, suffix=".tmp", delete=False) as handle:
        pending = Path(handle.name)
    try:
        with (
            rasterio.open(source) as raster,
            WarpedVRT(
                raster,
                crs="EPSG:4326",
                transform=from_origin(
                    -180,
                    NORTH,
                    1 / MODEL_CELLS_PER_DEGREE,
                    1 / MODEL_CELLS_PER_DEGREE,
                ),
                width=360 * MODEL_CELLS_PER_DEGREE,
                height=(NORTH - SOUTH) * MODEL_CELLS_PER_DEGREE,
                dtype="float32",
                nodata=-32768,
                resampling=Resampling.average,
            ) as grid,
            ZipFile(pending, "w") as archive,
        ):
            metadata = {
                "version": 1,
                "datasetYear": DATASET_YEAR,
                "north": NORTH,
                "south": SOUTH,
                "bandDegrees": BAND_DEGREES,
                "cellsPerDegree": OUTPUT_CELLS_PER_DEGREE,
                "sourceSha256": SOURCE_SHA256,
                "source": "EOG VIIRS Nighttime Lights annual average (2024); OpenLandMap, T. Hengl",
                "sourceUrl": "https://doi.org/10.5281/zenodo.17294744",
                "license": "https://creativecommons.org/licenses/by/4.0/",
                "model": "AstroManager grid based on the First Rig zenith calibration",
                "modelUrl": "https://firstrig.com/method/sky-brightness",
            }
            write_entry(archive, "metadata.json", json.dumps(metadata).encode("ascii"))
            rows = BAND_DEGREES * MODEL_CELLS_PER_DEGREE
            for index, north in enumerate(range(NORTH, SOUTH, -BAND_DEGREES)):
                codes = model_band(grid, index * rows, rows, north - BAND_DEGREES / 2)
                write_entry(archive, f"{index}.bin", codes.tobytes())
                print(f"Processed {north:+d} to {north - BAND_DEGREES:+d} degrees", flush=True)
        pending.replace(output)
    finally:
        pending.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Verified OpenLandMap VIIRS 2024 GeoTIFF")
    parser.add_argument("output", type=Path, help="Destination ZIP asset")
    args = parser.parse_args()
    generate(args.source, args.output)

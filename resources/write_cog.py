#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import urlparse
import click

from loguru import logger
import pystac 

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.shutil import copy as rio_copy
from rasterio.windows import from_bounds, Window, transform as window_transform

# Function to crop with BBOX and create COG
def rasterio_save_cog_bbox(input_tif: Path, output_tif: Path, bbox: None) -> None:

    factors = [2, 4, 8, 16, 32, 64]

    with rasterio.open(input_tif) as src:
        profile = src.profile.copy()

        if bbox is not None:
            minx, miny, maxx, maxy = bbox

            # Window in the *source CRS units* (so bbox must be in src.crs coordinates)
            win = from_bounds(minx, miny, maxx, maxy, transform=src.transform)

            # Make sure it's integer aligned and clipped to raster extent
            win = win.round_offsets().round_lengths()
            win = win.intersection(Window(0, 0, src.width, src.height))

            if win.width <= 0 or win.height <= 0:
                raise ValueError("BBOX does not intersect raster extent (empty window).")

            arr = src.read(window=win)
            new_transform = window_transform(win, src.transform)

            profile.update(
                height=int(win.height),
                width=int(win.width),
                transform=new_transform,
            )
        else:
            arr = src.read()

    if np.issubdtype(arr.dtype, np.floating):
        nan_mask = np.isnan(arr)
        if nan_mask.any():
            arr = arr.copy()
            arr[nan_mask] = 0

    profile.update(
        driver="GTiff",
        tiled=True,
        blockxsize=256,
        blockysize=256,
        compress="deflate",
        BIGTIFF="IF_NEEDED",
        count=arr.shape[0],
    )

    tmp = output_tif.with_name(output_tif.stem + "_temp.tif")
    tmp.parent.mkdir(parents=True, exist_ok=True)

    try:
        with rasterio.open(tmp, "w", **profile) as dst:
            dst.write(arr)
            dst.build_overviews(factors, Resampling.nearest)
            dst.update_tags(ns="rio_overview", resampling="nearest")

        rio_copy(
            str(tmp),
            str(output_tif),
            copy_src_overviews=True,
            driver="COG",
            compress="deflate",
            # If you want to force 256 in the final COG:
            # BLOCKSIZE=256,
        )
    finally:
        if tmp.exists():
            tmp.unlink()

@click.command(
    short_help="Tool to stagein a FLEX Product from the ESA MAAP portal",
    help="Tool to stagein (ie download and create STAC Objects) a FLEX Product from the ESA MAAP portal",
)
@click.option(
    "input_tif",
    "--input_tif",
    help="Input dir containing the STAC catalog, Item and asset *.tif",
    required=True,
)
@click.option(
    "output_tif",
    "--output_tif",
    help="Output dir where the COG and related STAC objects will be saved",
    required=True,
)
@click.option(
    "bbox",
    "--bbox",
    type=(float, float, float, float),
    help="Bounding box to use for cropping the COG output",
)
def main(input_tif, output_tif, bbox):

    logger.info(f'STARTING NOW')
    
    in_dir = Path(input_tif).resolve() 
    out_dir = Path(output_tif).resolve() 
    if bbox is not None: print(bbox)

    out_dir.mkdir(parents=True, exist_ok=True)
    
    # Read Catalog
    catalog_path = in_dir / "catalog.json"
    if not catalog_path.exists():
        raise FileNotFoundError(f"Missing catalog.json at: {catalog_path}")
    catalog = pystac.Catalog.from_file(str(catalog_path))

    # Read Item
    item_links = [link for link in catalog.links if link.rel == "item"]
    if len(item_links) != 1:
        raise ValueError(f"Expected exactly 1 item link in catalog, found {len(item_links)}")
    item_link = item_links[0]
    item_json_path = (catalog_path.parent / Path(item_link.href)).resolve()
    if not item_json_path.exists():
        raise FileNotFoundError(f"Item JSON not found at: {item_json_path}")

    item = pystac.Item.from_file(str(item_json_path))
    
    # Read Asset Tiff
    asset_key = 'TIFF'
    asset_tif = item.get_assets()[asset_key]

    tif_path = item_json_path.parent / Path(asset_tif.href)
    if not tif_path.exists():
        raise FileNotFoundError(f"TIFF asset path does not exist: {tif_path}")

    # Output dir
    out_root = out_dir / f"{in_dir.name}-cog"
    out_root.mkdir(parents=True, exist_ok=True)
    logger.info(f"Out dir created: {out_root}")

    # Copy catalog.json
    out_catalog_path = out_root / "catalog.json"
    shutil.copy2(catalog_path, out_catalog_path)

    # Copy item JSON to same relative location as in input
    rel_item_json = item_json_path.relative_to(in_dir)
    out_item_json_path = out_root / rel_item_json
    out_item_json_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(item_json_path, out_item_json_path)

    # Re-load the OUT item 
    out_item = pystac.Item.from_file(str(out_item_json_path))

    # Decide where to write the COG: alongside the output item JSON
    cog_name = f"{Path(tif_path).stem}_cog.tif"
    out_cog_path = out_item_json_path.parent / cog_name
    logger.info(f"COG will be written to: {out_cog_path}")

    # Create COG and crop with BBOX
    # rasterio_save_cog(tif_path, out_cog_path)
    rasterio_save_cog_bbox(tif_path, out_cog_path, bbox=bbox)
    
    # Update Output STAC Item
    out_item.id = f"{out_item.id}-{Path(tif_path).stem}-cog"
    logger.info(f"New item ID: {out_item.id}")

    out_asset = out_item.assets[asset_key]
    
    # Update the existing TIFF asset in-place (or you could add a new asset key)
    out_asset.href = out_cog_path.name
    out_asset.media_type = "image/tiff; application=geotiff; profile=cloud-optimized"
    out_asset.title = f"OST-processed ARD COG"
    # Keep existing roles if any; ensure "data" exists
    roles = list(out_asset.roles) if out_asset.roles else []
    if "data" not in roles:
        roles.append("data")
    out_asset.roles = roles

    # Update asset key (need to remove asset and add it with the new key)
    out_item.assets.pop(asset_key)
    new_key = "ost-ard-cog"
    out_item.add_asset(new_key, out_asset)

    # Optional: update out_item self href to match output location (handy when saving)
    out_item.set_self_href(str(out_item_json_path))

    # Save updated item
    out_item.set_self_href(str(out_item_json_path))
    out_item.save_object(dest_href=str(out_item_json_path))

    logger.info(f"Catalog copied to: {out_catalog_path}")
    logger.info(f"Item updated and saved to: {out_item_json_path}")
    logger.info(f"COG written to: {out_cog_path}")

if __name__ == "__main__":
    main()

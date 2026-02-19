#!/usr/bin/env python3
import json
import os
import shutil
import sys
from pathlib import Path
from urllib.parse import urlparse

from loguru import logger
import pystac 

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.shutil import copy as rio_copy


def rasterio_save_cog(input_tif: Path, output_tif: Path) -> None:
    factors = [2, 4, 8, 16, 32, 64]

    with rasterio.open(input_tif) as src:
        arr = src.read()
        profile = src.profile.copy()

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
        )
    finally:
        if tmp.exists():
            tmp.unlink()


def main():
    if len(sys.argv) != 3:
        print("Usage: run_me.py <input_dir> <out_dir>", file=sys.stderr)
        sys.exit(2)

    logger.info(f'STARTING NOW')
    
    in_dir = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
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

    # Create COG
    rasterio_save_cog(tif_path, out_cog_path)

    # Update Output STAC Item
    out_item.id = f"{out_item.id}-{Path(tif_path).stem}-cog"
    logger.info(f"New item ID: {out_item.id}")

    out_asset = out_item.assets[asset_key]
    
    # # Make the COG href relative to the item JSON location (recommended for portability)
    # cog_rel_href = os.path.relpath(out_cog_path, start=out_item_json_path.parent).replace("\\", "/")
    # logger.info(cog_rel_href)

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

    print(f"Catalog: {out_catalog_path}")
    print(f"Item: {out_item_json_path}")
    print(f"COG:  {out_cog_path}")

if __name__ == "__main__":
    main()

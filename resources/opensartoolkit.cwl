cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 2.1.1
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf

$graph:
  - label: OpenSarToolkit
    class: Workflow
    doc: Preprocessing an S1 image with OST
    id: opensartoolkit
    requirements: 
      NetworkAccess:
        networkAccess: true
      ScatterFeatureRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: |-
              https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    inputs:
      odata_api_endpoint:
        label: OData API endpoint
        doc: OData API endpoint
        type: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml#APIEndpoint
      search_request:
        label: STAC search request
        doc: STAC search request
        type: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml#STACSearchSettings
      resolution:
        type: int
        label: Resolution
        doc: Resolution in metres
      ard-type:
        label: ARD type
        doc: Type of analysis-ready data to produce
        type:
        - symbols:
          - OST_GTC
          - OST-RTC
          - CEOS
          - Earth-Engine
          type: enum
      with-speckle-filter:
        label: Speckle filter
        doc: Whether to apply a speckle filter
        type:
        - symbols:
          - APPLY-FILTER
          - NO-FILTER
          type: enum
      resampling-method:
        label: Resampling method
        doc: Resampling method to use
        type:
        - symbols:
          - BILINEAR_INTERPOLATION
          - BICUBIC_INTERPOLATION
          type: enum
    outputs:
      output:
        outputSource: 
          - run_script/ost_ard
        type: 
          type: array
          items: Directory
    steps:
      normalize_search_request:
        run: "#normalize_search_request"
        in:
          search_request: search_request
        out: [normalised]
      discovery:
        label: OData API discovery
        doc: Discover STAC items from a OData API endpoint based on a search request
        in:
          api_endpoint: odata_api_endpoint
          search_request: normalize_search_request/normalised
        run: https://github.com/eoap/schemas/releases/download/0.3.0/odata-client.0.3.0.cwl
        out:
          - search_output
      convert_search:
        label: Convert Search
        doc: Convert Search results to get the item self hrefs  
        in:
          search_results: discovery/search_output
          search_request: search_request
        run: "#convert-search"
        out: [items]
      stage_in:
        label: Stage-in S1 data 
        doc: Stage-in S1 data with Arvesto
        scatter: reference_ID
        in:
          reference_ID: convert_search/items
        run: "#stage-in"
        out: [staged]
      run_script:
        run: "#ost_run"
        scatter: input
        in:
          input: stage_in/staged
          resolution: resolution
          ard-type: ard-type
          with-speckle-filter: with-speckle-filter
          resampling-method: resampling-method
        out: [ost_ard]
      write_cog:
        run: "#write-cog"
        scatter: input_tif
        in:
          input_tif: run_script/ost_ard # dir containinig the OST-processed TIFF to write to COG
          search_request: search_request # for the BBOX
          #reference_ID: convert_search/items # for the reference_ID to fix the STAC Item
        out: [ost_ard_cog]

        
# =====================================
 
  - id: normalize_search_request
    class: ExpressionTool
    requirements:
    - class: InlineJavascriptRequirement
    inputs:
      search_request: Any
    outputs:
      normalised: Any
    expression: |
      ${
        const sr = inputs.search_request || {};
        const interval = sr["datetime-interval"] ?? sr.datetime_interval;
        if (interval) return { normalised: sr };

        const v = sr?.datetime?.value ?? sr?.datetime;
        if (!v) throw new Error("Provide either search_request.datetime(.value) or search_request.datetime_interval");

        const t = Date.parse(v);
        if (Number.isNaN(t)) throw new Error("Invalid datetime: " + v);

        const iso = (ms) => new Date(ms).toISOString().replace(/\.\d+Z$/, "Z");
        const out = { ...sr };
        delete out.datetime;

        out["datetime-interval"] = {
          // start: { value: iso(t - 6*864e5) },
          // end:   { value: iso(t + 6*864e5) }
          start: { value: iso(t - 1*864e5) },
          end:   { value: iso(t + 1*864e5) }

        };
        out.datetime_interval = out["datetime-interval"];
        return { normalised: out };
      }


# =====================================

  - id: convert-search
    class: CommandLineTool
    label: Gets the item self hrefs
    doc: Gets the item self hrefs from a STAC search result
    baseCommand: ["/bin/sh", "run.sh"]
    arguments: []
    hints:
      DockerRequirement:
        dockerPull: ghcr.io/eoap/zarr-cloud-native-format/yq@sha256:401655f3f4041bf3d03b05f3b24ad4b9d18cfcf908c3b44f5901383621d0688a
    requirements:
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
      - $import: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    - class: InitialWorkDirRequirement
      listing:
      - entryname: run.sh
        entry: |-
          #!/usr/bin/env sh
          set -x
          set -euo pipefail

          yq '[.features[].links[] | select(.rel=="derived_from") | .href | capture("Name%20eq%20%27(?<name>[^%]+)\\.SAFE%27") | .name]' "$(inputs.search_results.path)" > items.json

          echo "Items IDs extracted"
          cat items.json
    inputs:
      search_request:
        label: Search Request
        doc: Search request from the discovery step
        type: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml#STACSearchSettings
      search_results:
        label: Search Results
        doc: Search results from the discovery step
        type: File
    outputs:
      items:
        type:
          type: array
          items: string
        outputBinding:
          glob: items.json
          loadContents: true
          outputEval: ${ return JSON.parse(self[0].contents); }

# =====================================

  - id: stage-in
    class: CommandLineTool
    label: harvest products from CDSE
    baseCommand:
      - /bin/bash
      - arvesto.sh
    inputs:
      reference_ID:
        label: Product reference ID
        doc: Product reference ID
        type: string
    outputs:
      staged:
        label: Staged products paths
        doc: Staged products paths
        type: Directory
        outputBinding:
          glob: $(inputs.reference_ID)
          # glob: $(inputs.reference.split("/").pop().replace(".SAFE","").replace("\"",""))
    requirements:
      NetworkAccess:
        networkAccess: true
      DockerRequirement:
        dockerPull: cr.terradue.com/seda/arvesto:0.6.3-develop
      ResourceRequirement:
        coresMax: 1
        ramMax: 2000
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
        - entryname: arvesto.sh
          entry: |-
            #!/bin/bash
            set -euo pipefail
            set -ex
            
            # Extract ref and uid
            uid="${return inputs.reference_ID;}"
            echo $uid

            # CDSE creds
            export CDSE_ACCESS_KEY_ID=$CDSE_AWS_ACCESS_KEY_ID
            export CDSE_SECRET_ACCESS_KEY=$CDSE_AWS_SECRET_ACCESS_KEY
            export CDSE_SERVICE_URL=$CDSE_ENDPOINT_URL
            
            # Stagein with arvesto
            arvesto download --product $uid.SAFE --output $uid --dump-stac-catalog 
            
            # Check if the directory was created
            if [[ -d $uid/$uid/$uid.SAFE ]]; then
              echo "Directory $uid.SAFE created."
              # find $uid/$uid/$uid.SAFE -maxdepth 2 -type f
            else
              echo "Directory $uid.SAFE was not created"
            fi
            
            # Check STAC item and print
            stac_json="$uid/$uid/$uid.json"
            if [[ -f "$stac_json" ]]; then
              echo "Found STAC item: $stac_json"
            else
              echo "Missing STAC item: $stac_json"
              exit 1
            fi
            
            rm arvesto.sh
            exit 0

# =====================================

  - id: ost_run
    class: CommandLineTool
    baseCommand: ["/bin/bash", "run_me.sh"]
    arguments:
      - --wipe-cwd
    inputs:
      input:
        type: Directory
        inputBinding:
          position: 1
      resolution:
        type: int
        inputBinding:
          prefix: --resolution
      ard-type:
        type:
        - symbols:
          - OST_GTC
          - OST-RTC
          - CEOS
          - Earth-Engine
          type: enum
        inputBinding:
          prefix: --ard-type
      with-speckle-filter:
        type:
        - symbols: 
          - APPLY-FILTER
          - NO-FILTER
          type: enum
        inputBinding:
          valueFrom: |
            $(self == "APPLY-FILTER" ? "--with-speckle-filter" : null)
      resampling-method:
        type:
        - symbols:
          - BILINEAR_INTERPOLATION
          - BICUBIC_INTERPOLATION
          type: enum
        inputBinding:
          prefix: --resampling-method
      cdse-user:
        type: string?
        inputBinding:
          prefix: --cdse-user
      cdse-password:
        type: string?
        inputBinding:
          prefix: --cdse-password

    outputs:
      ost_ard:
        outputBinding:
          glob: .
        type: Directory

    requirements:
      DockerRequirement:
        dockerPull: ghcr.io/simonevaccari/opensartoolkit:1.0
      NetworkAccess:
        networkAccess: true
      ResourceRequirement:
        coresMax: 6
        ramMax: 24000
      EnvVarRequirement:
        envDef:
          INPUT_DIR: $(inputs.input.path)
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
        - entryname: run_me.sh
          entry: |-
            #!/bin/bash
            set -e  # Stop on error
            set -x  # Debug mode
            
            echo "OpenSarToolkit START"
            find .
            
            echo "--------------------------------"
            echo "Input directory path: $INPUT_DIR"
            find $INPUT_DIR
            echo "--------------------------------"
            
            # Check that manifest.safe file exists, and print full path 
            if [ \$((\$(find $INPUT_DIR -name "manifest.safe" | wc -l))) -eq 0 ]
            then
              echo "Error: manifest.safe file not found, check staged-in data. Stopping execution"
              exit 1
            fi

            found_path=\$(find "$INPUT_DIR" -name "manifest.safe" | head -n 1)
            echo "$found_path"

            echo python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"
            python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"
            
            res=$?         

            # Print dir content
            echo "Print PWD path and content: $PWD"
            echo $PWD
            ls -latr *            
                    
            echo "END of OpenSarToolkit"
            set +x
            exit $res

# =========================================

  - id: write-cog
    class: CommandLineTool
    baseCommand: ["python3", "write_cog.py"]
    inputs:
      input_tif:
        type: Directory
        inputBinding:
          prefix: --input_tif
      search_request:
        type: Any
      
      # reference_ID:
        # type: string
        # inputBinding:
        #   prefix: --reference_ID

    arguments:
      - valueFrom: |
              ${
                if (inputs.search_request && inputs.search_request.bbox && inputs.search_request.bbox.length === 4) {
                  return ["--bbox"].concat(inputs.search_request.bbox);
                }
                return [];
              }
        shellQuote: false

    outputs:
      ost_ard_cog:
        type: Directory
        outputBinding:
          glob: ost-ard-cog
        
    requirements:
      DockerRequirement:
        dockerPull: ghcr.io/simonevaccari/opensartoolkit:1.0
      NetworkAccess:
        networkAccess: true
      ResourceRequirement:
        coresMax: 6
        ramMax: 24000
      EnvVarRequirement:
        envDef:
          SEARCH_REQUEST: $(JSON.stringify(inputs.search_request))
      InlineJavascriptRequirement: {}
      InitialWorkDirRequirement:
        listing:
        - entryname: write_cog.py
          entry: |-
            #!/usr/bin/env python3
            import json
            import os
            import shutil
            import sys
            from pathlib import Path
            from urllib.parse import urlparse
            import click

            # from loguru import logger
            import pystac 

            import numpy as np
            import rasterio
            from rasterio.enums import Resampling
            from rasterio.shutil import copy as rio_copy
            from rasterio.windows import from_bounds, Window, transform as window_transform
            from rasterio.windows import bounds as window_bounds

            # Debug search_request
            print("DEBUG search_request =", os.environ.get("SEARCH_REQUEST"))

            # Function to crop with BBOX and create COG
            def rasterio_save_cog_bbox(input_tif: Path, output_tif: Path, bbox=None) -> None:

                factors = [2, 4, 8, 16, 32, 64]

                with rasterio.open(input_tif) as src:
                    profile = src.profile.copy()

                    if bbox is not None:
                        minx, miny, maxx, maxy = bbox

                        # Window in the *source CRS units* (so bbox must be in src.crs coordinates)
                        win = from_bounds(minx, miny, maxx, maxy, transform=src.transform)

                        # Make sure it is integer aligned and clipped to raster extent
                        win = win.round_offsets().round_lengths()
                        win = win.intersection(Window(0, 0, src.width, src.height))

                        if win.width <= 0 or win.height <= 0:
                            raise ValueError("BBOX does not intersect raster extent (empty window).")

                        # Compute the *actual* bounds we will write, snapped to pixels and clipped
                        out_bounds = window_bounds(win, src.transform)

                        arr = src.read(window=win)
                        new_transform = window_transform(win, src.transform)

                        profile.update(
                            height=int(win.height),
                            width=int(win.width),
                            transform=new_transform,
                        )
                    else:
                        arr = src.read()
                        out_bounds = src.bounds

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

                tmp = Path("/tmp") / (output_tif.stem + "_temp.tif")
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

                return out_bounds

            @click.command(
                short_help="Script to crop with BBOX and write to COG",
                help="Script to crop with BBOX and write to COG",
            )
            @click.option(
                "--input_tif",
                help="Input dir containing the STAC catalog, Item and asset *.tif",
                required=True,
            )
            @click.option(
                "--bbox",
                type=(float, float, float, float),
                help="Bounding box to use for cropping the COG output",
            )
            def main(input_tif, bbox):

                print(f"STARTING NOW")
                if bbox is None: print("No BBOX, no cropping")
                else: print("BBOX is provided, cropping and then creating COG")
                
                in_dir = Path(input_tif).resolve() 
                out_dir = Path.cwd().resolve() 

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
                asset_key = "TIFF"
                asset_tif = item.get_assets()[asset_key]

                tif_path = item_json_path.parent / Path(asset_tif.href)
                if not tif_path.exists():
                    raise FileNotFoundError(f"TIFF asset path does not exist: {tif_path}")

                # Output dir
                out_root = out_dir / "ost-ard-cog"
                out_root.mkdir(parents=True, exist_ok=True)
                print(f"Out dir created: {out_root}")

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
                print(f"COG will be written to: {out_cog_path}")

                # Create COG and crop with BBOX
                out_bounds = rasterio_save_cog_bbox(tif_path, out_cog_path, bbox=bbox)
                
                # Update Output STAC Item
                out_item.id = f"{out_item.id}-{Path(tif_path).stem}-cog"
                print(f"New item ID: {out_item.id}")

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

                # Update spatial fields to match output
                minx, miny, maxx, maxy = float(out_bounds[0]), float(out_bounds[1]), float(out_bounds[2]), float(out_bounds[3])
                out_item.bbox = [minx, miny, maxx, maxy]
                out_item.geometry = {
                    "type": "Polygon",
                    "coordinates": [[
                        [minx, miny],
                        [minx, maxy],
                        [maxx, maxy],
                        [maxx, miny],
                        [minx, miny],
                    ]]
                }

                # Optional: update out_item self href to match output location (handy when saving)
                out_item.set_self_href(str(out_item_json_path))

                # Save updated item
                out_item.set_self_href(str(out_item_json_path))
                out_item.save_object(dest_href=str(out_item_json_path))

                print(f"Catalog copied to: {out_catalog_path}")
                print(f"Item updated and saved to: {out_item_json_path}")
                print(f"COG written to: {out_cog_path}")

            if __name__ == "__main__":
                main()

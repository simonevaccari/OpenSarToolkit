cwlVersion: v1.2
$namespaces:
  s: https://schema.org/

schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf

# Software 
s:name: OpenSarToolkit 
s:description: Preprocessing an S1 image with OpenSarToolkit OST.
s:dateCreated: '2026-03-10'
s:license:
  '@type': s:CreativeWork
  s:identifier: CC-BY-4.0

# Discoverability and citation
s:keywords:
- CWL
- CWL Workflow
- Workflow
- Earth Observation
- Earth Observation application package
- '@type': s:DefinedTerm
  s:description: delineation
  s:name: application-type
- '@type': s:DefinedTerm
  s:description: terrain
  s:name: domain
- '@type': s:DefinedTerm
  s:inDefinedTermSet: https://gcmd.earthdata.nasa.gov/kms/concepts/concept_scheme/sciencekeywords
  s:termCode: 959f1861-a776-41b1-ba6b-d23c71d4d1eb

# Run-time environment
s:operatingSystem:
- Linux
- MacOS X
s:softwareRequirements:
- https://cwltool.readthedocs.io/en/latest/
- https://www.python.org/

# Current version of the software
s:softwareVersion: 2.1.8
s:softwareHelp:
  '@type': s:CreativeWork
  s:name: User Manual
  s:url: https://eoap.github.io/ost_v2/

# Publisher
s:publisher:
  '@type': s:Organization
  s:email: info@terradue.com
  s:identifier: https://ror.org/0069cx113
  s:name: Terradue Srl

# Authors & Contributors
s:author:
- '@type': s:Role
  s:roleName: Project Manager
  s:additionalType: http://purl.org/spar/datacite/ProjectManager
  s:author:
    '@type': s:Person
    s:affiliation:
      '@type': s:Organization
      s:identifier: https://ror.org/0069cx113
      s:name: Terradue
    s:email: fabrice.brito@terradue.com
    s:familyName: Brito
    s:givenName: Fabrice
    s:identifier: https://orcid.org/0009-0000-1342-9736

# - '@type': s:Role
#   s:roleName: Project Leader
#   s:additionalType: http://purl.org/spar/datacite/ProjectLeader
#   s:author:
#     '@type': s:Person
#     s:affiliation:
#       '@type': s:Organization
#       s:identifier: 
#       s:name: Brockmann
#     s:email: 
#     s:familyName: 
#     s:givenName: 
#     s:identifier: 
# - '@type': s:Role
#   s:roleName: Project Leader
#   s:additionalType: http://purl.org/spar/datacite/ProjectLeader
#   s:author:
#     '@type': s:Person
#     s:affiliation:
#       '@type': s:Organization
#       s:identifier: 
#       s:name: 
#     s:email: 
#     s:familyName: 
#     s:givenName: 
#     s:identifier: 

s:contributor:
- '@type': s:Role
  s:roleName: Researcher
  s:additionalType: http://purl.org/spar/datacite/Researcher
  s:contributor:
    '@type': s:Person
    s:affiliation:
      '@type': s:Organization
      s:identifier: https://ror.org/0069cx113
      s:name: Terradue
    s:email: simone.vaccari@terradue.com
    s:familyName: Vaccari
    s:givenName: Simone
    s:identifier: https://orcid.org/0000-0002-2757-4165

# CWL Workflow 

$graph:
  - label: OpenSarToolkit
    class: Workflow
    doc: Preprocessing an S1 image with OST
    id: opensartoolkit
    requirements: 
      NetworkAccess:
        networkAccess: true
      ScatterFeatureRequirement: {}
      SubworkflowFeatureRequirement: {}
      StepInputExpressionRequirement: {}
      InlineJavascriptRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    inputs:
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
      target_datetime:
        label: Target datetime
        doc: Target datetime in ISO 8601 format
        type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#DateTime
      bbox:
        label: Area of interest
        doc: AOI polygon (bbox field will be used for STAC bbox)
        type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Polygon
    outputs:
      output:
        outputSource: 
          - s1_subworkflow/ost_ard_cog
        type: 
          type: array
          items: Directory
    steps:
      build_search_request:
        run: "#build_search_request"
        label: Build search_request and add datetime-interval
        in:
          target_datetime: target_datetime
          bbox: bbox
        out: [search_request_norm]
      discovery:
        label: OData API discovery
        doc: Discover STAC items from a OData API endpoint based on a search request
        in:
          api_endpoint:
            valueFrom: |
              ${
                return {
                  headers: [],
                  url: { value: "https://catalogue.dataspace.copernicus.eu/odata/v1/Products" }
                };
              }
          search_request: build_search_request/search_request_norm
        run: "https://github.com/eoap/schemas/releases/download/0.3.0/odata-client.0.3.0.cwl"
        out:
          - search_output
      convert_search:
        run: "#convert-search"
        label: Convert Search
        doc: Convert Search results to get the item self hrefs  
        in:
          search_results: discovery/search_output
          target_datetime: target_datetime
          bbox: bbox
        out: [items]
      s1_subworkflow:
        run: "#s1_subworkflow"
        label: Sub-workflow to process searched S1 data
        doc: Sub-workflow to process searched S1 data
        scatter: reference_ID
        in:
          reference_ID: convert_search/items
          bbox:
            source: bbox
            valueFrom: $(self.bbox)
          resolution: resolution
          ard-type: ard-type
          with-speckle-filter: with-speckle-filter
          resampling-method: resampling-method
        out: [ost_ard_cog]
        
# =====================================
 
  - id: build_search_request
    class: ExpressionTool
    requirements: 
      NetworkAccess:
        networkAccess: true
      InlineJavascriptRequirement: {}
      StepInputExpressionRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    inputs:
      target_datetime:
        label: Target datetime
        doc: Target datetime in ISO 8601 format
        type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#DateTime
      bbox:
        label: Area of interest
        doc: AOI polygon (bbox field will be used for STAC bbox)
        type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Polygon
    outputs:
      search_request_norm: 
        type: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml#STACSearchSettings
    expression: |
      ${
        const dt = inputs.target_datetime?.value;
        if (!dt) throw new Error("target_datetime.value is required");

        const poly = inputs.bbox;
        const bb = poly?.bbox;
        if (!bb || !Array.isArray(bb) || bb.length !== 4) {
          throw new Error("bbox.bbox must be [minx,miny,maxx,maxy]");
        }

        // Build the base request (your fixed defaults)
        const sr = {
          collections: ["SENTINEL-1"],
          bbox: bb,
          "filter-lang": "cql2-json",
          filter: {
            op: "and",
            args: [
              {
                op: "in",
                args: [
                  { property: "productType" },
                  ["IW_GRHD_1S", "IW_GRDH_1S"]
                ]
              }
            ]
          }
        };

        // Add datetime interval (±6 days)
        const t = Date.parse(dt);
        if (Number.isNaN(t)) throw new Error("Invalid datetime: " + dt);

        const iso = (ms) => new Date(ms).toISOString().replace(/\.\d+Z$/, "Z");
        const interval = {
          start: { value: iso(t - 6 * 864e5) },
          end:   { value: iso(t + 7 * 864e5) }
        };

        sr["datetime-interval"] = interval;
        sr.datetime_interval = interval; // keep alias for compatibility

        console.error("SEARCH_REQUEST BUILT SUCCESSFULLY");
        console.error(JSON.stringify(sr, null, 2));
        
        return { search_request_norm: sr };
      }

# =====================================

  - id: convert-search
    class: CommandLineTool
    label: Gets the item self hrefs
    doc: Gets the item self hrefs from a STAC search result
    baseCommand: ["/bin/sh", "run.sh"]
    arguments: 
      - valueFrom: $(inputs.search_results.path)      
    inputs:
      target_datetime:
        label: Target datetime
        doc: Target datetime in ISO 8601 format
        type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#DateTime
      search_results:
        label: Search Results
        doc: Search results from the discovery step
        type: File
      bbox:
        label: Area of interest
        doc: AOI polygon (bbox field will be used for STAC bbox)
        type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Polygon
    outputs:
      items:
        type:
          type: array
          items: string
        outputBinding:
          glob: items.json
          loadContents: true
          outputEval: ${ return JSON.parse(self[0].contents); }

    requirements: 
      NetworkAccess:
        networkAccess: true
      InlineJavascriptRequirement: {}
      StepInputExpressionRequirement: {}
      DockerRequirement:
        # dockerPull: ghcr.io/eoap/zarr-cloud-native-format/yq@sha256:401655f3f4041bf3d03b05f3b24ad4b9d18cfcf908c3b44f5901383621d0688a
        dockerPull: python:3.11-slim
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
      EnvVarRequirement:
        envDef:
          TARGET_DATETIME: $(inputs.target_datetime.value)
          INPUT_BBOX: $(inputs.bbox.bbox.join(","))
      InitialWorkDirRequirement:
        listing:
        - entryname: run.sh
          entry: |-
            #!/usr/bin/env sh
            set -x
            set -euo pipefail

            # ==============================================================
            # Select only the best candidate, ie S1 with maximum overlap with bbox, and closest to target_date
            search_results="$1"
            input_bbox="\${2:-\${INPUT_BBOX:-}}"

            if [ -z "$input_bbox" ]; then
              echo "ERROR: input bbox not provided" >&2
              exit 1
            fi

            target_day="\$(echo "$TARGET_DATETIME" | cut -c1-10 | tr -d "-")"
            echo "Search_results: $search_results"
            echo "Target datetime: $target_day"
            echo "Input bbox: $input_bbox"
            
            # Check which python
            echo '[]' > items.json

            if command -v python3 >/dev/null 2>&1; then
              PYTHON_BIN=python3
            elif command -v python >/dev/null 2>&1; then
              PYTHON_BIN=python
            else
              echo "ERROR: neither python3 nor python found in container" >&2
              exit 1
            fi

            # install pystac and shapely
            pip install --user pystac shapely

            # Switch to python to calculate percentage of S1 products footprints over BBOX
            "$PYTHON_BIN" - "$search_results" "$TARGET_DATETIME" "$input_bbox" > items.json <<'PY'
            import json
            import re
            import sys
            from datetime import datetime, timezone

            import pystac
            from shapely.geometry import shape, box

            search_results_path = sys.argv[1]
            target_dt_str = sys.argv[2]          # e.g. 20241114T00:00:00Z
            input_bbox_str = sys.argv[3]         # e.g. 12.146,41.701,12.629,41.967

            # Parse target datetime
            target_dt = datetime.fromisoformat(target_dt_str.replace("Z", "+00:00"))

            # Build user bbox polygon
            minx, miny, maxx, maxy = map(float, input_bbox_str.split(","))
            user_geom = box(minx, miny, maxx, maxy)
            user_area = user_geom.area
            if user_area <= 0:
                raise ValueError("Input bbox has zero area")

            # Load STAC FeatureCollection
            with open(search_results_path, "r", encoding="utf-8") as f:
                fc = json.load(f)

            items = pystac.ItemCollection.from_dict(fc)

            def extract_product_name(item):
                for link in item.links:
                    if link.rel == "derived_from":
                        href = link.target if isinstance(link.target, str) else str(link.target)
                        m = re.search(r"Name%20eq%20%27([^%]+)\.SAFE%27", href)
                        if m:
                            return m.group(1)
                return item.id

            best_name = None
            best_key = None
            debug_rows = []

            for item in items.items:
                if item.geometry is None:
                    continue

                scene_geom = shape(item.geometry)
                overlap_area = scene_geom.intersection(user_geom).area
                overlap_pct = 100.0 * overlap_area / user_area

                proc_dt_str = item.properties.get("processing:datetime")
                if not proc_dt_str:
                    continue
                proc_dt = datetime.fromisoformat(proc_dt_str.replace("Z", "+00:00"))

                delta_sec = abs((proc_dt - target_dt).total_seconds())

                name = extract_product_name(item)

                # highest overlap first, then closest datetime
                key = (-overlap_pct, delta_sec, proc_dt.isoformat(), name)

                debug_rows.append({
                    "name": name,
                    "overlap_pct": round(overlap_pct, 6),
                    "processing_datetime": proc_dt.isoformat(),
                    "delta_sec": delta_sec,
                })

                if best_key is None or key < best_key:
                    best_key = key
                    best_name = name

            print(json.dumps([best_name] if best_name else []))
            print(json.dumps(debug_rows, indent=2), file=sys.stderr)
            PY

            echo "Selected item(s):"
            cat items.json

# =====================================

  - id: s1_subworkflow
    label: Sub-workflow to process searched S1 data
    class: Workflow
    doc: Stage-in, OST processing, creation of COG
    
    requirements: 
      NetworkAccess:
        networkAccess: true
      InlineJavascriptRequirement: {}
      StepInputExpressionRequirement: {}
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/ogc.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    inputs:
      reference_ID:
        label: Product reference ID
        type: string
      bbox:
        label: Bounding Box
        doc: Bounding box [minx, miny, maxx, maxy] in the raster CRS
        type:
          - "null"
          - type: array
            items: double
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
      ost_ard_cog:
        outputSource: write_cog/ost_ard_cog
        type: Directory
    steps:
      stage_in:
        label: Stage-in S1 data 
        doc: Stage-in S1 data with Arvesto
        in:
          reference_ID: reference_ID
        run: "#stage-in"
        out: [staged]
      run_script:
        run: "#ost_run"
        in:
          input: stage_in/staged
          resolution: resolution
          ard-type: ard-type
          with-speckle-filter: with-speckle-filter
          resampling-method: resampling-method
        out: [ost_ard]
      write_cog:
        run: "#write-cog"
        in:
          input_tif: run_script/ost_ard # dir containinig the OST-processed TIFF to write to COG
          bbox: bbox
          reference_ID: reference_ID # for the reference_ID to fix the STAC Item
        out: [ost_ard_cog]

# ======================================

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
        dockerPull: cr.terradue.com/eo-services/opensartoolkit:1.0.0
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
        label: Input TIFF file
        type: Directory
        inputBinding:
          prefix: --input_tif
      reference_ID:
        label: Product reference ID
        type: string
        inputBinding:
          prefix: --reference-id
      bbox:
        label: Bounding Box
        doc: Bounding box [minx, miny, maxx, maxy] in the raster CRS
        type: 
          - "null"
          - type: array
            items: double
        inputBinding:
          prefix: --bbox
          separate: true

    outputs:
      ost_ard_cog:
        type: Directory
        outputBinding:
          glob: $(inputs.reference_ID + "-COG")
        
    requirements:
      DockerRequirement:
        dockerPull: cr.terradue.com/eo-services/opensartoolkit:1.0.0
      NetworkAccess:
        networkAccess: true
      ResourceRequirement:
        coresMax: 6
        ramMax: 24000
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
                "--reference-id",
                "reference_id",
                help="Reference ID",
                required=True,
            )
            @click.option(
                "--bbox",
                type=(float, float, float, float),
                help="Bounding box to use for cropping the COG output",
            )
            def main(input_tif, reference_id, bbox):

                print(f"Start processing: {reference_id}")
                
                # BBOX check
                if bbox is not None and len(bbox) != 4:
                    raise ValueError("bbox must have 4 elements: minx miny maxx maxy")
                if bbox is None: 
                    print("No BBOX, no cropping")
                else: 
                    print("BBOX is provided, cropping and then creating COG")
                
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
                bundle_name = f"{reference_id}-COG"
                out_root = Path.cwd().resolve() / bundle_name
                out_root.mkdir(parents=True, exist_ok=True)
                
                # Directory + JSON base name (matches your example)
                out_item_dir = out_root / bundle_name
                out_item_dir.mkdir(parents=True, exist_ok=True)

                out_item_json_path = out_item_dir / f"{bundle_name}.json"
                tif_fname = "ost-ard-cog" 
                out_cog_path = out_item_dir / f"{tif_fname}.tif"

                # Set path of catalog
                out_catalog_path = out_root / "catalog.json"
                
                print(f"Bundle root: {out_root}")
                print(f"Catalog: {out_catalog_path}")
                print(f"Out item dir: {out_item_dir}")
                print(f"Out item JSON: {out_item_json_path}")
                print(f"Out COG: {out_cog_path}")

                # --- Create COG (cropped or full) ---
                out_bounds = rasterio_save_cog_bbox(tif_path, out_cog_path, bbox=bbox)

                # --- Build output STAC Item ---
                # Start from the original item object, but rewrite it for the new structure
                out_item = item.clone()

                # 1) Set item id 
                out_item.id = bundle_name
                print(f"New item ID: {out_item.id}")

                # 2) Ensure self href points to the new JSON path
                out_item.set_self_href(str(out_item_json_path))

                # 3) Build a new asset for the COG
                cog_asset = pystac.Asset(
                    href=out_cog_path.name,  # relative inside item dir
                    media_type="image/tiff; application=geotiff; profile=cloud-optimized",
                    title="OST-processed ARD COG",
                    roles=["data", "visual"],
                )

                # Replace assets with only the COG (optional, but keeps things clean)
                out_item.assets = {}
                out_item.add_asset(tif_fname, cog_asset)

                # 4) Update spatial fields to match output bounds (cropped or full)
                minx, miny, maxx, maxy = map(float, out_bounds)
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

                # --- Build output Catalog with correct link to the new item ---
                out_catalog = pystac.Catalog(
                    id="ost-ard-cog-catalog",
                    description="OST ARD COG output",
                )

                # Set correct hrefs 
                out_catalog.set_self_href(str(out_catalog_path))
                out_item.set_self_href(str(out_item_json_path))

                out_catalog.add_item(out_item)

                # Save catalog + item
                out_catalog.save(catalog_type=pystac.CatalogType.SELF_CONTAINED)

                print(f"Catalog written to: {out_catalog_path}")
                print(f"Item written to: {out_item_json_path}")
                print(f"COG written to: {out_cog_path}")


            if __name__ == "__main__":
                main()

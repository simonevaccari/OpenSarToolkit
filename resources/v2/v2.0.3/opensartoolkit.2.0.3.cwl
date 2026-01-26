cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 2.0.3
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf

$graph:
  - class: Workflow
    label: OpenSarToolkit
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
      start_date:
        doc: Start date for the  Sentinel-1 products search expressed in ISO format yyyy-MM-ddTHH:mm:ssZ
        label: Start date for the Sentinel-1 products search
        type: string
      end_date:
        doc: End date for the Sentinel-1 products search expressed in ISO format yyyy-MM-ddTHH:mm:ssZ
        label: End date for the Sentinel-1 products search
        type: string
      aoi:
        doc: Area of interest for the  Sentinel-1 products search (WKT format)
        label: Area of interest for the  Sentinel-1 products search (WKT format)
        type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Polygon
      orbit_direction:
        doc: Orbit direction for the  Sentinel-1 products search
        label: Orbit direction for the  Sentinel-1 products search
        type:
        - symbols:
          - ASCENDING
          - DESCENDING
          type: enum
      track_number:
        label: Track number for the  Sentinel-1 products search
        doc: Track number for the  Sentinel-1 products search
        type: float?
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
        
      s1_search_step:
        label: Search S1 data on OData
        doc: Search S1 data on OData
        in:
          start_date: start_date
          end_date: end_date
          aoi: aoi
          orbit_direction: orbit_direction
          track_number: track_number
        run: "#s1_search"
        out: [s1_searched]

      stage_in:
        label: Stage-in S1 data 
        doc: Stage-in S1 data with Arvesto
        scatter: reference
        in:
          reference: s1_search_step/s1_searched
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

# =====================================

  - class: CommandLineTool
    baseCommand: ["/bin/bash", "s1_search.sh"]
    id: s1_search
    stdout: message
    inputs:
      start_date:
        doc: Start date for the  Sentinel-1 products search expressed in ISO format yyyy-MM-ddTHH:mm:ssZ
        label: Start date for the Sentinel-1 products search
        #type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#Datetime
        type: string
      end_date:
        doc: End date for the Sentinel-1 products search expressed in ISO format yyyy-MM-ddTHH:mm:ssZ
        label: End date for the Sentinel-1 products search
        #type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#Datetime
        type: string
      aoi:
        doc: Area of interest for the  Sentinel-1 products search (WKT format)
        label: Area of interest for the  Sentinel-1 products search (WKT format)
        type: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml#Polygon
      orbit_direction:
        doc: Orbit direction for the  Sentinel-1 products search
        label: Orbit direction for the  Sentinel-1 products search
        type:
        - symbols:
          - ASCENDING
          - DESCENDING
          type: enum
      track_number:
        label: Track number for the  Sentinel-1 products search
        doc: Track number for the  Sentinel-1 products search
        type: float?
    arguments:
    - valueFrom: |
        ${
          function geoJSONToWktPolygon(geojson) {
            if (!geojson || geojson.type !== "Polygon") {
              throw new Error("Input must be a GeoJSON Polygon");
            }

            // GeoJSON Polygon: coordinates = [ ring1, ring2, ... ]
            // Use the first ring (outer ring)
            var ring = geojson.coordinates[0];

            // Convert each [lon, lat] pair to "lon lat"
            var points = ring.map(function(coord) {
              return coord[0] + " " + coord[1];
            });

            return "POLYGON((" + points.join(", ") + "))";
          }

          return geoJSONToWktPolygon(inputs.aoi);
        }
    outputs:
      s1_searched:
        doc: References of the selected Sentinel-1 products
        label: References of the selected Sentinel-1 products
        type: 
          - string[]
          #- type: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml#URI
        outputBinding:
          glob: message
          loadContents: true
          outputEval: $(self[0].contents.split("\n").slice(0,-1))
    requirements:
    - class: DockerRequirement
      dockerPull: docker.io/python:3.9.9-slim-bullseye
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
        - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
        - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
    - class: NetworkAccess
      networkAccess: true
    - class: InitialWorkDirRequirement
      listing:
        - entryname: s1_search.sh
          entry: |-
            #!/bin/bash
            set -x
            pip3 install pystac requests shapely loguru > /dev/null 2>&1
            #aoi="${return inputs.aoi;}"
            aoi="$@"
            start_date="${return inputs.start_date;}"
            end_date="${return inputs.end_date;}"
            orbit_direction="${return inputs.orbit_direction;}"
            track_number="${return inputs.track_number;}"
            python prod_search.py $CDSE_ENDPOINT $CDSE_COLLECTION "\${start_date}" "\${end_date}" "\${aoi}" \${orbit_direction} \${track_number}> output.list
            res=$?
            [[ \${res} == 0 ]] && cat output.list
            exit \${res}
        - entryname: prod_search.py
          entry: |-
            import os
            import pystac
            import requests
            import sys
            from collections import defaultdict
            from datetime import datetime
            from loguru import logger
            from shapely.geometry import shape, mapping
            from shapely import wkt

            def filter_by_footprint(references_objs,aoi_polygon):
                out_refs=[]
                i=0
                for ref_obj in references_objs:
                    polygon=shape(ref_obj["geom"])
                    intersecion_area = aoi_polygon.intersection(polygon).area
                    int_area_perc = (intersecion_area/aoi_polygon.area)*100.0
                    ref_obj_id=ref_obj["id"]
                    #logger.info(f"{ref_obj_id} intersection area: {int_area_perc}")
                    if int_area_perc > 30:
                        #i=i+1
                        #logger.info(f"{i} - Adding {ref_obj_id}")
                        out_refs.append(ref_obj_id)

                logger.debug(f"Returning {len(out_refs)}")
                return out_refs

            def get_items_from_odata_catalog(request_url):
                  response = requests.get(request_url)
                  response.raise_for_status()  # Raise an error for HTTP error codes
                  data = response.json()
                  #logger.debug(data["value"][0]["GeoFootprint"])
                  refs = [
                      (lambda meta: {
                          "id": item["Name"],
                          "geom": item["GeoFootprint"],
                          "orbit_n": meta["relativeOrbitNumber"],
                          "orbit_d": meta["orbitDirection"],
                          "date": meta["beginningDateTime"].split("T")[0],
                          #"slice": meta["sliceNumber"],
                      })({attrs["Name"]: attrs["Value"] for attrs in item["Attributes"]})
                      for item in data["value"]
                  ]
                  refs_id = [ref["id"] for ref in refs]
                  logger.info(f"Retrieved {len(refs_id)} products")
                  return refs

            def get_odata_query_url(base_url,collection,start_dt,end_dt,aoi,orbit_direction,track_number):
                  product_type_filter = f"and%20(Attributes/OData.CSC.StringAttribute/any(att:att/Name%20eq%20%27productType%27%20and%20att/OData.CSC.StringAttribute/Value%20eq%20%27GRD%27))"
                  collection_filter = f"Collection/Name%20eq%20%27{collection}%27"
                  content_filter = f"and%20ContentDate/Start%20gt%20{start_dt}%20and%20ContentDate/End%20lt%20{end_dt}"
                  track_n_filter = f"and%20(Attributes/OData.CSC.IntegerAttribute/any(att:att/Name%20eq%20%27relativeOrbitNumber%27%20and%20att/OData.CSC.IntegerAttribute/Value%20eq%20{track_number}))"
                  orbit_d_filter = f"and%20(Attributes/OData.CSC.StringAttribute/any(att:att/Name%20eq%20%27orbitDirection%27%20and%20att/OData.CSC.StringAttribute/Value%20eq%20%27{orbit_direction}%27))"
                  aoi = aoi.replace(" ","%20")
                  intersect_filter = f"and%20OData.CSC.Intersects(area=geography%27SRID=4326;{aoi}%27)"
                  filter_string = "%20".join(
                      part
                      for part in [
                          collection_filter,
                          content_filter,
                          product_type_filter,
                          intersect_filter,
                          orbit_d_filter,
                          track_n_filter
                      ]
                  )
                  logger.debug(f"ODATA URL: {base_url}?\$filter={filter_string}&\$expand=Attributes")
                  return f"{base_url}?$filter={filter_string}&$expand=Attributes&$top=1000"

            def get_prod_list_from_odata(catalog_source, collection, aoi, start_dt, end_dt, orbit_direction, track_number):
                # Looking for product in the time range [start_dt, end_dt]
                logger.info(f"Looking for products in {start_dt}/{end_dt})")
                query_url = get_odata_query_url(catalog_source,collection,start_dt,end_dt,aoi,orbit_direction,track_number)
                references = get_items_from_odata_catalog(query_url)
                references_id = [ref["id"]for ref in references]
                logger.info(f"s1_references full list: {references_id}")
                logger.info("Filtering by intersection with AOI")
                polygon = wkt.loads(aoi)
                filtered = filter_by_footprint(references,polygon)
                logger.info(f"references filtered by AOI intersection: {len(filtered)}")
                return filtered

            query_endpoint = sys.argv[1]
            collection = sys.argv[2]
            start_date = sys.argv[3]
            end_date = sys.argv[4]
            aoi = sys.argv[5]
            orbit_direction = sys.argv[6]
            track_number = int(sys.argv[7])

            if "T" not in start_date:
                start_date = f"{start_date}T00:00:00Z"
            if "T" not in end_date:
                end_date = f"{end_date}T23:59:59Z"

            logger.info(f"Looking for products in {start_date} - {end_date}")
            prod_uids = get_prod_list_from_odata(
                query_endpoint,
                collection,
                aoi,
                start_date,
                end_date,
                orbit_direction,
                track_number
            )
            if len(prod_uids) >= 1:
                logger.info("Returning:")
                for uid in prod_uids:
                    logger.info(f"{uid}")
                    print(f"{uid}")
            else:
                logger.info(f"No Sentinel-1 products found.")
                sys.exit(1)

# =====================================

  - class: CommandLineTool
    label: harvest products from CDSE
    id: stage-in
    baseCommand:
      - /bin/bash
      - arvesto.sh
    inputs:
      reference:
        label: Product reference
        doc: Product reference
        type: string
    outputs:
      staged:
        label: Staged products paths
        doc: Staged products paths
        type: Directory
        outputBinding:
          glob: $(inputs.reference.split("/").pop().replace(".SAFE","").replace("\"",""))
          # glob: "S1A_IW_GRDH_1SDV_20241113T170607_20241113T170632_056539_06EEA8_B145" # hard-coded native file
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
              ref="${return inputs.reference;}"
              uid="\${ref%.SAFE}" 
              echo $ref
              echo $uid
              
              # CDSE creds
              export CDSE_ACCESS_KEY_ID=$CDSE_AWS_ACCESS_KEY_ID
              export CDSE_SECRET_ACCESS_KEY=$CDSE_AWS_SECRET_ACCESS_KEY
              export CDSE_SERVICE_URL=$CDSE_ENDPOINT_URL
              
              # Stagein with arvesto
              arvesto download --product $uid.SAFE --output $uid --dump-stac-catalog 
              # arvesto download --product $uid.SAFE --output $uid --dump-stac-catalog # asset -da 
              
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

  - class: CommandLineTool
    id: ost_run
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
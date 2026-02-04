$graph:
- class: CommandLineTool
  id: ost_script_1
  baseCommand: ["/bin/bash", "run_me.sh"]
  arguments: []
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
        type: enum
      inputBinding:
        prefix: --ard-type
    with-speckle-filter:
      type: boolean
      inputBinding:
        prefix: --with-speckle-filter
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
    dry-run:
      type: boolean
      inputBinding:
        prefix: --dry-run
  outputs:
    ost_ard:
      outputBinding:
        glob: .
      type: Directory

  requirements:
    DockerRequirement:
      dockerPull: quay.io/bcdev/opensartoolkit:version3
    ResourceRequirement:
      coresMax: 4
      ramMax: 16000
    InlineJavascriptRequirement: {}
    InitialWorkDirRequirement:
      listing:
        - entryname: run_me.sh
          entry: |-
            #!/bin/bash
            set -e  # Stop on error
            set -x  # Debug mode

            echo "OpenSarToolkit START"

            # python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"

            # res=$?

            # # Delete unnecessary files
            # echo "Deleting unnecessary files"
            # find ./ -mindepth 1 -maxdepth 1 -type d ! -name "result-item" ! -name "." -exec rm -rf {} +
            # rm -f processing.json .install4j run_me.sh

            # # Move tif into "result-item" sub-dir
            # mv *.tif result-item/

            # # Define STAC file 
            # STAC_FILE="result-item/result-item.json"
            
            # # Replace string of TIFF asset's href 
            # sed -i 's#\.\./\([0-9]\+\)\.tif#./\1.tif#g' $STAC_FILE
            
            # Create dummy STAC Catalog and Item for testing validation
            cat << EOF > catalog.json
            {
              "type": "Catalog",
              "id": "catalog",
              "stac_version": "1.0.0",
              "description": "Root catalog",
              "links": [
                {
                  "rel": "root",
                  "href": "./catalog.json",
                  "type": "application/json"
                },
                {
                  "rel": "item",
                  "href": "./result-item/result-item.json",
                  "type": "application/json"
                }
              ]
            }
            EOF

            mkdir result-item
            touch result-item/20241113.tif

            cat << EOF > result-item/result-item.json
            {
              "type": "Feature",
              "stac_version": "1.0.0",
              "id": "result-item",
              "properties": {
                "start_datetime": "2024-11-13T17:06:07Z",
                "end_datetime": "2024-11-13T17:06:32Z",
                "datetime": null
              },
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [10.708008018233109,40.93290373077535],
                    [10.708008018233109,42.83984741590427],
                    [14.192573005332733,42.83984741590427],
                    [14.192573005332733,40.93290373077535],
                    [10.708008018233109,40.93290373077535]
                  ]
                ]
              },
              "links": [
                {
                  "rel": "root",
                  "href": "../catalog.json",
                  "type": "application/json"
                },
                {
                  "rel": "parent",
                  "href": "../catalog.json",
                  "type": "application/json"
                }
              ],
              "assets": {
                "TIFF": {
                  "title":"OST-processed",
                  "href": "./20241113.tif",
                  "type": "image/tiff; application=geotiff;",
                  "roles": [
                    "data", "visual"
                  ],
                  "gsd":60      
                }
              },
              "bbox": [
                10.708008018233109,
                40.93290373077535,
                14.192573005332733,
                42.83984741590427
              ],
              "stac_extensions": []
            }
            EOF

            echo "Validating STAC Item"
            pip install pystac
            pystac validate result-item/result-item.json

            # Print dir content
            echo $PWD
            ls -latr *
            
            echo "END of OpenSarToolkit"
            exit $res

- class: Workflow
  label: OpenSarToolkit
  doc: Preprocessing an S1 image with OST
  id: opensartoolkit
  requirements: 
    NetworkAccess:
      networkAccess: true
  inputs:
    input:
      type: Directory
      label: Input S1 GRD
      loadListing: no_listing
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
        type: enum
    with-speckle-filter:
      type: boolean
      label: Speckle filter
      doc: Whether to apply a speckle filter
    resampling-method:
      label: Resampling method
      doc: Resampling method to use
      type:
      - symbols:
        - BILINEAR_INTERPOLATION
        - BICUBIC_INTERPOLATION
        type: enum
    dry-run:
      type: boolean
      label: Dry run
      doc: Skip processing and write a placeholder output file instead

  outputs:
    stac_catalog:
      outputSource: run_script/ost_ard
      type: Directory

  steps:
    run_script:
      run: "#ost_script_1"
      in:
        input: input
        resolution: resolution
        ard-type: ard-type
        with-speckle-filter: with-speckle-filter
        resampling-method: resampling-method
        dry-run: dry-run
      out:
        - ost_ard

$namespaces:
  s: https://schema.org/
cwlVersion: v1.2
s:softwareVersion: 1.0.5
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf
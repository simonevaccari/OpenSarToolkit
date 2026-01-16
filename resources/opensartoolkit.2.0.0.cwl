cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 2.0.0
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
      SchemaDefRequirement:
        types:
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
          - $import: |-
              https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
          - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
    inputs:
      stac_api_endpoint:
        label: STAC API endpoint
        doc: STAC API endpoint
        type: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml#APIEndpoint
      search_request:
        label: STAC search request
        doc: STAC search request
        type: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml#STACSearchSettings

      # input:
      #   type: Directory
      #   label: Input S1 GRD
      #   loadListing: no_listing
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
        type: Directory

    steps:
      discovery:
        label: STAC API discovery
        doc: Discover STAC items from a STAC API endpoint based on a search request
        in:
          api_endpoint: stac_api_endpoint
          search_request: search_request
        run: https://github.com/eoap/schemas/releases/download/0.2.0/stac-api-client.0.2.0.cwl
        out:
          - search_output
      
      convert_search:
        label: Convert Search
        doc: Convert Search results to get the item self hrefs  
        in:
          search_results: discovery/search_output
          search_request: search_request
        run: "#convert-search"
        out:
          - items

      # stagein step?! 
      
      run_script:
        run: "#ost_run"
        in:
          input: convert_search/items
          resolution: resolution
          ard-type: ard-type
          with-speckle-filter: with-speckle-filter
          resampling-method: resampling-method
        out:
          - ost_ard


  - class: CommandLineTool
    id: convert-search
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

          yq '[.features[].links[] | select(.rel=="self") | .href]' "$(inputs.search_results.path)" > items.json
          cat items.json
          echo "Items href extracted"

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
        type: Any
        outputBinding:
          glob: items.json
          loadContents: true
          outputEval: ${ return JSON.parse(self[0].contents); }

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
        dockerPull: ghcr.io/simonevaccari/opensartoolkit:0.4
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



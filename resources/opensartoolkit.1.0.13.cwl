cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 1.0.13
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf

$graph:
- class: CommandLineTool
  id: ost_script_1
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
      type: boolean?
      inputBinding:
        prefix: --dry-run
  outputs:
    ost_ard:
      outputBinding:
        glob: .
      type: Directory

  requirements:
    DockerRequirement:
      dockerPull: quay.io/bcdev/opensartoolkit:version5
    NetworkAccess:
      networkAccess: true
    ResourceRequirement:
      coresMax: 4
      ramMax: 16000
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
            ls -latr *
            
            echo "Input directory path: $INPUT_DIR"
            
            # Check that manifest.safe file exists, and print full path 
            if [ \$((\$(find $INPUT_DIR -name "manifest.safe" | wc -l))) -eq 0 ]
            then
              echo "Error: manifest.safe file not found, check staged-in data. Stopping execution"
              exit 1
            fi

            found_path=\$(find "$INPUT_DIR" -name "manifest.safe" | head -n 1)
            echo "$found_path"

            # Extract Sentinel-1 ID  
            s1_id=\$(basename "\$(dirname "$found_path")")
            s1_id="\${s1_id%.SAFE}"
            echo "$s1_id"

            # check if Sentinel-1 ID appears twice in found_path (ie execution on GEP)
            count=\$(grep -o "$s1_id" <<< "$found_path" | wc -l)
            echo "$count"

            # if data has been staged-in in GEP: then append S1 ID to the input path 
            if [[ "$count" -eq 2 ]]; then
              echo "properly staged-in (from GEP)"
              echo python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"/"$s1_id"
              python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"/"$s1_id"

            else
              # else do nothing (ie launch the python command as it is)
              echo "inproper staged-in (manual?)"
              echo python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"
              python3 /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py "$@"
            fi 

            res=$?         

            # Print dir content
            echo $PWD
            ls -latr *
            
            echo "END of OpenSarToolkit"
            set +x
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
        - CEOS
        - Earth-Engine
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

  outputs:
    output:
      outputSource: 
        - run_script/ost_ard
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
      out:
        - ost_ard
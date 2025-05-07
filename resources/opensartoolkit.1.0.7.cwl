cwlVersion: v1.2
$namespaces:
  s: https://schema.org/
s:softwareVersion: 1.0.7
schemas:
- http://schema.org/version/9.0/schemaorg-current-http.rdf

$graph:
- class: CommandLineTool
  id: ost_script_1
  requirements:
    DockerRequirement:
      dockerPull: quay.io/bcdev/opensartoolkit:version5
    NetworkAccess:
      networkAccess: true
    ResourceRequirement:
      coresMax: 4
      ramMax: 16000
  baseCommand:
    - python3
    - /usr/local/lib/python3.8/dist-packages/ost/app/preprocessing.py
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
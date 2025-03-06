cwlVersion: v1.0
baseCommand: Stars
doc: "Run Stars for staging results"
class: CommandLineTool
hints:
  DockerRequirement:
    dockerPull: ghcr.io/terradue/stars:2.13.0
id: stars
arguments:
  - copy
  - -v
  - -r
  - '4'
  - -o
  - $( inputs.ADES_STAGEOUT_OUTPUT + "/" + inputs.process )
  - -res
  - $( inputs.process + ".res" )
  - "./res_test/catalog.json"
inputs: 
  ADES_STAGEOUT_AWS_PROFILE:
    type: string?
  ADES_STAGEOUT_AWS_SERVICEURL: 
    type: string?
  ADES_STAGEOUT_AWS_ACCESS_KEY_ID: 
    type: string?
  ADES_STAGEOUT_AWS_SECRET_ACCESS_KEY: 
    type: string?
  aws_profiles_location:
    type: File?
  ADES_STAGEOUT_OUTPUT:
    type: string?
  ADES_STAGEOUT_AWS_REGION:
    type: string?
  process:
    type: string?
outputs: 
  StacCatalogUri:
    outputBinding:
      outputEval: ${  return inputs.ADES_STAGEOUT_OUTPUT + "/" + inputs.process + "/catalog.json"; }
    type: string
requirements:
  InitialWorkDirRequirement:
    listing:
    - entryname: stageout.sh
      entry: |-
        #!/bin/bash
        export AWS__ServiceURL=$(inputs.ADES_STAGEOUT_AWS_SERVICEURL)
        export AWS__Region=$(inputs.ADES_STAGEOUT_AWS_REGION)
        export AWS__AuthenticationRegion=$(inputs.ADES_STAGEOUT_AWS_REGION)
        export AWS_ACCESS_KEY_ID=$(inputs.ADES_STAGEOUT_AWS_ACCESS_KEY_ID)
        export AWS_SECRET_ACCESS_KEY=$(inputs.ADES_STAGEOUT_AWS_SECRET_ACCESS_KEY)
        Stars $@
  InlineJavascriptRequirement: {}
  EnvVarRequirement:
    envDef:
      PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      # AWS__Profile: $(inputs.ADES_STAGEOUT_AWS_PROFILE)
      # AWS__ProfilesLocation: $(inputs.aws_profiles_location.path)
      AWS__ServiceURL: $(inputs.ADES_STAGEOUT_AWS_SERVICEURL)
      AWS__Region: $(inputs.ADES_STAGEOUT_AWS_REGION)
      AWS__AuthenticationRegion: $(inputs.ADES_STAGEOUT_AWS_REGION)
      AWS_ACCESS_KEY_ID: $(inputs.ADES_STAGEOUT_AWS_ACCESS_KEY_ID)
      AWS_SECRET_ACCESS_KEY: $(inputs.ADES_STAGEOUT_AWS_SECRET_ACCESS_KEY)
  ResourceRequirement: {}


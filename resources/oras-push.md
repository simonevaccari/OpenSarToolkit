# OpenSarToolkit - `ORAS` push

Command to push an App Package CWL to cr.terradue.com (based on the CI example [here](https://git.terradue.com/eo-services/get-it/ingv-gpuflow/-/blob/develop/.gitlab-ci.yml#L284). 

## `oras` command to push the app package CWL

```bash
oras push \
          cr.terradue.com/app-packages/terradue/opensartoolkit:2.1.2 \
          /workspace/APEx/OpenSarToolkit/resources/cwl-workflow/opensartoolkit.2.1.2.cwl:application/vnd.commonworkflowlanguage.cwl \
          --artifact-type application/vnd.commonworkflowlanguage.cwl \
          --annotation org.opencontainers.image.usedImages=ghcr.io/simonevaccari/opensartoolkit:1.0 \
          --annotation org.opencontainers.image.version="2.1.2" \
          --annotation org.opencontainers.image.source="https://github.com/simonevaccari/OpenSarToolkit.git"
```
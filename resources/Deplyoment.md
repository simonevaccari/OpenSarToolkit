# OpenSarToolkit - Deployment

Commands to: 

* push an App Package CWL to cr.terradue.com (based on the CI example [here](https://git.terradue.com/eo-services/get-it/ingv-gpuflow/-/blob/develop/.gitlab-ci.yml#L284), using on `oras`.
* create the manifest while checking CWL validation, using `calrimate.

## `oras` command to push the app package CWL

```bash
cd /workspace
oras push \
          cr.terradue.com/app-packages/terradue/opensartoolkit:2.1.3 \
          APEx/OpenSarToolkit/resources/cwl-workflow/opensartoolkit.2.1.3.cwl:application/vnd.commonworkflowlanguage.cwl \
          --artifact-type application/vnd.commonworkflowlanguage.cwl \
          --annotation org.opencontainers.image.usedImages=ghcr.io/simonevaccari/opensartoolkit:1.0 \
          --annotation org.opencontainers.image.version="2.1.3" \
          --annotation org.opencontainers.image.source="https://github.com/simonevaccari/OpenSarToolkit.git"
```

## `calrimate` command to validate the CWL 
```bash
cd /workspace/calrimate
calrimate developer -r /workspace/APEx/OpenSarToolkit/resources/recipe-standard.frequency.mate.yaml \
    -cwl "file:///workspace/APEx/OpenSarToolkit/resources/cwl-workflow/opensartoolkit.2.1.2.cwl" \
    -e opensartoolkit \
    -sync 15 \
    -cc /workspace/APEx/OpenSarToolkit/resources/cluster-config.opensartoolkit.mate.yaml \
    --label mate-api-enabled="true" \
    --label workspace="geohazards" \
    -ns geohazards \
    --odata_api_endpoint \
    --search_request \
    --resolution \
    --ard-type \
    --with-speckle-filter \
    --resampling-method \
    --stdout > opensartoolkit_manifest.yaml
```

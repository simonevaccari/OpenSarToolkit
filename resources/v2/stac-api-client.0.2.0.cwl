cwlVersion: v1.2
class: CommandLineTool
id: stac-client
label: STAC Client Tool
doc: |
  This tool uses the STAC Client to search for STAC items
hints:
  - class: DockerRequirement
    dockerPull: ghcr.io/eoap/schemas/stac-api-client@sha256:a7e346f704836d07f5dabc6b29ee3359e7253f4a294d74f3899973b8920da6f7
requirements:
  - class: InlineJavascriptRequirement
  - class: NetworkAccess
    networkAccess: true
  - class: SchemaDefRequirement
    types:
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/string_format.yaml
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/geojson.yaml
      - $import: |-
          https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml
      - $import: https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml
inputs:
  api_endpoint:
    label: STAC API endpoint
    doc: STAC API endpoint for Landsat-9 data
    type: |-
      https://raw.githubusercontent.com/eoap/schemas/main/experimental/api-endpoint.yaml#APIEndpoint
  search_request:
    label: STAC API settings
    doc: STAC API settings for Landsat-9 data
    type: |-
      https://raw.githubusercontent.com/eoap/schemas/main/experimental/discovery.yaml#STACSearchSettings
outputs:
  search_output:
    type: File
    outputBinding:
      glob: discovery-output.json
baseCommand: ["stac-client"]
arguments:
  - "search"
  - $(inputs.api_endpoint.url.value)
  - ${ const args = []; const collections = inputs.search_request.collections; args.push('--collections', collections.join(",")); return args; }
  - ${ const args = []; const bbox = inputs.search_request?.bbox; if (Array.isArray(bbox) && bbox.length >= 4) { args.push('--bbox', ...bbox.map(String)); } return args; }
  - ${ const args = []; const limit = inputs.search_request?.limit; args.push("--limit", (limit ?? 10).toString()); return args; }
  - ${ const maxItems = inputs.search_request?.['max-items']; return ['--max-items', (maxItems ?? 20).toString()]; }
  - ${ const args = []; const filter = inputs.search_request?.filter; const filterLang = inputs.search_request?.['filter-lang']; if (filterLang) { args.push('--filter-lang', filterLang); } if (filter) { args.push('--filter', JSON.stringify(filter)); } return args; }
  - ${ const datetime = inputs.search_request?.datetime; const datetimeInterval = inputs.search_request?.datetime_interval; if (datetime) { return ['--datetime', datetime]; } else if (datetimeInterval) { const start = datetimeInterval.start?.value || '..'; const end = datetimeInterval.end?.value || '..'; return ['--datetime', `${start}/${end}`]; } return []; }
  - ${ const ids = inputs.search_request?.ids; const args = []; if (Array.isArray(ids) && ids.length > 0) { args.push('--ids', ...ids.map(String)); } return args; }
  - ${ const intersects = inputs.search_request?.intersects; if (intersects) { return ['--intersects', JSON.stringify(intersects)]; } return []; }
  - --save
  - discovery-output.json

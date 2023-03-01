![Build & Tests](https://github.com/tricktron/openapi2jsonschema/actions/workflows/main.yml/badge.svg)

# openapi2jsonschema

A utility to extract [JSON Schema](http://json-schema.org/) from a
valid [OpenAPI](https://www.openapis.org/) specification.

This fork includes support for Openshift.

## Why

OpenAPI contains a list of type `definitions` using a superset of JSON
Schema. These are used internally by various OpenAPI compatible tools. I
found myself however wanting to use those schemas separately, outside
existing OpenAPI tooling. Generating separate schemas for types defined
in OpenAPI allows for all sorts of indepent tooling to be build which
can be easily maintained, because the canonical definition is shared.

## Docker

Multi-arch Docker images are available at `ghcr.io/tricktron/openapi2jsonschema/openapi2jsonschema`
and you can run it like so:
```bash
# From URL
docker run -v $(pwd):/tmp --rm ghcr.io/tricktron/openapi2jsonschema/openapi2jsonschema -o /tmp/test-schema --strict --kubernetes https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json

# From a FILE
docker run -v $(pwd):/tmp --rm ghcr.io/tricktron/openapi2jsonschema/openapi2jsonschema -o /tmp/test-schema --strict --kubernetes /tmp/openapi.json
```

## Usage

The simplest usage is to point the `openapi2jsonschema` tool at a URL
containing a JSON (or YAML) OpenAPI definition like so:

```
openapi2jsonschema https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json
```

This will generate a set of schemas in a `schemas` directory. The tool
provides a number of options to modify the output:

```
$ openapi2jsonschema --help
Usage: openapi2jsonschema [OPTIONS] SCHEMA

  Converts a valid OpenAPI specification into a set of JSON Schema files

Options:
  -o, --output PATH  Directory to store schema files
  -p, --prefix TEXT  Prefix for JSON references (only for OpenAPI versions
                     before 3.0)
  --stand-alone      Whether or not to de-reference JSON schemas
  --kubernetes       Enable Kubernetes specific processors
  --strict           Prohibits properties not in the schema
                     (additionalProperties: false)
  --help             Show this message and exit.
```

## Example

My specific usecase was being able to validate Openshift
configuration files with the [YAML language server](https://github.com/redhat-developer/yaml-language-server).

There is currently an [open pull request](https://github.com/redhat-developer/yaml-language-server/pull/841) to add support for custom Kubernetes and
Openshift schemas. Until the pr is merged you can use my [fork](https://github.com/tricktron/yaml-language-server) of the
YAML language server or directly download the updated VSCode extension from my
[forks Github action](https://github.com/tricktron/vscode-yaml/actions/runs/4261755318)
and install it with `Install from VSIX...`.

Afterwards you can get and convert your Openshift schemas as follows:

1. Get the OpenAPI definition from your Openshift cluster and convert it to JSON
schemas with the following commands:

    ```bash
    # login to your Oopenshift cluster
    oc get --raw /openapi/v2 > openapi.json
    mkdir openshift-schemas
    docker run -v $(pwd):/tmp --rm ghcr.io/tricktron/openapi2jsonschema/openapi2jsonschema -o /tmp/openshift-schemas --strict --kubernetes /tmp/openapi.json
    ```

2. Rename the `openshift-schemas/all.json` to `openshift-schemas/kubernetes-all.json`.
It is important that the file name includes the word `kubernetes`.

3. Finally, you can configure the YAML language server to use the schemas by
adding the following to your `.vscode/settings.json`:

    ```json
    {
      "yaml.schemas": {
            "openshift-schemas/kubernetes-all.json": [
                "*.yml",
                "*.yaml",
            ]
        }
    }
    ```

## Manual Installation

`openapi2jsonschema` is implemented in Python. Assuming you have a
Python intepreter and pip installed you should be able to install with:

```
pip install openapi2jsonschema
```

This has not yet been widely tested and is currently in a _works on my
machine_ state.

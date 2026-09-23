# Local example

A Pulumi Julia program that runs without a cloud account. It creates component
resources, which the Pulumi engine handles itself, so no provider plugin and no
credentials are involved.

## Prerequisites

Install the Julia language host, from the repository root:

```bash
just plugin-install
```

## Running it

```bash
cd examples/local

# Resolve the program's dependencies.
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Keep the state outside the repository: this repository's .gitignore is an
# allowlist that includes examples/, so a state directory here would be
# committable by accident.
export PULUMI_BACKEND_URL="file://${TMPDIR:-/tmp}/pulumi-julia-example"
export PULUMI_CONFIG_PASSPHRASE="example"
mkdir -p "${TMPDIR:-/tmp}/pulumi-julia-example"

pulumi stack init dev
pulumi up --yes
```

## What you should see

```console
$ pulumi stack output
Current stack outputs (4):
    OUTPUT       VALUE
    apiToken     [secret]
    environment  dev
    groupUrn     urn:pulumi:dev::julia-local-example::examples:local:Group::demo-dev
    project      julia-local-example

$ pulumi stack output apiToken --show-secrets
token-for-dev
```

`apiToken` is stored encrypted and is only revealed with `--show-secrets`.

## Cleaning up

```bash
pulumi destroy --yes
pulumi stack rm dev --yes
```

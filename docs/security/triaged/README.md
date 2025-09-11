# Security triage process

Within this folder should be the output of triaging a CVE, each CVE should have a dedicated folder named by the CVE with all relevant files inside it.
We take these files to generate documentation and the VEX output feeds for customers.

## Example

Using CVE-2023-2953 as an example, we do the following:

1. Create a new directory: `mkdir -p docs/security/triaged/CVE-2023-2953`.
2. Ensure `vexctl` is installed/updated and runnable: <https://edu.chainguard.dev/open-source/sbom/getting-started-openvex-vexctl/#installing-vexctl>.
3. If a CVE is non-trivial we should mark it as under investigation first:

    ```shell
    cd docs/security/triaged/CVE-2023-2953
    vexctl create --product="pkg:oci/fluent-bit" \
                --vuln="CVE-2023-2953" \
                --status="under_investigation" \
                --author="info@fluent.do" \
                 | tee investigation.vex.json
    ```

4. At this point we can generate our output documents if required (see below).
5. Once triaged, we can again use `vexctl` to indicate it can be ignored for our agent versions:

    ```shell
    cd docs/security/triaged/CVE-2023-2953
    vexctl create --product="pkg:oci/fluent-bit" \
                --vuln="CVE-2023-2953" \
                --status="not_affected" \
                --justification="vulnerable_code_not_in_execute_path" \
                --author="info@fluent.do" \
                --impact-statement="Fluent Bit does not use this component directly or in the way affected in the CVE." \
                 | tee triaged.vex.json
    ```

    Note that we use the `oci/fluent-bit` pURL which will target any image ending in `fluent-bit`, the full pURL spec lets you specify registry and other information: <https://github.com/package-url/purl-spec>.

    For justification you must use one of the expected values: <https://github.com/openvex/spec/blob/main/OPENVEX-SPEC.md#status-justifications>.
    The impact statement is freeform text and will be what we display for user-readable documentation so ensure it is well written and helpful for users.

    Refer to the `vexctl` [documentation](https://edu.chainguard.dev/open-source/sbom/getting-started-openvex-vexctl/) for more details.

6. Now, we can generate our output documents.

## Generation process

To generate the output documents we run the `scripts/security/generate-vex-output.sh` script.

The generation process will loop through all CVE directories and merge any VEX files found into a single one:

```shell
cd docs/security/triaged/CVE-2023-2953
vexctl merge --author="info@fluent.do" \
            investigation.vex.json \
            triaged.vex.json | tee vex.json
```

From these we then create a top-level VEX feed/file of everything.

Ensure all new files are added to Git.

## Testing

We can use the VEX document locally to run with Trivy or Grype:

```shell
trivy image fluent/fluent-bit:4.0.9 --vex docs/security/vex.json
grype fluent/fluent-bit:4.0.9 --vex docs/security/vex.json
```

In each case, neither should show the presence of CVE-2023-2953.

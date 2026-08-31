"""Two standard encodings of one reviewed, artifact-bound inventory."""

import uuid


def purl(component):
    repository = component["source"].removeprefix("https://github.com/")
    return f"pkg:github/{repository}@{component['version']}"


def cyclonedx(inventory, digest, created):
    def component(item):
        result = {
            "type": "application" if item["id"] == "quilnode" else "library",
            "bom-ref": item["id"], "name": item["name"], "version": item["version"],
            "supplier": {"name": item["supplier"]}, "purl": purl(item),
            "licenses": [{"expression": item["license"]}],
            "properties": [{"name": "quilnode:linkage", "value": item["linkage"]}],
            "externalReferences": [{"type": "vcs", "url": item["source"]}],
        }
        if "staticArchiveSHA256" in item:
            result["properties"].append({"name": "quilnode:static-link-input-sha256", "value": item["staticArchiveSHA256"]})
        return result

    records = {item["id"]: component(item) for item in inventory["components"]}
    records["quilnode"]["hashes"] = [{"alg": "SHA-256", "content": digest}]
    return {
        "bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
        "serialNumber": "urn:uuid:" + str(uuid.uuid5(uuid.NAMESPACE_URL, "https://quilnode.com/releases/" + digest)),
        "metadata": {"timestamp": created, "component": records.pop("quilnode"),
                     "properties": [{"name": "quilnode:inventory-scope", "value": inventory["scope"]}]},
        "components": list(records.values()),
        "dependencies": [{"ref": "quilnode", "dependsOn": ["sparkle", "openssl"]},
                         {"ref": "sparkle", "dependsOn": []}, {"ref": "openssl", "dependsOn": []}],
        "compositions": [{"aggregate": "incomplete",
                          "assemblies": ["quilnode"]}],
    }


def spdx(inventory, digest, created, download_url):
    packages = []
    for component in inventory["components"]:
        package = {
            "SPDXID": "SPDXRef-" + component["id"], "name": component["name"],
            "versionInfo": component["version"], "supplier": "Organization: " + component["supplier"],
            "downloadLocation": download_url if component["id"] == "quilnode" else component["upstreamArchive"],
            "filesAnalyzed": False, "licenseConcluded": "NOASSERTION", "licenseDeclared": component["license"],
            "copyrightText": "NOASSERTION",
            "externalRefs": [{"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl",
                              "referenceLocator": purl(component)}],
            "sourceInfo": f"Linkage: {component['linkage']}. Exact delivered files and hashes are in bundle-manifest.json and dependencies.json.",
        }
        if component["id"] == "quilnode":
            package["checksums"] = [{"algorithm": "SHA256", "checksumValue": digest}]
        packages.append(package)
    return {
        "spdxVersion": "SPDX-2.3", "dataLicense": "CC0-1.0", "SPDXID": "SPDXRef-DOCUMENT",
        "name": "QuilNode artifact inventory", "documentNamespace": "https://quilnode.com/spdx/" + digest,
        "creationInfo": {"created": created, "creators": ["Tool: QuilNode-release-evidence-1"]},
        "comment": inventory["scope"], "packages": packages,
        "relationships": [
            {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-quilnode"},
            {"spdxElementId": "SPDXRef-quilnode", "relationshipType": "DEPENDS_ON", "relatedSpdxElement": "SPDXRef-sparkle"},
            {"spdxElementId": "SPDXRef-quilnode", "relationshipType": "STATIC_LINK", "relatedSpdxElement": "SPDXRef-openssl"},
        ],
    }

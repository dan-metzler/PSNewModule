# PSNewModule

Minimal PowerShell module template with build, test, docs, and publish automation.

Click **Use this template** on GitHub to create your own module repo from this one.

---

## What this repo includes

- `Invoke-Build` pipeline (`template.build.ps1`)
- Module packaging with `ModuleBuilder` (`Source/ModuleBuilder.ps1`)
- Pester tests (`Tests/`)
- Markdown help generation with `platyPS` (`Docs/`)
- GitHub Actions workflow that builds, creates a GitHub Release, and optionally publishes to the PowerShell Gallery on every version tag push (`.github/workflows/publish.yml`)

---

## Getting started

### 1. Rename the module

Rename `Source/NewModule.psm1` and `Source/NewModule.psd1` to your module name, then update the manifest (`Source/YourModule.psd1`):

- `RootModule` — match the `.psm1` filename
- `ModuleVersion`, `GUID`, `Author`, `CompanyName`, `Description`
- `Tags`, `ProjectUri`, `LicenseUri`
- `FunctionsToExport` / `CmdletsToExport` / `AliasesToExport`

### 2. Replace `MODULE_NAME` in the workflow

Open `.github/workflows/publish.yml` and replace both occurrences of `MODULE_NAME` with your module name:

```yaml
Compress-Archive -Path .\Output\YourModule ...
Publish-Module   -Path .\Output\YourModule ...
```

### 3. Install dev dependencies

```powershell
.\Install-Requirements.ps1
```

Installs required modules using min/max version ranges:

- `ModuleBuilder` (3.1.8 - 4.x)
- `Pester` (5.7.0 - 6.x)
- `InvokeBuild` (5.14.23 - 6.x)
- `platyPS` (0.14.2 - 1.x)

---

## Build pipeline

Run Local build (compile + import + docs):

```powershell
.\template.build.ps1 -Type Local
```

Run Full pipeline (compile + import + tests):

```powershell
.\template.build.ps1 -Type Full
```

Run an individual task:

```powershell
Invoke-Build -Task BuildModule
Invoke-Build -Task RunTests
Invoke-Build -Task GenerateMarkdownDocs
```

---

## Folder layout

- `Source/` — module source (`.psm1`, `.psd1`, `Public/`, `Private/`)
- `Output/` — built artifact (git-ignored)
- `Tests/` — Pester tests
- `Docs/` — generated markdown help

---

## Publishing

### PowerShell Gallery

The publish workflow fires automatically when a version tag is pushed. To enable Gallery publishing:

1. Generate an API key at [powershellgallery.com](https://www.powershellgallery.com)
2. Add it as a repository secret named `PSGALLERY_API_KEY` in **GitHub > Settings > Secrets and variables > Actions**

If `PSGALLERY_API_KEY` is not set the workflow still runs — it builds, tests, and creates the GitHub Release, but skips the Gallery publish step.

### Push a new release

```powershell
# Commit and push your changes first
git add .
git commit -m "[feat] add my new feature"
git push origin main

# Tag the release — this triggers the publish workflow **NOTE** Make sure you are updating your versioning
git tag -a v1.1.0 -m "Release v1.0.0"
git push origin v1.1.0
```

Pushing the tag triggers `.github/workflows/publish.yml`, which:

1. Installs dependencies
2. Runs the full build pipeline (the tag version number is extracted and passed in as `-Version`)
3. Zips the `Output/<ModuleName>` folder
4. Creates a GitHub Release with auto-generated release notes and the zip attached
5. Publishes to the PowerShell Gallery (if `PSGALLERY_API_KEY` is set)

### Re-tag an existing version

If you need to re-run a release after fixing something:

```powershell
# Delete the tag locally and on remote, then re-create it
git tag -d v1.0.1
git push origin :refs/tags/v1.0.1
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

---

## Notes

- Tests import the built module from `Output/`, not `Source/` — always run a build before running tests.
- Markdown help generation depends on `ModuleImport` so the module name is available at doc-gen time.
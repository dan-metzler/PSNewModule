# PSNewModule

A minimal PowerShell module template (PowerShell 5.1+) with build, test, docs, and publish automation already set up.

- **Build** — `Invoke-Build` pipeline (`template.build.ps1`) + `ModuleBuilder` packaging
- **Test** — Pester 5 (`Tests/`)
- **Docs** — Markdown help generated with `platyPS` (`Docs/`)
- **Publish** — GitHub Actions workflow that creates a GitHub Release, and optionally publishes to the PowerShell Gallery, on every version tag

---

## Quick start: local (no GitHub needed)

Load the `New-PSModuleProject` function, then run it to create a ready-to-build module on your Desktop:

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/dan-metzler/PSNewModule/main/New-PSModuleProject.ps1' | Invoke-Expression
New-PSModuleProject -Name MyModule
```

Prefer to read it first? Open [`New-PSModuleProject.ps1`](New-PSModuleProject.ps1), copy the whole file, paste it into PowerShell, then run `New-PSModuleProject -Name MyModule`.

The function downloads this template, copies it to `Desktop\MyModule`, and renames everything for your module: files, manifest (new GUID, author, description), tests, docs, and the publish workflow. It then prints numbered next steps; the same steps are written to the new project's own `README.md`.

| Parameter | Default | Purpose |
|---|---|---|
| `-Name` | *(required)* | Module name |
| `-Path` | Desktop | Parent folder for the project |
| `-Author` | `$env:USERNAME` | Manifest author |
| `-Description` | `<Name> PowerShell module.` | Manifest description |
| `-InstallRequirements` | off | Install build dependencies |
| `-GitInit` | off | `git init` and create an initial commit |
| `-PassThru` | off | Return the new project folder object |

Then build it:

```powershell
cd ~\Desktop\MyModule
.\Install-Requirements.ps1          # skip if you used -InstallRequirements
.\template.build.ps1 -Type Full
```

When you're ready to put it on GitHub, see [Moving a local project to GitHub](#moving-a-local-project-to-github).

> Already cloned or downloaded this repo? Run `.\New-PSModuleProject.ps1 -Name MyModule` from it instead. It uses your local copy. Run `Get-Help New-PSModuleProject -Full` after loading the function for full help.

---

## Quick start: GitHub template

1. Click **Use this template** on GitHub and clone your new repo.
2. Rename `Source/NewModule.psd1`, `Source/NewModule.psm1`, and `Tests/NewModule.Tests.ps1` to your module name.
3. In the manifest, update `RootModule` (match the `.psm1` name), `GUID` (`[guid]::NewGuid()`), `Author`, `CompanyName`, `Description`, and optionally `Tags`, `ProjectUri`, `LicenseUri`.
4. In `.github/workflows/publish.yml`, replace every `YOUR_MODULE_NAME` with your module name.

---

## Build and test

Install dev dependencies (run once):

```powershell
.\Install-Requirements.ps1
```

| Module | Version range |
|---|---|
| `ModuleBuilder` | 3.1.8 – 4.x |
| `Pester` | 5.7.0 – 5.x |
| `InvokeBuild` | 5.14.23 – 6.x |
| `platyPS` | 0.14.2 – 1.x |

Build:

```powershell
.\template.build.ps1 -Type Local   # compile, import, regenerate Docs/
.\template.build.ps1 -Type Full    # compile, import, run Pester tests
```

The build version comes from the latest git tag (`v1.2.3`). With no git, no repo, or no tags yet, it falls back to `ModuleVersion` in `Source/<ModuleName>.psd1`. Pass `-Version 1.2.3` to override either.

Run a single task:

```powershell
Invoke-Build -Task BuildModule -Type Local
Invoke-Build -Task RunTests -Type Full
Invoke-Build -Task GenerateMarkdownDocs -Type Local
```

Tests run against the built module in `Output/`, not `Source/`, so build before you run tests by hand.

---

## Folder layout

| Path | Contents |
|---|---|
| `Source/` | Module source: `.psd1`, `.psm1`, `Public/` (exported), `Private/` (internal) |
| `Tests/Unit/` | Pester tests (`*.Tests.ps1`) |
| `Docs/` | Generated markdown help, one file per exported function |
| `Output/` | Built module (git-ignored) |

Add a function by creating `Source/Public/Verb-Noun.ps1`. `ModuleBuilder` exports everything in `Public/` automatically.

---

## Moving a local project to GitHub

Create an empty repo on GitHub (no README or license), then:

```powershell
git init -b main            # skip if you used -GitInit
git add .
git commit -m "[chore] initial commit"
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

Or, with the GitHub CLI: `gh repo create <repo> --private --source . --push`.

---

## Publishing

Pushing a version tag (`v1.2.3`) triggers `.github/workflows/publish.yml`, which:

1. Installs dependencies and runs the Full build, using the tag as the module version
2. Zips `Output/<ModuleName>` and attaches it to a new GitHub Release with auto-generated notes
3. Publishes to the PowerShell Gallery, but only if the `PSGALLERY_API_KEY` secret is set

### Enable PowerShell Gallery publishing

1. Create an API key at [powershellgallery.com](https://www.powershellgallery.com).
2. Add it as a repository secret named `PSGALLERY_API_KEY` under **Settings › Secrets and variables › Actions**.

### Release a version

```powershell
git push origin main
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

### Re-run a release

Delete the tag locally and on the remote, then re-create it:

```powershell
git tag -d v1.1.0
git push origin :refs/tags/v1.1.0
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

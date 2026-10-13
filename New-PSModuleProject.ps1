function New-PSModuleProject {
    <#
    .SYNOPSIS
        Creates a new local PowerShell module project from the PSNewModule template.

    .DESCRIPTION
        Copies the PSNewModule template into a new folder and renames everything for your module:
        source files, manifest (RootModule, new GUID, Author, Description), test entry point,
        docs, and the publish workflow. No GitHub account or git is required.

        Paste this whole file into a PowerShell session (or load it with Invoke-RestMethod or
        dot-sourcing) to define the function, then call it. When loaded from a clone of the
        template, the local files are used; otherwise the template is downloaded from GitHub.

    .PARAMETER Name
        Name of the new module. Must start with a letter; letters, digits, '.', '_' and '-' allowed.

    .PARAMETER Path
        Parent folder for the new project. Defaults to the current user's Desktop.

    .PARAMETER Author
        Author written to the module manifest. Defaults to the current user name.

    .PARAMETER Description
        Description written to the module manifest.

    .PARAMETER Branch
        Template branch to download when running remotely. Defaults to 'main'.

    .PARAMETER InstallRequirements
        Runs Install-Requirements.ps1 in the new project to install the build dependencies.

    .PARAMETER GitInit
        Initializes a git repository in the new project and creates an initial commit.

    .EXAMPLE
        New-PSModuleProject -Name MyModule

        After pasting this function into the console, downloads the template and creates
        the project at Desktop\MyModule.

    .EXAMPLE
        Invoke-RestMethod 'https://raw.githubusercontent.com/dan-metzler/PSNewModule/main/New-PSModuleProject.ps1' | Invoke-Expression
        New-PSModuleProject -Name MyModule

        Loads the function straight from GitHub, then creates the project.

    .EXAMPLE
        .\New-PSModuleProject.ps1 -Name MyModule -Path C:\Code -InstallRequirements -GitInit

        Runs the file directly from a local clone: creates C:\Code\MyModule from the local
        files, installs dependencies, and initializes git.

    .INPUTS
        None.

    .OUTPUTS
        System.IO.DirectoryInfo. The new project folder.

    .NOTES
        Requires PowerShell 5.1 or later.

    .LINK
        https://github.com/dan-metzler/PSNewModule
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9._-]*$')]
        [string]$Name,

        [Parameter()]
        [string]$Path = [Environment]::GetFolderPath('Desktop'),

        [Parameter()]
        [string]$Author = $env:USERNAME,

        [Parameter()]
        [string]$Description = "$Name PowerShell module.",

        [Parameter()]
        [string]$Branch = 'main',

        [Parameter()]
        [switch]$InstallRequirements,

        [Parameter()]
        [switch]$GitInit
    )

    $ErrorActionPreference = 'Stop'

    $templateRepo = 'https://github.com/dan-metzler/PSNewModule'
    $templateName = 'NewModule'

    # ============================================================================
    # Step 1: Validate Destination
    # ============================================================================

    if (-not (Test-Path -Path $Path -PathType Container)) {
        throw "Parent folder '$Path' does not exist."
    }

    $destination = Join-Path -Path (Resolve-Path -Path $Path).ProviderPath -ChildPath $Name

    if ((Test-Path -Path $destination) -and (Get-ChildItem -Path $destination -Force | Select-Object -First 1)) {
        throw "Destination '$destination' already exists and is not empty."
    }

    # ============================================================================
    # Step 2: Copy Template Files
    # ============================================================================
    # Uses the local clone when this file is loaded from one; otherwise downloads
    # the template zip from GitHub. Git-ignored and repo-only items are skipped.

    $excluded = @('.git', 'Output', 'Dev', 'Development', 'CLAUDE.md', 'New-PSModuleProject.ps1')
    $tempDir = $null

    try {
        if ($PSScriptRoot -and (Test-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "Source\$templateName.psd1"))) {
            Write-Host "Using local template at $PSScriptRoot"
            $templateRoot = $PSScriptRoot
        }
        else {
            # Windows PowerShell 5.1 may default to TLS 1.0, which GitHub rejects.
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

            $tempDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().ToString())
            New-Item -Path $tempDir -ItemType Directory | Out-Null

            $zipUri = "$templateRepo/archive/refs/heads/$Branch.zip"
            $zipPath = Join-Path -Path $tempDir -ChildPath 'template.zip'
            Write-Host "Downloading template from $zipUri"
            Invoke-WebRequest -Uri $zipUri -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $tempDir

            # GitHub zips contain a single top-level folder, e.g. PSNewModule-main
            $templateRoot = (Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1).FullName
        }

        New-Item -Path $destination -ItemType Directory -Force | Out-Null
        Get-ChildItem -Path $templateRoot -Force |
            Where-Object { $excluded -notcontains $_.Name } |
            Copy-Item -Destination $destination -Recurse -Force
    }
    finally {
        if ($tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # ============================================================================
    # Step 3: Rename Template Files
    # ============================================================================

    foreach ($file in @("Source\$templateName.psd1", "Source\$templateName.psm1", "Tests\$templateName.Tests.ps1")) {
        $filePath = Join-Path -Path $destination -ChildPath $file
        if (Test-Path -Path $filePath) {
            Rename-Item -Path $filePath -NewName ((Split-Path -Path $filePath -Leaf) -replace "^$templateName", $Name)
        }
    }

    # ============================================================================
    # Step 4: Replace Placeholders
    # ============================================================================
    # Swaps the template module name in code, workflow, and docs files. README.md
    # is left alone since it documents the template itself.

    $utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

    function Update-FileContent {
        param([string]$FilePath, [scriptblock]$Transform)
        $content = [IO.File]::ReadAllText($FilePath)
        $updated = & $Transform $content
        if ($updated -cne $content) { [IO.File]::WriteAllText($FilePath, $updated, $utf8NoBom) }
    }

    Get-ChildItem -Path $destination -Recurse -File -Include '*.ps1', '*.psd1', '*.psm1', '*.yml', '*.md' |
        Where-Object { $_.Name -ne 'README.md' } |
        ForEach-Object {
            Update-FileContent -FilePath $_.FullName -Transform {
                param($text)
                $text.Replace($templateName, $Name).Replace('YOUR_MODULE_NAME', $Name)
            }
        }

    # Manifest metadata. Single quotes are doubled to stay valid inside '...' strings.
    $manifestPath = Join-Path -Path $destination -ChildPath "Source\$Name.psd1"
    Update-FileContent -FilePath $manifestPath -Transform {
        param($text)
        $safeAuthor = $Author.Replace("'", "''")
        $safeDescription = $Description.Replace("'", "''")
        $text = $text -replace "(?m)^(\s*GUID\s*=\s*)'[^']*'", "`$1'$([guid]::NewGuid())'"
        $text = $text -replace "(?m)^(\s*Author\s*=\s*)'[^']*'", "`$1'$safeAuthor'"
        $text = $text -replace "(?m)^(\s*Copyright\s*=\s*)'[^']*'", "`$1'(c) $((Get-Date).Year) $safeAuthor. All rights reserved.'"
        $text -replace "(?m)^(\s*Description\s*=\s*)'[^']*'", "`$1'$safeDescription'"
    }

    Write-Host "Created module project '$Name' at $destination" -ForegroundColor Green

    # ============================================================================
    # Step 5: Optional Setup
    # ============================================================================

    if ($InstallRequirements) {
        Write-Host 'Installing build dependencies...'
        & (Join-Path -Path $destination -ChildPath 'Install-Requirements.ps1')
    }

    if ($GitInit) {
        if (Get-Command -Name git -ErrorAction SilentlyContinue) {
            git -C $destination init --initial-branch=main --quiet
            git -C $destination -c core.safecrlf=false add --all
            git -C $destination commit --quiet -m '[chore] initial project from PSNewModule template'
            if ($LASTEXITCODE -ne 0) {
                Write-Warning 'git commit failed. Check your git user.name/user.email config, then commit manually.'
            }
        }
        else {
            Write-Warning 'git was not found on PATH; skipping repository initialization.'
        }
    }

    # ============================================================================
    # Step 6: Next Steps
    # ============================================================================

    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor Cyan
    Write-Host "  cd '$destination'"
    if (-not $InstallRequirements) { Write-Host '  .\Install-Requirements.ps1' }
    Write-Host '  .\template.build.ps1 -Type Local    # build + docs'
    Write-Host '  .\template.build.ps1 -Type Full     # build + tests'
    Write-Host ''
    Write-Host 'Add functions to Source\Public, tests to Tests\Unit. See README.md for publishing to GitHub.'

    Get-Item -Path $destination
}

# When the file is run directly (.\New-PSModuleProject.ps1 -Name X) rather than
# pasted, piped to Invoke-Expression, or dot-sourced, forward the arguments.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.MyCommand.Path) {
    New-PSModuleProject @args
}

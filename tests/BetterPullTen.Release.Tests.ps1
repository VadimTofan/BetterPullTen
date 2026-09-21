$repositoryPath = Join-Path $PSScriptRoot '..'
$workflowPath = Join-Path $repositoryPath '.github\workflows\release.yml'
$packageMetaPath = Join-Path $repositoryPath '.pkgmeta'
$tocPath = Join-Path $repositoryPath 'BetterPullTen.toc'
$readmePath = Join-Path $repositoryPath 'README.md'
$clientTocFiles = @{
    Forever = 'BetterPullTen.toc'
    Retail = 'BetterPullTen_Mainline.toc'
    ClassicEra = 'BetterPullTen_Vanilla.toc'
    Anniversary = 'BetterPullTen_BCC.toc'
    Mists = 'BetterPullTen_Mists.toc'
}
$clientInterfaces = @{
    Forever = '16001'
    Retail = '120100'
    ClassicEra = '11508'
    Anniversary = '20506'
    Mists = '50503'
}

$workflow = if (Test-Path -LiteralPath $workflowPath) {
    Get-Content -Raw $workflowPath
} else {
    ''
}

$packageMeta = if (Test-Path -LiteralPath $packageMetaPath) {
    Get-Content -Raw $packageMetaPath
} else {
    ''
}

$toc = Get-Content -Raw $tocPath
$readme = Get-Content -Raw $readmePath

Describe 'BetterPullTen tagged releases' {
    It 'runs only for version tag pushes' {
        # Given
        $tagTrigger = 'tags:\s*\r?\n\s*- [''"]v\*[''"]'

        # When
        $releaseWorkflowExists = Test-Path -LiteralPath $workflowPath

        # Then
        $releaseWorkflowExists | Should Be $true
        $workflow | Should Match '(?m)^\s*push:\s*$'
        $workflow | Should Match $tagTrigger
        $workflow | Should Not Match '(?m)^\s*branches:'
    }

    It 'validates semantic tags against the toc version' {
        # Given
        $semanticVersionPattern = '\^\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$'

        # When
        $validationStep = $workflow

        # Then
        $validationStep | Should Match 'GITHUB_REF_NAME#v'
        $validationStep | Should Match 'sed -n'
        $validationStep | Should Match '\^## Version:'
        $validationStep | Should Match $semanticVersionPattern
        $validationStep | Should Match 'tag_version.*toc_version'
    }

    It 'validates every client manifest before packaging' {
        # Given every supported client must ship the same addon version
        # When the release validation step checks manifests
        # Then all five toc files are included in the version loop
        foreach ($tocFile in $clientTocFiles.Values) {
            $tocPattern = [regex]::Escape($tocFile)
            $workflow | Should Match $tocPattern
        }

        $workflow | Should Match 'for toc_file in'
        $workflow | Should Match 'tag_version.*toc_version'
    }

    It 'publishes with the configured CurseForge and GitHub tokens' {
        # Given
        $curseForgeSecret = [regex]::Escape(
            'CF_API_KEY: ${{ secrets.CF_API_TOKEN }}'
        )
        $githubToken = [regex]::Escape(
            'GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}'
        )

        # When
        $releaseEnvironment = $workflow

        # Then
        $releaseEnvironment | Should Match $curseForgeSecret
        $releaseEnvironment | Should Match $githubToken
        $releaseEnvironment | Should Match '(?m)^permissions:\s*\r?\n\s+contents: write$'
    }

    It 'uses the WoW packager with complete Git history' {
        # Given
        $packagerAction = [regex]::Escape('BigWigsMods/packager@v2')

        # When
        $releaseSteps = $workflow

        # Then
        $releaseSteps | Should Match 'fetch-depth: 0'
        $releaseSteps | Should Match $packagerAction
    }

    It 'declares the CurseForge project on the addon' {
        # Given
        $projectMetadata = '(?m)^## X-Curse-Project-ID: 1509727$'

        # When
        $addonMetadata = $toc

        # Then
        $addonMetadata | Should Match $projectMetadata
    }

    It 'provides a manifest for every supported client' {
        # Given
        $requiredMetadata = @(
            '(?m)^## Title: BetterPullTen$'
            '(?m)^## Version: 0\.1\.3$'
            '(?m)^## X-Curse-Project-ID: 1509727$'
            '(?m)^## SavedVariables: BetterPullTenDB$'
            '(?m)^BetterPullTen\.lua$'
        )

        # When
        foreach ($client in $clientTocFiles.Keys) {
            $clientTocPath = Join-Path $repositoryPath $clientTocFiles[$client]

            # Then
            Test-Path -LiteralPath $clientTocPath | Should Be $true
            $clientToc = Get-Content -Raw $clientTocPath
            $clientToc | Should Match (
                '(?m)^## Interface: ' + $clientInterfaces[$client] + '$'
            )

            foreach ($metadataPattern in $requiredMetadata) {
                $clientToc | Should Match $metadataPattern
            }
        }
    }

    It 'packages only the runtime addon directory' {
        # Given
        $packageName = '(?m)^package-as: BetterPullTen$'

        # When
        $packagingRules = $packageMeta

        # Then
        Test-Path -LiteralPath $packageMetaPath | Should Be $true
        $packagingRules | Should Match $packageName
        $packagingRules | Should Match '(?m)^\s+- \.github$'
        $packagingRules | Should Match '(?m)^\s+- docs$'
        $packagingRules | Should Match '(?m)^\s+- tests$'
        $packagingRules | Should Match `
            '(?m)^\s+- CURSEFORGE_DESCRIPTION\.md$'
        $packagingRules | Should Match '(?m)^\s+- README\.md$'
    }

    It 'documents the matching toc version and tag release flow' {
        # Given
        $releaseTagExample = [regex]::Escape('git tag -a v0.1.3')

        # When
        $releaseDocumentation = $readme

        # Then
        $releaseDocumentation | Should Match '(?m)^## Releasing$'
        $releaseDocumentation | Should Match $releaseTagExample
        $releaseDocumentation | Should Match 'CF_API_TOKEN'
    }

    It 'documents every supported client and Forever installation path' {
        # Given users need client-specific installation guidance
        # When the compatibility documentation is inspected
        # Then every supported client and the beta directory are named
        foreach ($clientName in @(
            'Retail'
            'Classic Era'
            'Anniversary'
            'MoP Classic'
            'WoW Forever'
        )) {
            $clientPattern = [regex]::Escape($clientName)
            $readme | Should Match $clientPattern
        }

        $foreverPathPattern = [regex]::Escape('_classic_beta_')
        $readme | Should Match $foreverPathPattern
        $readme | Should Match 'Mythic\+ visibility is available only on Retail'
        $readme | Should Match 'Interface versions must'
    }
}

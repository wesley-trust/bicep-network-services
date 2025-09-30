param(
    [Parameter(Mandatory = $false)]
    [string]$TestsPath = '.',

    [Parameter(Mandatory = $false)]
    [string]$ResultsFile = 'TestResults/pester.review.txt'
)

Write-Host "Pester review information"
Write-Host "TestsPath: $TestsPath"
Write-Host "ResultsFile (deploy run will emit XML to this path): $ResultsFile"

if (-not (Test-Path $TestsPath)) {
    Write-Warning "The supplied TestsPath '$TestsPath' does not exist in the review snapshot."
}

# In review we only surface metadata instead of executing the tests.
Write-Host "Skipping test execution because this is a review-only run."

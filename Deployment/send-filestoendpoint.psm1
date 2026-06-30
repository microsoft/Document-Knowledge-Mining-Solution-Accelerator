function Send-FilesToEndpoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DataFolderPath,

        [Parameter(Mandatory=$true)]
        [string]$EndpointUrl
    )

    # Load necessary .NET assemblies
    Add-Type -AssemblyName "System.Net.Http"

    # Check if the Data folder exists
    if (-Not (Test-Path -Path $DataFolderPath)) {
        Write-Error "The specified Data folder path does not exist: $DataFolderPath"
        return
    }

    # Get all files in the Data folder
    $files = Get-ChildItem -Path $DataFolderPath -File

    # Create HttpClient with timeout with 20minutes
    $timeout = 1200000 # Timeout in milliseconds (e.g., 1200000 ms = 1200 seconds)
    $httpClient = [System.Net.Http.HttpClient]::new()
    $httpClient.Timeout = [TimeSpan]::FromMilliseconds($timeout)

    $totalFiles = $files.Count
    $currentFileIndex = 0
    $maxRetries = 3
    $retryDelaySeconds = 5
    $failedFiles = @()
    $successfulFiles = 0

    foreach ($file in $files) {
        $currentFileIndex++
        $percentComplete = [math]::Round(($currentFileIndex / $totalFiles) * 100)
        Write-Progress -Activity "Uploading Files" -Status "Uploading and Processing file ${currentFileIndex} of ${totalFiles}: $($file.Name)" -PercentComplete $percentComplete

        # Check file size
        if ($file.Length -eq 0) {
            Write-Host "⚠️  File cannot be uploaded: $($file.Name) (File size is 0)" -ForegroundColor Yellow
            $failedFiles += @{FileName = $file.Name; Reason = "File size is 0"}
            continue
        }

        # Check file type
        $allowedExtensions = @(".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".pdf", ".tif", ".tiff", ".jpg", ".jpeg", ".png", ".bmp", ".txt")
        if (-Not ($allowedExtensions -contains $file.Extension.ToLower())) {
            Write-Host "⚠️  File cannot be uploaded: $($file.Name) (Unsupported file type)" -ForegroundColor Yellow
            $failedFiles += @{FileName = $file.Name; Reason = "Unsupported file type"}
            continue
        }

        # Retry logic for file upload
        $uploadSuccess = $false
        $attempt = 0
        
        while ($attempt -lt $maxRetries -and -not $uploadSuccess) {
            $attempt++
            try {
                if ($attempt -gt 1) {
                    Write-Host "🔄 Retry attempt $attempt of $maxRetries for file: $($file.Name)" -ForegroundColor Cyan
                    Start-Sleep -Seconds $retryDelaySeconds
                }
                
                # Read the file content as byte array
                $fileContent = [System.IO.File]::ReadAllBytes($file.FullName)

                # Create the multipart form data content
                $content = [System.Net.Http.MultipartFormDataContent]::new()
                $fileContentByteArray = [System.Net.Http.ByteArrayContent]::new($fileContent)
                $fileContentByteArray.Headers.ContentDisposition = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
                $fileContentByteArray.Headers.ContentDisposition.Name = '"file"'
                $fileContentByteArray.Headers.ContentDisposition.FileName = '"' + $file.Name + '"'
                $content.Add($fileContentByteArray)

                # Upload the file content to the HTTP endpoint
                $response = $httpClient.PostAsync($EndpointUrl, $content).GetAwaiter().GetResult()
                
          
                # Check the response status
                if ($response.IsSuccessStatusCode) {
                    Write-Host "✅ File uploaded successfully: $($file.Name)" -ForegroundColor Green
                    $uploadSuccess = $true
                    $successfulFiles++
                } 
                else {
                    $statusCode = $response.StatusCode
                    if ($attempt -lt $maxRetries) {
                        Write-Host "⚠️  Failed to upload file: $($file.Name). Status code: $statusCode. Will retry..." -ForegroundColor Yellow
                    } else {
                        Write-Host "❌ Failed to upload file: $($file.Name). Status code: $statusCode. Max retries reached." -ForegroundColor Red
                        $failedFiles += @{FileName = $file.Name; Reason = "HTTP Status: $statusCode"}
                    }
                }
            }
            catch {
                if ($attempt -lt $maxRetries) {
                    Write-Host "⚠️  Error uploading file: $($file.Name). Error: $($_.Exception.Message). Will retry..." -ForegroundColor Yellow
                } else {
                    Write-Host "❌ Error uploading file: $($file.Name). Error: $($_.Exception.Message). Max retries reached." -ForegroundColor Red
                    $failedFiles += @{FileName = $file.Name; Reason = $_.Exception.Message}
                }
            }
        }
    }
    # Dispose HttpClient
    $httpClient.Dispose()

    # Clear the progress bar
    Write-Progress -Activity "Uploading Files" -Status "Completed" -PercentComplete 100
    
    # Print summary report
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📊 File Upload Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total files processed: $totalFiles" -ForegroundColor White
    Write-Host "✅ Successfully uploaded: $successfulFiles" -ForegroundColor Green
    Write-Host "❌ Failed uploads: $($failedFiles.Count)" -ForegroundColor Red
    
    if ($failedFiles.Count -gt 0) {
        Write-Host "`n❌ Failed Files Details:" -ForegroundColor Red
        foreach ($failed in $failedFiles) {
            Write-Host "  • $($failed.FileName) - Reason: $($failed.Reason)" -ForegroundColor Yellow
        }
        Write-Host "`n⚠️  Warning: Some files failed to upload after $maxRetries retry attempts." -ForegroundColor Yellow
        Write-Host "You can manually retry uploading the failed files later." -ForegroundColor Yellow
    } else {
        Write-Host "`n✅ All files uploaded successfully!" -ForegroundColor Green
    }
    Write-Host "========================================`n" -ForegroundColor Cyan
}

Export-ModuleMember -Function Send-FilesToEndpoint
Add-Type -AssemblyName System.Windows.Forms
# Specify the folder path where the images are located
$folderPath = Join-Path -Path $PSScriptRoot -ChildPath "Lockscreens"

# Check if the folder exists
if (Test-Path $folderPath -PathType Container) {
    # Get the primary monitor's resolution and aspect ratio
    $primaryScreenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $primaryScreenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    $primaryAspectRatio = [math]::Round($primaryScreenWidth / $primaryScreenHeight, 3)

    # Initialize variables to store the best match information
    $bestMatchFile = $null
    $bestMatchDiff = [double]::MaxValue

    # Get all image files in the folder
    $imageFiles = Get-ChildItem -Path $folderPath -Filter *.png

    # Iterate through each image and find the best match
    foreach ($imageFile in $imageFiles) {
        # Load the image and get its dimensions
        $image = [System.Drawing.Image]::FromFile($imageFile.FullName)
        $width = $image.Width
        $height = $image.Height

        # Calculate the aspect ratio
        $aspectRatio = [math]::Round($width / $height, 3)

        # Check for an exact resolution match
        if ($width -eq $primaryScreenWidth -and $height -eq $primaryScreenHeight) {
            $bestMatchFile = $imageFile
            break  # Found an exact match, no need to check further
        }

        # Check for the closest aspect ratio match
        $aspectRatioDiff = [math]::Abs($primaryAspectRatio - $aspectRatio)
        if ($aspectRatioDiff -lt $bestMatchDiff) {
            $bestMatchDiff = $aspectRatioDiff
            $bestMatchFile = $imageFile
        }

        # Dispose of the image object
        $image.Dispose()
    }

    # Output the best match file path
    if ($bestMatchFile -ne $null) {
        Write-Host "Best Match File Path: $($bestMatchFile.FullName)"
	$registryPath = "HKLM:Software\Policies\Microsoft\Windows\Personalization"
	New-Item -Path $registryPath -Force
	Set-ItemProperty -Path $registryPath -Name "LockScreenImage" -Value $bestMatchFile.FullName
	Set-ItemProperty -Path $registryPath -Name "NoChangingLockScreen" -Value 1
    } else {
        Write-Host "No matching image found."
    }
} else {
    Write-Host "Folder not found: $folderPath"
}

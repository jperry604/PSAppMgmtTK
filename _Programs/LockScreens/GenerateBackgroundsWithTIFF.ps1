Add-Type -AssemblyName System.Drawing

# Specify the folder path where you want to save the images
$folderPath = Join-Path -Path $PSScriptRoot -ChildPath "Lockscreens"
$companyLogo = Join-Path -Path $PSScriptRoot -ChildPath "CompanyLogo.Tiff"
$generatePortrait = $true


function Create-Image {
    param (
        [int]$width,
        [int]$height,
        [System.IO.FileInfo]$outputPath,
        $cornerText = @{
            "TopLeft"     = "Top Left Corner"
            "TopRight"    = "Top Right Corner"
            "BottomLeft"  = "Bottom Left Corner"
            "BottomRight" = "Bottom Right Corner"
        }
    )

    $bmp = New-Object System.Drawing.Bitmap $width, $height

    $font = $null  # Initialize $font variable

    # Set the background color
    $bgColor = [System.Drawing.ColorTranslator]::FromHtml("#003e43")
    # Set the text color
    $textColor = [System.Drawing.ColorTranslator]::FromHtml("#f4f4ec")

    # Calculate the font size based on the image size
    $fontSize = [math]::Min($width, $height) / 20  # You can adjust the divisor for scaling

    try {
        $font = New-Object System.Drawing.Font "Consolas", $fontSize
        $brushBg = New-Object System.Drawing.SolidBrush $bgColor
        $brushFg = New-Object System.Drawing.SolidBrush $textColor
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.FillRectangle($brushBg, 0, 0, $bmp.Width, $bmp.Height)

        # Multiline text in each corner
        $cornerTextFontSize = $fontSize / 2  # Adjust the divisor for corner text size

        foreach ($corner in $cornerText.Keys) {
            $cornerFont = New-Object System.Drawing.Font "Consolas", $cornerTextFontSize
            $textSize = $graphics.MeasureString($cornerText.$corner, $cornerFont)

            if ($corner -eq "TopLeft" -or $corner -eq "BottomLeft") {
                $cornerX = 10
            } else {
                $cornerX = $bmp.Width - $textSize.Width - 10
            }

            if ($corner -eq "TopLeft" -or $corner -eq "TopRight") {
                $cornerY = 10
            } else {
                $cornerY = $bmp.Height - $textSize.Height - 10
            }

            $graphics.DrawString($cornerText[$corner], $cornerFont, $brushFg, $cornerX, $cornerY)
            $cornerFont.Dispose()
        }

        if (Test-Path $companyLogo) {
            $logoImage = [System.Drawing.Image]::FromFile($companyLogo)
            $xmargins = 0.2
            $ymargins = 0.2

            $xoffset = -0.1
            $yoffset = 0.05

            # upper left location
            $xposition = ($bmp.Width * $xmargins) + ($bmp.Width * $xoffset)
            $yposition = ($bmp.Height * $ymargins) + ($bmp.Height * $yoffset)

            # Calculate the desired width and height
            $logoX = $bmp.Width * (1 - ($xmargins * 2))
            $logoY = $bmp.Height * (1 - ($ymargins * 2))

            # Draw the logo on the image
            $graphics.DrawImage($logoImage, $xposition, $yposition, $logoX, $logoY)

            # Dispose of the logo image
            $logoImage.Dispose()
        }

        # Save the image to the specified path
        $bmp.Save($outputPath.FullName)

        Write-Host "Image created at: $($outputPath.FullName)"
    }
    finally {
        if ($font -ne $null) {
            $font.Dispose()
        }
        if ($brushBg -ne $null) {
            $brushBg.Dispose()
        }
        if ($brushFg -ne $null) {
            $brushFg.Dispose()
        }
    }

    $bmp.Dispose()
}

# Create the folder if it doesn't exist
if (-not (Test-Path $folderPath -PathType Container)) {
    New-Item -ItemType Directory -Path $folderPath | Out-Null
}



# Common resolutions
$resolutions = @{
    "HD"      = @{ Width = 1280; Height = 720 }
    "FHD"     = @{ Width = 1920; Height = 1080 }
    "QHD"     = @{ Width = 2560; Height = 1440 }
    "WUXGA"   = @{ Width = 1920; Height = 1200 }  # Widescreen UXGA
    "UWHD"    = @{ Width = 2560; Height = 1080 }  # Ultrawide Full HD
    "WQHD"    = @{ Width = 3440; Height = 1440 }  # Ultrawide Quad HD (UWQHD)
    "4K"      = @{ Width = 3840; Height = 2160 }
    "5K"      = @{ Width = 5120; Height = 2880 }
    "8K"      = @{ Width = 7680; Height = 4320 }
    "UWQHD"   = @{ Width = 3440; Height = 1440 }  # Ultrawide Quad HD
    "WQXGA"   = @{ Width = 2560; Height = 1600 }  # Widescreen Quad Extended Graphics Array
    "QWXGA"   = @{ Width = 2048; Height = 1152 }  # Quad Widescreen Extended Graphics Array
    "WXGA"    = @{ Width = 1280; Height = 800 }   # Widescreen Extended Graphics Array
    "WSXGA"   = @{ Width = 1680; Height = 1050 }  # Widescreen Super Extended Graphics Array
}



# Create images for each resolution
foreach ($resolutionKey in $resolutions.Keys) {
    $name = $resolutionKey
    $dimensions = $resolutions[$resolutionKey]
    $outputPath = ([System.IO.FileInfo](Join-Path -Path $folderPath -ChildPath "$name.png")).FullName
    Create-Image -width $dimensions.Width -height $dimensions.Height -outputPath $outputPath 
    Write-Host "Image created for $name resolution. Path: $($outputPath.FullName)"

    if($generatePortrait){
	    $outputPath = ([System.IO.FileInfo](Join-Path -Path $folderPath -ChildPath "$name-Portrait.png")).FullName
	    Create-Image -width $dimensions.Height -height $dimensions.Width -outputPath $outputPath 
	    Write-Host "Image created for $name resolution. Path: $($outputPath.FullName)"
    }
    
}

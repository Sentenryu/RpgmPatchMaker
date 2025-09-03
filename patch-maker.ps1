#parameters

#list here any file patterns you want to ignore
# example, to keep ignoring html files and start ignoring json files that start with the word "temp" the array should look like this:
#$ignoredFiles = (
#    '*.html',
#    'temp*.json'
#)

$ignoredFiles = (
    '*.html'
)

# the 3 paths bellow don't need to be in the same folder as the script, but it's way easier to track if they are.

# a path to a folder containing the base version that's being updated
# the script doesn't modify the files in this folder.
$oldVersionFolder = '.\OldVersion\'

# a path to a folder containing the new version
# the script doesn't modify the files in this folder.
$newVersionFolder = '.\NewVersion\'

# a path to a folder where the output will be generated
# the script will copy a bunch of files there.
$patchOutputFolder = '.\Patch\'

# helper function to check if the whole folder structure of the file path exists, if it doesn't it will be created.
function New-DirectoryIfNotExists {
    param (
        [string] $filePath
    )
    #this grabs just the directory path from the file name
    $fileDirectoryInPatchFolder = Split-Path $filePath -Parent

    #this checks if the directory path exists, -Not because we only have to do something if it doesn't
    if (-Not (Test-Path -LiteralPath $fileDirectoryInPatchFolder -PathType Container)) {
        #this creates the whole directory path. "| Out-Null" is just for the console output to not be messy
        New-Item -ItemType Directory -Path $fileDirectoryInPatchFolder | Out-Null
    }
}

# script

#first we grab all the file names on the new and the old version except the ignored ones
$oldVersionFiles = Get-ChildItem -Recurse -Name $oldVersionFolder -File -Exclude $ignoredFiles
$newVersionFiles = Get-ChildItem -Recurse -Name $newVersionFolder -File -Exclude $ignoredFiles

#then use a handy powershell compare tool that tells us which files exist on only one of the directories and which exist on both
# it will add the SideIndicator property to our file names
$basicCompareResult = Compare-Object -ReferenceObject $oldVersionFiles -DifferenceObject $newVersionFiles -IncludeEqual -PassThru

# this is so there's no weirdness with relative paths
$resolvedPatchFolder = Resolve-Path -LiteralPath $patchOutputFolder

# here we build the file name for a script for deleting files that got removed in the newer version, since there's no way to do that
# by copying files.
$fileRemovalScriptPath = Join-Path -Path $resolvedPatchFolder -ChildPath "delete_removed_files.bat"

# now for each comparated file...
foreach ($comparedFile in $basicCompareResult) {

    #... we check where the file is.
    if ($comparedFile.SideIndicator -eq '=>') {
        #here the file exists only on the new version, so add to the patch.

        # get the path in the new version folder
        $newVersionPath = [System.IO.Path]::Combine($newVersionFolder, $comparedFile)
        # define the path of the new file in the patch folder
        $patchPath = [System.IO.Path]::Combine($resolvedPatchFolder, $comparedFile)
        
        #report what we are doing
        Write-Host "New -> $($newVersionPath) -> $patchPath" -ForegroundColor Green

        #ensure the path exists on the patch folder (copy doesn't like when the destination folder doesn't exist yet)
        New-DirectoryIfNotExists $patchPath

        # copy the file from the new version to the patch folder.
        Copy-Item -literalPath $newVersionPath -Destination $patchPath

    }
    elseif ($comparedFile.SideIndicator -eq '<=') {
        # here the file only exists in the old version, so it was removed, 
        # best we can do is generate a script that can be run to delete the files

        #report what we are doing
        Write-Host "Removed -> $($comparedFile)" -ForegroundColor Red

        # write a line to the script with a cmd command to delete the file
        Add-Content -Path $fileRemovalScriptPath -Value "del /f $($comparedFile)"
    }
    else {
        # here the file exists in both versions, so it gets complicated.
        
        #first we grab the paths in both the old and new version
        $oldVersionPath = [System.IO.Path]::Combine($oldVersionFolder, $comparedFile)
        $newVersionPath = [System.IO.Path]::Combine($newVersionFolder, $comparedFile)
        
        #sanity check, with the old script there would be cases where the file doesn't actually exist, that should be fixed
        if ($null -ne $newVersionPath) {
            if (Test-Path -LiteralPath $newVersionPath) {
                # then we run another native powershell comparison tool to check if the files are equal. -ne means "not equal"
                if ((Get-FileHash -LiteralPath $oldVersionPath).Hash -ne (Get-FileHash -LiteralPath $newVersionPath).Hash) {
                    
                    #they aren't equal, create a path for the new version
                    $patchPath = [System.IO.Path]::Combine($resolvedPatchFolder, $comparedFile)
                    
                    # report what we are doing
                    Write-Host "Changed -> $newVersionPath -> $patchPath" -ForegroundColor Yellow
                    
                    # ensure the file has a place to go
                    New-DirectoryIfNotExists $patchPath
                    
                    # and copy the new version of the file to the patch.
                    Copy-Item -LiteralPath $newVersionPath -Destination $patchPath
                }
            }
            else {
                Write-Host "Error -> File reported as changed: $($comparedFile) but there was no new version at $newVersionPath" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Error -> Could not build a path in the new version for the file: $($comparedFile)" -ForegroundColor Red
        }
    }
}

# and that's it. once we reach this line, the patch folder should contain everything that's needed to update the game.
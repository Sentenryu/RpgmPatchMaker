#parameters

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


#utility functions

# helper function for changing the base path of a file. Example: 
# -file C:\Data\scripts\index.js 
# -from c:\Data\
# -to c:\WebSite\
# result should be: c:\WebSite\scripts\index.js
function RebasePath {
    param (
        [string] $file,
        [string] $from,
        [string] $to
    )
    $file -replace [regex]::Escape((Resolve-Path $from)), $to
}

# helper function to check if the whole folder structure of the file path exists, if it doesn't it will be created.
function New-DirectoryIfNotExists{
    param (
        [string] $filePath
    )
    #this grabs just the directory path from the file name
    $fileDirectoryInPatchFolder = Split-Path $filePath -Parent

    #this checks if the directory path exists, -Not because we only have to do something if it doesn't
    if (-Not (Test-Path -Path $fileDirectoryInPatchFolder -PathType Container)) {
        #this creates the whole directory path. "| Out-Null" is just for the console output to not be messy
        New-Item -ItemType Directory -Path $fileDirectoryInPatchFolder | Out-Null
    }
}

# script

#first we grab all the files on the new and the old version
$oldVersionFiles = Get-ChildItem -Recurse -path $oldVersionFolder -File
$newVersionFiles = Get-ChildItem -Recurse -path $newVersionFolder -File

#then use a handy powershell compare tool that tells us which files exist on only one of the directories and which exist on both
# it will add the SideIndicator property to our file objects
$basicCompareResult = Compare-Object -ReferenceObject $oldVersionFiles -DifferenceObject $newVersionFiles -IncludeEqual -PassThru

# this is so there's no weirdness with relative paths
$resolvedPatchFolder = Resolve-Path $patchOutputFolder

# here we build the file name for a script for deleting files that got removed in the newer version, since there's no way to do that
# by copying files.
$fileRemovalScriptPath = Join-Path -Path $resolvedPatchFolder -ChildPath "delete_removed_files.bat"

# now for each comparated file...
foreach ($comparedFile in $basicCompareResult) {

    #... we check where the file is.
    if($comparedFile.SideIndicator -eq '=>'){
        #here the file exists only on the new version, so add to the patch.

        # define the path of the new file in the patch folder
        $patchPath = RebasePath -file $comparedFile.Fullname -from $newVersionFolder -to $resolvedPatchFolder
        
        #report what we are doing
        Write-Host "New -> $($comparedFile.Fullname) -> $patchPath" -ForegroundColor Green

        #ensure the path exists on the patch folder (copy doesn't like when the destination folder doesn't exist yet)
        New-DirectoryIfNotExists $patchPath

        # copy the file from the new version to the patch folder.
        Copy-Item $comparedFile.Fullname -Destination $patchPath

    } elseif ($comparedFile.SideIndicator -eq '<='){
        # here the file only exists in the old version, so it was removed, 
        # best we can do is generate a script that can be run to delete the files

        #report what we are doing
        Write-Host "Removed -> $($comparedFile.Fullname)" -ForegroundColor Red

        #grab a relative version of the file path, since the script will be run from the root folder of the game.
        $patchPath = RebasePath -file $comparedFile.Fullname -from $oldVersionFolder -to ''

        # write a line to the script with a cmd command to delete the file
        Add-Content -Path $fileRemovalScriptPath -Value "del /f $($patchPath)"
    } else {
        # here the file exists in both versions, so it gets complicated.

        # first, the compare function gives us the old file path in this case, but we want the new one too, so build that path
        $newVersionPath = RebasePath -file $comparedFile.Fullname -from $oldVersionFolder -to $newVersionFolder | Resolve-Path

        # then we run another native powershell comparison tool to check if the files are equal. -ne means "not equal"
        if ((Get-FileHash $comparedFile.Fullname).Hash -ne (Get-FileHash $newVersionPath).Hash) {
            
            # here we are sure we need to update the file, so we build the path in the patch folder
            $patchPath = RebasePath -file $newVersionPath -from $newVersionFolder -to $resolvedPatchFolder

            # report what we are doing
            Write-Host "Changed -> $($newVersionPath) -> $patchPath" -ForegroundColor Yellow

            # ensure the file has a place to go
            New-DirectoryIfNotExists $patchPath

            # and copy the new version of the file to the patch.
            Copy-Item $newVersionPath -Destination $patchPath
        }
    }
}

# and that's it. once we reach this line, the patch folder should contain everything that's needed to update the game.
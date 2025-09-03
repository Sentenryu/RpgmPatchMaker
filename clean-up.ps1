$foldersToClean = (
    #'.\OldVersion\',
    #'.\NewVersion\',
    '.\Patch\'
)

Get-ChildItem -Exclude .gitkeep $foldersToClean | Remove-Item -Verbose -Recurse -Confirm:$false
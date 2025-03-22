# Patch Maker

Powershell script to make an incremental "patch" from a new and an old version of a folder structure, intended to make it easier for RPGM developers to create a patch for their games instead of reuploading the full game every time there is an update.


## Instructions

The repository illustrates the folder structure the script expects out of the box, create a new folder somewhere containing:

- NewVersion: this folder should contain the new version of the game, the same as it would be in the player's machine.
- OldVersion: this folder should contain the version the player is expected to have in their machine
- Patch: this folder should be empty, it's where the script will place the files needed to update OldVersion to NewVersion
- patch-maker.ps1: this is the script itself

All the script needs is to be run from powershell. In the script itself there are variables at the top that can be used to change the folders paths.
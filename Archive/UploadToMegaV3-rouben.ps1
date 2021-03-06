﻿<#
This script will take a file or folder path and upload it to mega, encode the link, and then put it into a persistent file.
Author: Disk546
Last modified 3/24/20

In order for this to work you need to first install megaCMD. You can get it here https://mega.nz/cmd
This has only been tested on Windows thus far. It may work on Linux but I haven't tried it.
Finally, this probably could be written better / more efficiently but I just wanted to get it working first.
If you have any questions, find any bugs, or want to help optimize this feel free to DM me. Enjoy!

#### Change Log ####
V1 Prototype build, not released publicly. 
V2 First Public release.
V3 Rewrote the login section so your password is no longer hardcoded. 
   Changed up the text file so that it creates a file and then adds to it each time so you can keep track of each encoded link.
   Finally, the part where you specify the folder/file is a little less picky.       


#### Known Issues ####
If your drive is out of space, or close to it the upload will start but when you run out the script will get stuck in an infinite loop. I plan on fixing this in the next release.
Sometimes if you run the script and MegaCMD is not already running the script will either hang or take forever to proceed. For now, just close the script and rerun it.
#>

#### Dependencies ####
# 1. PowerShell
# 2. MEGAcmd: mega-whoami (.bat), mega-login (.bat), mega-df (.bat), mega-transfers (.bat),
#    mega-export (.bat), mega-put.

#################################################################
# Detect the OS and try to set the environment variables for MEGAcmd.
if ($IsWindows) {
    $MEGApath = "$env:LOCALAPPDATA\MEGAcmd"
    $OS = "Windows"
    $PathVarSeparator = ";"
    $PathSeparator = "\"
}
elseif ($IsMacOS) {
    $MEGApath = "/Applications/MEGAcmd.app/Contents/MacOS"
    $OS = "macOS"
    $PathVarSeparator = ":"
    $PathSeparator = "/"
}
elseif ($isLinux) {
    $MEGApath = "/usr/bin"
    $OS = "Linux"
    $PathVarSeparator = ":"
    $PathSeparator = "/"
}
else {
    Write-Error "Unknown OS! Bailing..."
    Exit
}

#################################################################
# Check if MEGAcmd is already installed and in the PATH
# This gives access to the MEGAcmd executables and wrapper scripts.
$deps = "mega-whoami","mega-login","mega-df","mega-transfers","mega-export","mega-put"
foreach ($dep in $deps) {
    Write-Host -NoNewline "Checking for $dep..."
    if (Get-Command $dep -ErrorAction SilentlyContinue) { 
        Write-Host "found!"
    }
    else {
        Write-Host "not found! I'm going to try and fix this by setting PATH..."
        Write-Host "$OS detected! Assuming MEGAcmd lives under $MEGApath."
        Write-Host "Checking for MEGAcmd and setting paths. If this hangs, exit and retry." -ForegroundColor Yellow
        if (Test-Path $MEGApath) {
            $env:PATH += "$PathVarSeparator$MEGApath"
        }
        else {
            Write-Error "MEGAcmd doesn't seem to exist under $MEGApath! Please install" +
            "MEGAcmd and/or update this script accordingly."
            Exit
        }
    }
}

#################################################################
#This will test to see if a user is logged in and if not prompt them to log in
$testLogin = mega-whoami

if ($testLogin -like '*Not logged in.*')
{
    Write-Host "User not logged in, prompting for credentials" -ForegroundColor Yellow
    $creds = Get-Credential -Message "Please enter your Mega username and password" 

    mega-login $creds.UserName $creds.GetNetworkCredential().Password 
}
#################################################################
#Display who the current user is
mega-whoami
#################################################################
#Display current free space
mega-df
#################################################################
#This step asks for the file/folder path of the thing(s) you are trying to upload and then gets rid of any quotations if they appear
$FilePath = Read-Host "Enter the entire filepath of the file OR folder you want to upload. Be sure to include the file type (if applicable). This is case sensitive"

#Display the total size of the files being uploaded
$TotalSize = "{0:N2} GB" -f ((Get-ChildItem $FilePath | Measure-Object Length -Sum).sum / 1GB)
Write-Host  "Total Size of the file in GB being uploaded is" $TotalSize -ForegroundColor Yellow

#This does the upload
Write-Host "Uploading: " $FilePath -ForegroundColor Yellow
Write-Host "If you are uploading a lot of files the script might hang for a little bit." -ForegroundColor Yellow
mega-put -q $FilePath
#################################################################
#This section will show the current transfers and their upload progress. It repeats this until there are nothing being uploaded.
Do {
    $isMegaEmpty = mega-transfers --only-uploads
    Write-Host $isMegaEmpty
}
While (![string]::IsNullOrEmpty($isMegaEmpty))

#################################################################
#Now that the upload is done this section will get the link, encode it to base64, and then export it to a notepad file for easy copy pasting. We will also set the clipboard to the encoded string
#First need to get the file name. To do this we need to export the link(-a) and the -f flag to auto-accept the copyright notice
$FileName = Split-Path -Path $Filepath -Leaf
$ExportedLink = mega-export -a -f  $FileName
$ShortLink = $ExportedLink.Split(":",2)[1]    

#Next, we need to encode it.
$sEncodedString=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ShortLink))
Write-Host $sEncodedString

#Next, we are going to check and see if the destination folder exists and if not create it
$FolderPath = $HOME + $PathSeparator + "Documents" + $PathSeparator + "EncodedMegaTxts"

if (!(Test-Path $FolderPath))
{
    Write-Host "Encoded text file location does not exist creating it at "  $FolderPath
    New-Item -Path $FolderPath -ItemType Directory 
    New-Item -Path $FolderPath -Name "EncodedLinks.txt" -ItemType "file" -Value $fileValue -Force
}

#Now that we have an encoded link, we put it in a notepad file (saved to same directory as the uploaded file) and open it
$fileValue =  $FilePath + " || " + $sEncodedString + " || " + $TotalSize
Add-Content -Path ($FolderPath + $PathSeparator + "EncodedLinks.txt") -Value $fileValue  
if ($IsWindows) {
    start ($FolderPath + $PathSeparator + "EncodedLinks.txt")
}
else {
    open ($FolderPath + $PathSeparator + "EncodedLinks.txt")
}
#################################################################
#Ask for a user input before closing just in case there is an error that needs to be read before PowerShell closes
Read-Host -Prompt "Press Enter to exit"
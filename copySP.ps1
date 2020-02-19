$sourceWebURL = "http://source"
$sourceLibrary = "LibURLName"
$destWebURL = "http://destination"
$destLibrary = "LibURLName"

$sourceWeb = Get-SPWeb $sourceWebURL
$destWeb = Get-SPWeb $destWebURL
$fromLibrary = $sourceWeb.Lists | where {$_.RootFolder.Url -eq $sourceLibrary}
$libDest = $destWeb.Lists | where {$_.RootFolder.Url -eq $destLibrary}

foreach($itmSource in $fromLibrary.Items){
    write-host $itmSource["Title"]

    $fileSource = $itmSource.File
    $userCreatedBy = $fileSource.Author;
    $dateCreatedOn = $fileSource.TimeCreated.ToLocalTime();
    $countVersions = $itmSource.File.Versions.Count;

    <## This is a zero based array and so normally you'd use the < not <= but we need to get
     the current version too which is not in the SPFileVersionCollection so we're going to
     count one higher to accomplish that.##>

    for ($i = 0; $i -le $countVersions; $i++)
    {
       write-host ("Version " + $i)
       if ($i -lt $countVersions)
       {
    <#This section captures all the versions of the document and gathers the properties
     we need to add to the SPFileCollection.  Note we're getting the modified information
     and the comments seperately as well as checking if the version is a major version
     (more on that later).  I'm also getting a stream object to the file which is more efficient
     than getting a byte array for large files but you could obviously do that as well. 
     Again note I'm converting the created time to local time.#>

          $fileSourceVer = $itmSource.File.Versions[$i];
          $hashSourceProp = $fileSourceVer.Properties;
          #$userModifiedBy = (i == 0) ? userCreatedBy: fileSourceVer.CreatedBy;

          if($i -eq 0){
            $userModifiedBy = $userCreatedBy
          } else {
            $userModifiedBy = $fileSourceVer.CreatedBy
          }

          $dateModifiedOn = $fileSourceVer.Created.ToLocalTime();
          $strVerComment = $fileSourceVer.CheckInComment;

          if($fileSourceVer.VersionLabel.EndsWith("0")){
            $bolMajorVer = $true
          } else {
            $bolMajorVer = $false
          }

          $streamFile = $fileSourceVer.OpenBinaryStream();
       }
       else
       {
    <#Here I'm getting the information for the current version.  Unlike in SPFileVersion when
     I get the modified date from SPFile it's already in local time.#>
          $userModifiedBy = $fileSource.ModifiedBy;
          $dateModifiedOn = $fileSource.TimeLastModified;
          $hashSourceProp = $fileSource.Properties;
          $strVerComment = $fileSource.CheckInComment;

          if($fileSource.MinorVersion -eq 0){
            $bolMajorVer = $true
          } else {
            $bolMajorVer = $false
          }

          $streamFile = $fileSource.OpenBinaryStream();
       }
       [string]$urlDestFile = $libDest.RootFolder.Url + "/" + $fileSource.Name;
    <#Here I'm using the overloaded Add method to add the file to the SPFileCollection. 
     Even though this overload takes the created and modified dates for some reason they aren't
     visible in the SharePoint UI version history which shows the date/time the file was added
     instead, however if this were a Microsoft Word document and I opened it in Word 2010 and looked
     at the version history it would all be reflective of the values passed to this Add method.
     I'm voting for defect but there could just be something I'm missing.#>
       
       $userCreatedByEnsure = $destWeb.EnsureUser($userCreatedBy.UserLogin)
       $userModifiedByEnsure = $destWeb.EnsureUser($userModifiedBy.UserLogin)
       $fileDest = $libDest.RootFolder.Files.Add(
           $urlDestFile,
           $streamFile,
           $hashSourceProp,
           ([Microsoft.SharePoint.SPUser]$userCreatedByEnsure),
           ([Microsoft.SharePoint.SPUser]$userModifiedByEnsure),
           $dateCreatedOn,
           $dateModifiedOn,
           $strVerComment,
           $true)
       if ($bolMajorVer) {
    <#Here we're checking if this is a major version and calling the publish method, passing in
     the check-in comments.  Oddly when the publish method is called the passed created and
     modified dates are displayed in the SharePoint UI properly without further adjustment.#>
           ## $fileDest.Publish($strVerComment);
       }
       else
       {
    <#Setting the created and modified dates in the SPListItem which corrects the display in the
     SharePoint UI version history for the draft versions.#>
          $itmNewVersion = $fileDest.Item;
          $itmNewVersion["Created"] = $dateCreatedOn;
          $itmNewVersion["Modified"] = $dateModifiedOn;
          $itmNewVersion.UpdateOverwriteVersion();
       }
    }
}

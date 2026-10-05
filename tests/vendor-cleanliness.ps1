param([string]$ExtraSource='', [string]$ExtraBinary='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$profile=[IO.File]::ReadAllText("$root/profiles/ohm-api30-arm32.json") | ConvertFrom-Json
if(-not ('VendorDataScan' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Security.Cryptography;
public static class VendorDataScan {
 public static bool Contains(byte[] bytes,int start,int count,int length,string expected) {
  using(var hash=SHA256.Create()) {
   for(int i=start;i<=start+count-length;i++) {
    string found=BitConverter.ToString(hash.ComputeHash(bytes,i,length)).Replace("-","").ToLowerInvariant();
    if(found==expected) return true;
   }
  }
  return false;
 }
 public static bool DataContains(byte[] elf,int length,string expected) {
  if(elf.Length<52 || elf[0]!=127 || elf[1]!=69 || elf[4]!=1) throw new Exception("Invalid ELF");
  int table=(int)BitConverter.ToUInt32(elf,32);
  int stride=BitConverter.ToUInt16(elf,46), number=BitConverter.ToUInt16(elf,48);
  for(int i=0;i<number;i++) {
   int entry=table+i*stride;
   uint type=BitConverter.ToUInt32(elf,entry+4), flags=BitConverter.ToUInt32(elf,entry+8);
   int offset=(int)BitConverter.ToUInt32(elf,entry+16), size=(int)BitConverter.ToUInt32(elf,entry+20);
   // All stored allocated non-executable sections: validation data, not opcodes.
   if(type!=8 && (flags&2)!=0 && (flags&4)==0 && Contains(elf,offset,size,length,expected)) return true;
   // Also inspect STT_OBJECT symbol ranges in executable sections (literal arrays).
   if(type==2 || type==11) {
    int symbolStride=(int)BitConverter.ToUInt32(elf,entry+36);
    if(symbolStride==0) continue;
    for(int s=offset;s<offset+size;s+=symbolStride) {
     if((elf[s+12]&15)!=1) continue;
     int section=BitConverter.ToUInt16(elf,s+14);
     if(section<=0 || section>=number) continue;
     int sh=table+section*stride;
     uint sf=BitConverter.ToUInt32(elf,sh+8);
     if((sf&4)==0) continue;
     int pos=(int)(BitConverter.ToUInt32(elf,sh+16)+BitConverter.ToUInt32(elf,s+4)-BitConverter.ToUInt32(elf,sh+12));
     int len=(int)BitConverter.ToUInt32(elf,s+8);
     if(Contains(elf,pos,len,length,expected)) return true;
    }
   }
  }
  return false;
 }
}
'@
}
$signatures=@($profile.library.signatures)+@([pscustomobject]@{length=$profile.library.siteBLength;sha256=$profile.library.originalSha256})
function CheckText([string]$text,[string]$name) {
    $chunks=@()
    $chunks+=,[Text.Encoding]::UTF8.GetBytes($text)
    # Decode quoted hex data and C/C++ byte lists without storing vendor bytes.
    foreach($match in [regex]::Matches($text,'(?i)\b[0-9a-f]{8,}\b')) {
        $hex=$match.Value
        if($hex.Length%2){continue}
        $bytes=New-Object byte[] ($hex.Length/2)
        for($i=0;$i -lt $bytes.Length;$i++){$bytes[$i]=[Convert]::ToByte($hex.Substring(2*$i,2),16)}
        $chunks+=,$bytes
    }
    foreach($match in [regex]::Matches($text,'(?i)(?:0x[0-9a-f]{2}\s*,\s*){3,}0x[0-9a-f]{2}\b')) {
        $bytes=[byte[]]@([regex]::Matches($match.Value,'(?i)0x([0-9a-f]{2})')|ForEach-Object {[Convert]::ToByte($_.Groups[1].Value,16)})
        $chunks+=,$bytes
    }
    foreach($match in [regex]::Matches($text,'(?i)(?<![0-9a-z])(?:[0-9a-f]{2}\s+){3,}[0-9a-f]{2}(?![0-9a-z])')) {
        $bytes=[byte[]]@([regex]::Matches($match.Value,'(?i)[0-9a-f]{2}')|ForEach-Object {[Convert]::ToByte($_.Value,16)})
        $chunks+=,$bytes
    }
    foreach($chunk in $chunks){foreach($s in $signatures){
        if([VendorDataScan]::Contains($chunk,0,$chunk.Length,$s.length,$s.sha256)){throw "VENDOR_SIGNATURE_DATA: $name"}
    }}
}
foreach($file in Get-ChildItem $root -Recurse -Force -File){
    $bytes=[IO.File]::ReadAllBytes($file.FullName)
    if($file.Extension -eq '.so'){
        foreach($s in $signatures){if([VendorDataScan]::DataContains($bytes,$s.length,$s.sha256)){throw "VENDOR_VALIDATION_ARRAY: $($file.Name)"}}
    }else{CheckText ([Text.Encoding]::UTF8.GetString($bytes)) $file.Name}
}
if($ExtraSource){
    if(Test-Path -LiteralPath $ExtraSource -PathType Container){
        foreach($file in Get-ChildItem -LiteralPath $ExtraSource -Recurse -File){CheckText ([IO.File]::ReadAllText($file.FullName)) $file.Name}
    }else{CheckText ([IO.File]::ReadAllText($ExtraSource)) 'candidate source'}
}
if($ExtraBinary){foreach($s in $signatures){if([VendorDataScan]::DataContains([IO.File]::ReadAllBytes($ExtraBinary),$s.length,$s.sha256)){throw 'VENDOR_VALIDATION_ARRAY: candidate'}}}
'VENDOR_BYTE_CLEANLINESS_PASS (executable coincidences excluded)'

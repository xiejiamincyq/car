#requires -Version 7.0
# Real native name-collision check. The first empty session is owned by this test.
$ErrorActionPreference='Stop'
if(-not $IsWindows -or [IntPtr]::Size -ne 8){throw 'Windows x64 required'}
Add-Type -Path (Join-Path $PSScriptRoot 'rc_independent_etw.cs')
$root=Join-Path (Join-Path $PSScriptRoot '../../tmp') ('etw-ownership-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $root)
$properties=[Runtime.InteropServices.Marshal]::AllocHGlobal(4216)
$type=[CarRcCapture.IndependentEtw]
$flags=[Reflection.BindingFlags]'Static,NonPublic'
$start=$type.GetMethod('Start',$flags);$query=$type.GetMethod('Query',$flags);$stop=$type.GetMethod('Stop',$flags)
$owned=$false
try {
    [Runtime.InteropServices.Marshal]::Copy([byte[]]::new(4216),0,$properties,4216)
    foreach($field in @{0=4216;40=1;44=0x20000;48=64;52=2;56=4;60=1;64=0x08000001;112=2168;116=120}.GetEnumerator()) {
        [Runtime.InteropServices.Marshal]::WriteInt32($properties,[int]$field.Key,[int]$field.Value)
    }
    foreach($field in @{120=$type::SessionName;2168=(Join-Path $root 'first.etl')}.GetEnumerator()) {
        $bytes=[Text.Encoding]::Unicode.GetBytes([string]$field.Value+[char]0)
        [Runtime.InteropServices.Marshal]::Copy($bytes,0,[IntPtr]::Add($properties,[int]$field.Key),$bytes.Length)
    }
    $startArguments=[object[]]@([ulong]0,$type::SessionName,$properties)
    $startExit=$start.Invoke($null,$startArguments)
    if($startExit -ne 0){throw "Test refused existing/unavailable session: $startExit"}
    $owned=$true;$handle=[ulong]$startArguments[0]
    $collision=$type::Capture((Join-Path $root 'second.etl'),1)
    if($collision.StartExit -ne 183 -or $collision.StopExit -ne [uint32]::MaxValue){throw 'Collision did not fail without stopping the existing session'}
    $queryExit=$query.Invoke($null,[object[]]@($handle,$type::SessionName,$properties,[uint32]0))
    if($queryExit -ne 0){throw 'Existing owned session was stopped by rejected capture'}
    Write-Output 'RC_INDEPENDENT_OWNERSHIP_PASS collision=183 existing_query=0 second_stop=not_attempted'
} finally {
    if($owned){
        $stopExit=$stop.Invoke($null,[object[]]@($handle,$type::SessionName,$properties))
        if($stopExit -ne 0){Write-Error "Owned test session cleanup failed: $stopExit" -ErrorAction Continue}
    }
    [Runtime.InteropServices.Marshal]::FreeHGlobal($properties)
}
if($owned -and $stopExit -ne 0){exit 1}
$oldEtl=Join-Path $root 'first.etl'
$originalHash=(Get-FileHash -LiteralPath $oldEtl).Hash
$rejected=$false
try{$null=$type::Capture($oldEtl,1)}catch{$rejected=$_.Exception.InnerException -is [ArgumentException]}
if(-not $rejected -or (Get-FileHash -LiteralPath $oldEtl).Hash -ne $originalHash){throw 'Native capture overwrote prior ETL evidence'}
Write-Output 'RC_INDEPENDENT_OWNERSHIP_PASS existing_etl_rejected hash_unchanged'

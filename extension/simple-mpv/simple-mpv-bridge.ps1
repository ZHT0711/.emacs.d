$in = [System.IO.Pipes.NamedPipeClientStream]::new('.', 'simple-mpv', 'InOut')
$in.Connect()
$out = [System.IO.StreamWriter]::new($in)
$out.AutoFlush = $true
$read = [System.IO.StreamReader]::new($in)
while ($line = [Console]::In.ReadLine()) {
    $out.WriteLine('{"command":[' + $line + ']}')
    [Console]::Out.WriteLine($read.ReadLine())
}
$in.Dispose()

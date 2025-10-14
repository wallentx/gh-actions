# Description: This script retrieves hardware information about the CPU and memory from the local system using Windows Management Instrumentation, specifically the model, number of cores, number of threads, and total capacity. It then sets these values as system environment variables in the local GitHub environment.

$CPU = Get-CimInstance -ClassName Win32_Processor
$CPU_MODEL = $CPU.Name
echo "Set CPU_MODEL=$CPU_MODEL"
echo "CPU_MODEL=$CPU_MODEL" >>"$env:GITHUB_ENV"
$CPU_CORES = $CPU.NumberOfCores
echo "Set CPU_CORES=$CPU_CORES"
echo "CPU_CORES=$CPU_CORES" >>"$env:GITHUB_ENV"
$CPU_THREADS = $CPU.NumberOfLogicalProcessors
echo "Set CPU_THREADS=$CPU_THREADS"
echo "CPU_THREADS=$CPU_THREADS" >>"$env:GITHUB_ENV"
$MEM = Get-CimInstance -ClassName Win32_PhysicalMemory
$MEM_TOTAL = $MEM.Capacity
$MEM_TOTAL = "$([int64]($MEM.Capacity | Measure-Object -Sum).Sum / 1GB)GB"
echo "Set MEM_TOTAL=$MEM_TOTAL"
echo "MEM_TOTAL=$MEM_TOTAL" >>"$env:GITHUB_ENV"

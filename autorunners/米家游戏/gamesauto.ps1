chcp 65001
# 引入 Windows Forms 来模拟键盘操作（如果需要）
Write-Host "激活屏幕"
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}")
Start-Sleep -Milliseconds 100
[System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}")

Write-Host "临时修改电源计划为从不"
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0

# 定义要启动的主应用程序列表
$mainapps = @(
    "D:\greenapp\March7thAssistant\March7th Assistant.exe",
    "D:\greenapp\ZenlessZoneZero-OneDragon\OneDragon Scheduler.exe",
    "D:\greenapp\BetterGI\start.exe"
)

# 定义副启动的应用程序列表(如被启动的游戏列表，与上方必须对应)
$Subapps = @(
    "StarRail.exe",
    "ZenlessZoneZero.exe",
    "YuanShen.exe"
)

# 定义函数用于程序监控
function Wait-MainExit-KillSub {
    param (
        [string]$MainAppPath,
        [string]$SubProcessName,
        [int]$MaxTimeout = 3600,
        [int]$Interval = 30
    )

    $timeout = 0
    Write-Host "开始监控主进程：$MainAppPath，超时时间$MaxTimeout 秒"

    while ($true) {
        # 获取主进程
        $mainProc = Get-Process | Where-Object {
            $_.Path -eq $MainAppPath
        }

        # 如果主进程不再存在或超时，退出循环
        if (-not $mainProc) {
            Write-Host "主进程已退出。"
            break
        }

        if ($timeout -ge $MaxTimeout) {
            Write-Host "主进程超时 $MaxTimeout 秒，强制终止主进程..."
            try {
                $mainProc | Stop-Process -Force -ErrorAction Stop
                Write-Host "主进程已被强制终止。"
            } catch {
                Write-Host "主进程终止失败：$($_.Exception.Message)"
            }
            break
        }

        if ($MainAppPath -eq "D:\greenapp\March7thAssistant\March7th Assistant.exe") {
            Write-Host "检测到 March7th Assistant 仍在运行，模拟回车..."
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        }

        Start-Sleep -Seconds $Interval
        $timeout += $Interval
    }

    # 无论如何都尝试终止副进程
    Write-Host "检查并尝试终止副进程：$SubProcessName"
    $result = taskkill /F /IM $SubProcessName /T 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$SubProcessName 已成功终止"
    } elseif ($result -match "not found") {
        Write-Host "$SubProcessName 未在运行中"
    } else {
        Write-Host "终止 $SubProcessName 失败：$result"
    }
}

# 启动程序
for ($i = 0; $i -lt $mainapps.Count; $i++) {
    $mainapp = $mainapps[$i]
    $subapp = $subapps[$i]
    $startArgs = @{
        FilePath = $mainapp
    }
    if ($mainapp -eq "D:\greenapp\March7thAssistant\March7th Assistant.exe") {
        $startArgs["PassThru"] = $true
    } elseif ($mainapp -ne "D:\greenapp\BetterGI\start.exe") {
        $startArgs["Wait"] = $true
    }
    Write-Host "正在启动主程序 $mainapp"
    Start-Process @startArgs
    if ($mainapp -eq "D:\greenapp\BetterGI\start.exe") {
        $mainapp = "D:\greenapp\BetterGI\BetterGI.exe"
        Write-Host "监控主进程改为：$mainapp"
        $maxWait = 15
        $waited = 0
        while (-not (Get-Process | Where-Object { $_.Path -eq $mainapp }) -and $waited -lt $maxWait) {
            Start-Sleep -Seconds 1
            $waited++
            Write-Host "等待中... $waited 秒"
        }

        if ($waited -ge $maxWait) {
            Write-Host "BetterGI.exe 未在预期时间内启动"
        } else {
            Write-Host "BetterGI.exe 启动成功"
            Wait-MainExit-KillSub -MainAppPath $mainapp -SubProcessName $subapp
        }
    }
    Wait-MainExit-KillSub -MainAppPath $mainapp -SubProcessName $subapp
}

# 进入睡眠状态
Write-Host "执行完毕，60秒后准备进入睡眠..."
Start-Sleep -Seconds 60  # 60秒后进入睡眠
rundll32.exe powrprof.dll,SetSuspendState Sleep
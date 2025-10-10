# Minh Nguyen DevKit

DevKit is a portable development environment for Windows. Here’s a quick-start guide to get you up and running.

## 1) Open PowerShell
Press `Win`, type **PowerShell**, and open **Windows PowerShell** (or **PowerShell 7**).

## 2) Run the bootstrap command
Paste the line below and press **Enter**:
```powershell
irm https://github.com/minhnguyenerp/mingit/raw/main/launch.ps1 | iex
```
Wait until it finishes. When it’s done, a Command Prompt window will open automatically.

## 3) Choose where to place DevKit.
In the Command Prompt window, change to your desired folder, e.g.:
```bat
cd /d C:\Data
```

## 4) Clone the repository
Run
```bat
git clone https://github.com/minhnguyenerp/devkit.git
```
This creates a `devkit` folder under `C:\Data`

_(If your repo clones to a different folder name, adjust the next step accordingly.)_

## 5) Launch DevKit
```bat
cd C:\Data\devkit
start
```
You’re all set—DevKit will initialize and open a ready-to-use shell. Next time, you can start by running `C:\Data\devkit\start.bat`.

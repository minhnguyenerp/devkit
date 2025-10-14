# Minh Nguyen DevKit

Minh Nguyen DevKit is a portable development environment for Windows. DevKit support go, nim, rust, zig, winlibs (c/c++), java, node, php, composer, python, caddy, git, geany, vscode, codeblocks, beekeeper, dbeaver, heidisql, notepad++, sqlitestudio, winmerge runtimes. Here’s a quick-start guide to get you up and running.

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
start.bat
```
You’re all set—DevKit will initialize and open a ready-to-use shell. Next time, you can start by running `C:\Data\devkit\start.bat`.

## 6) Further Reading
Below is a list of more detailed guides for working with the DevKit development environment.

[Use Minh Nguyen DevKit with Cursor](docs/Use%20Minh%20Nguyen%20DevKit%20with%20Cursor.md)

[Use Minh Nguyen DevKit to create a NextJS project](docs/Use%20Minh%20Nguyen%20DevKit%20to%20create%20a%20NextJS%20project.md)

[Use Minh Nguyen DevKit to create a Rust - Axum project](docs/Use%20Minh%20Nguyen%20DevKit%20to%20create%20a%20Rust%20-%20Axum%20project.md)

[Use Minh Nguyen DevKit to create a Go - Gin project](docs/Use%20Minh%20Nguyen%20DevKit%20to%20create%20a%20Go%20-%20Gin%20project.md)

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

func main() {
	if runtime.GOOS != "windows" {
		fmt.Println("[Z-WIN-1-01] This program only works on Windows.")
		return
	}

	_, err := exec.LookPath("git")
	if err != nil {
		fmt.Println("[Z-WIN-1-02] Git is not installed. Installing via winget...")

		cmd := exec.Command("cmd", "/C", "winget install --id Git.Git -e --silent")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			fmt.Println("[Z-WIN-1-03] Error installing Git via winget:", err)
			return
		}
	} else {
		fmt.Println("[Z-WIN-1-04] Git is already installed.")
	}

	userHome, err := os.UserHomeDir()
	if err != nil {
		fmt.Println("[Z-WIN-1-05] Error getting home directory:", err)
		return
	}

	zhivaPath := filepath.Join(userHome, ".zhiva")
	if _, err := os.Stat(zhivaPath); os.IsNotExist(err) {
		fmt.Println("[Z-WIN-1-06] .zhiva does not exist, running PowerShell...")
		psCmd := `irm https://raw.githubusercontent.com/wxn0brP/Zhiva-scripts/master/install/prepare.ps1 | iex`
		cmd := exec.Command("powershell", "-c", psCmd)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err := cmd.Run()
		if err != nil {
			fmt.Println("[Z-WIN-1-07] Error running PowerShell:", err)
			return
		}

		fmt.Println("[Z-WIN-1-08] Adding .zhiva to PATH...")
		pathAddCmd := fmt.Sprintf(`$env:PATH += ";%s"; [Environment]::SetEnvironmentVariable("PATH", $env:PATH, "User")`, zhivaPath)
		cmd = exec.Command("powershell", "-Command", pathAddCmd)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			fmt.Println("[Z-WIN-1-09] Error adding to PATH:", err)
			return
		}
	} else {
		fmt.Println("[Z-WIN-1-10] .zhiva already exists.")
	}

	fmt.Println("[Z-WIN-1-11] Ready.")
}

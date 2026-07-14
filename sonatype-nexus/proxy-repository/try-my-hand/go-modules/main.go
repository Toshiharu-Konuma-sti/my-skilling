package main

import (
	"fmt"
	"io"
	"net/http"

	"github.com/fatih/color"
)

func main() {
	color.Cyan("==========================================")
	color.Cyan("   Go (modules) Repository Manager Demo  ")
	color.Cyan("==========================================")

	resp, err := http.Get("https://api.github.com/zen")
	if err != nil {
		color.Red("Error: %v", err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	color.Green("GitHub Zen Message: %s", string(body))
	color.Cyan("==========================================")
	fmt.Println()
}

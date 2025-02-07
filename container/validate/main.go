package main

import (
	"os"

	"github.com/agnivade/levenshtein"
)

func main() {
	source, err := os.ReadFile("cast-instance.yaml")
	if err != nil {
		panic(err)
	}

	dest, err := os.ReadFile("cast-instance-tweaked.yaml")
	if err != nil {
		panic(err)
	}

	distance := levenshtein.ComputeDistance(string(source), string(dest))
	println(distance)
}

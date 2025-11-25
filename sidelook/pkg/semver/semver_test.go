// pkg/semver/semver_test.go
package semver

import "testing"

func TestNormalize(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"v1.2.3", "1.2.3"},
		{"1.2.3", "1.2.3"},
		{"v1.2.3-beta", "1.2.3"},
		{"1.2.3+build", "1.2.3"},
		{"V1.2.3", "1.2.3"},
		{"  v1.2.3  ", "1.2.3"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := Normalize(tt.input)
			if result != tt.expected {
				t.Errorf("Normalize(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestParse(t *testing.T) {
	tests := []struct {
		input    string
		expected [3]int
	}{
		{"1.2.3", [3]int{1, 2, 3}},
		{"1.2", [3]int{1, 2, 0}},
		{"1", [3]int{1, 0, 0}},
		{"v1.2.3", [3]int{1, 2, 3}},
		{"", [3]int{0, 0, 0}},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			result := Parse(tt.input)
			if result != tt.expected {
				t.Errorf("Parse(%q) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestCompare(t *testing.T) {
	tests := []struct {
		local    string
		remote   string
		expected Comparison
	}{
		{"1.0.0", "1.0.0", Equal},
		{"1.0.0", "2.0.0", Older},
		{"2.0.0", "1.0.0", Newer},
		{"1.1.0", "1.2.0", Older},
		{"1.0.0", "1.0.1", Older},
		{"v1.0.0", "1.0.0", Equal},
		{"1.0.0-beta", "1.0.0", Equal},
	}

	for _, tt := range tests {
		name := tt.local + "_vs_" + tt.remote
		t.Run(name, func(t *testing.T) {
			result := Compare(tt.local, tt.remote)
			if result != tt.expected {
				t.Errorf("Compare(%q, %q) = %v, want %v", tt.local, tt.remote, result, tt.expected)
			}
		})
	}
}

func TestHasUpdate(t *testing.T) {
	if !HasUpdate("1.0.0", "1.0.1") {
		t.Error("HasUpdate(1.0.0, 1.0.1) should be true")
	}
	if HasUpdate("1.0.0", "1.0.0") {
		t.Error("HasUpdate(1.0.0, 1.0.0) should be false")
	}
	if HasUpdate("2.0.0", "1.0.0") {
		t.Error("HasUpdate(2.0.0, 1.0.0) should be false")
	}
}

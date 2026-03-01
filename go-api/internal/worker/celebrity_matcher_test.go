package worker

import (
	"testing"
)

func TestNormalizeCaseName(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			"simple lowercase",
			"John Smith",
			"john smith",
		},
		{
			"last comma first",
			"SMITH, JOHN",
			"john smith",
		},
		{
			"with titles",
			"Mr. John Smith Jr.",
			"john smith",
		},
		{
			"with legal suffix",
			"People v. John Smith et al.",
			"people john smith",
		},
		{
			"complex case name",
			"STATE OF CALIFORNIA v. SIMPSON, ORENTHAL JAMES",
			"state of california orenthal james simpson",
		},
		{
			"with punctuation",
			"O'Brien, Thomas J.",
			"thomas obrien",
		},
		{
			"with inc suffix",
			"John Smith Inc. v. Jane Doe LLC",
			"john smith jane doe",
		},
		{
			"multiple spaces",
			"  SMITH ,  JOHN   ROBERT  ",
			"john robert smith",
		},
		{
			"empty string",
			"",
			"",
		},
		{
			"with judge title",
			"Judge William Brown",
			"william brown",
		},
		{
			"with dr title",
			"Dr. Conrad Murray",
			"conrad murray",
		},
		{
			"et al removal",
			"Smith, John et al",
			"john smith",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := normalizeCaseName(tt.input)
			if got != tt.want {
				t.Errorf("normalizeCaseName(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestIsMatch(t *testing.T) {
	tests := []struct {
		name      string
		caseName  string
		celebName string
		wantMatch bool
		minScore  float64
	}{
		{
			"full match",
			"john smith",
			"John Smith",
			true,
			1.0,
		},
		{
			"partial match in larger name",
			"people john robert smith case",
			"John Smith",
			true,
			0.9,
		},
		{
			"no match",
			"jane doe",
			"John Smith",
			false,
			0,
		},
		{
			"single word celebrity (should not match)",
			"cher performing live",
			"Cher",
			false,
			0,
		},
		{
			"all words match",
			"orenthal james simpson",
			"Orenthal James Simpson",
			true,
			1.0,
		},
		{
			"two of three words match",
			"james simpson trial",
			"Orenthal James Simpson",
			true,
			0.6,
		},
		{
			"empty case name",
			"",
			"John Smith",
			false,
			0,
		},
		{
			"empty celebrity name",
			"john smith",
			"",
			false,
			0,
		},
		{
			"skip single char initial",
			"john a smith",
			"John A Smith",
			true,
			0.6, // "A" is skipped, so 2 of 3 meaningful words match
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			score := isMatch(tt.caseName, tt.celebName)

			if tt.wantMatch && score == 0 {
				t.Errorf("isMatch(%q, %q) = 0, expected match", tt.caseName, tt.celebName)
			}
			if !tt.wantMatch && score > 0 {
				t.Errorf("isMatch(%q, %q) = %f, expected no match", tt.caseName, tt.celebName, score)
			}
			if tt.wantMatch && score < tt.minScore {
				t.Errorf("isMatch(%q, %q) = %f, expected >= %f", tt.caseName, tt.celebName, score, tt.minScore)
			}
		})
	}
}

func TestNormalizeThenMatch(t *testing.T) {
	// End-to-end: normalize a case name, then check if it matches a celebrity
	tests := []struct {
		caseName  string
		celebName string
		wantMatch bool
	}{
		{"SMITH, JOHN v. STATE", "John Smith", true},
		{"People v. Simpson, Orenthal James", "OJ Simpson", false}, // "OJ" is 2 chars but not in name
		{"BROWN, CHRISTOPHER MAURICE", "Chris Brown", false},       // Chris != Christopher
		{"DOE, JANE MARIE et al.", "Jane Doe", true},
		{"WEST, KANYE OMARI", "Kanye West", true},
	}

	for _, tt := range tests {
		t.Run(tt.caseName, func(t *testing.T) {
			normalized := normalizeCaseName(tt.caseName)
			score := isMatch(normalized, tt.celebName)

			if tt.wantMatch && score == 0 {
				t.Errorf("Expected match for case=%q (normalized=%q), celeb=%q", tt.caseName, normalized, tt.celebName)
			}
			if !tt.wantMatch && score > 0 {
				t.Errorf("Unexpected match (score=%f) for case=%q (normalized=%q), celeb=%q", score, tt.caseName, normalized, tt.celebName)
			}
		})
	}
}

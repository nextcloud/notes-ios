#!/bin/zsh

# Function to generate random blind text
generate_text() {
  if command -v gshuf &> /dev/null; then
    gshuf -n 30 /usr/share/dict/words | tr '\n' ' '
  else
    echo "gshuf not found. Please install coreutils with 'brew install coreutils'." >&2
    exit 1
  fi
}

# Function to generate a short unique file name
generate_filename() {
  if command -v gshuf &> /dev/null; then
    echo "$(gshuf -n 1 /usr/share/dict/words)_$(gshuf -n 1 /usr/share/dict/words).md"
  else
    echo "file_$(date +%s%N).md"
  fi
}

# Generate 1000 markdown files
for i in {1..1000}; do
  FILE_NAME="$(generate_filename)"
  echo "# $(basename "$FILE_NAME" .md)" > "$FILE_NAME"
  echo "" >> "$FILE_NAME"
  echo "$(generate_text)" >> "$FILE_NAME"
  echo "Generated: $FILE_NAME"
done

echo "All markdown files have been generated."
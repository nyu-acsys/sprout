#!/bin/bash

set -u

if [ $# -ne 1 ]; then
  echo "Usage: $0 <number_of_iterations>"
  exit 1
fi

# Define the number of iterations
n=$1

# Define the output file and aggregation file 
output_file="../examples/sprout/sprout_output_woto.txt"
aggregation_file="../examples/sprout/sprout_output_woto_aggregation.txt"

# Clear the output file if it exists, or create a new one
> "$output_file"
> "$aggregation_file"

# Base directory where the files are located
base_dir="../examples/sprout"

# List of examples to verify
files=(
  "calculator"
  "fibonacci"
  "higher-lower"
  "http"
  "negotiation"
  "online-wallet"
  # "sh"
  "ticket"
  "travel-agency"
  "two-buyer"
  "double-buffering"
  "oauth"
  "plus-minus"
  "ring-max"
  "simple-auth"
  "travel-agency2"
  # 
  "send-validity-yes"
  "send-validity-no"
  "receive-validity-yes"
  "receive-validity-no"
  "symbolic-two-bidder-yes"
  "symbolic-two-bidder-no1"
  "figure12-yes"
  "figure12-no"
  "symbolic-send-validity-yes"
  "symbolic-send-validity-no"
  "symbolic-receive-validity-yes"
  "symbolic-receive-validity-no"
  "fwd-auth-yes"
  # "fwd-auth-no"
  "symbolic-two-bidder-no2"
  "higher-lower-ultimate"
  # "higher-lower-winning"
  "higher-lower-no"
  "higher-lower-encrypt-yes"
  "higher-lower-encrypt-no"
  "higher-lower-mixed"
)

# Removing generated files before the experiment 
sh cleanup.sh

# Iterate over the files
for file in "${files[@]}"; do
  # Construct the full path to the file
  full_path="$base_dir/$file"
  
  # Check if file exists
  if [ ! -f "$full_path" ]; then
    echo "Warning: File $full_path not found. Skipping." >> "$output_file"
    continue
  fi

  # Add a header for each file in the output
  echo "Processing $file" >> "$output_file"
  echo "----------------------------------------" >> "$output_file"
  # Run the command n times and append output to the file
  for ((i=1; i<=n; i++)); do
    # Cleanup generated files before each iteration
    sh cleanup.sh 

    # Important that this is outside of the loop!
    res="" # Initialize res to empty 
    time=""
    # Capture output line-by-line
    while IFS= read -r line; do
      # Write to output file
      echo "$line" >> "$output_file"
      
      # Only if Killed is present, set res to "Killed"
      if [[ "$line" == "Killed"* ]]; then
        res="oom"
        continue
      fi 

      # Check for verification time line
      if [[ "$line" == "Total verification time:"* ]]; then
        # Extract time using parameter expansion (works on all systems)
        time="${line#*Total verification time:}"
        time="${time%%,*}"
        # Only modify res if it hasn't already been set to Killed 
        if [[ "$res" != "oom" ]]; then
          res="${line##*, }" 
        fi 
      fi
    done < <(./_build/default/main.exe "$full_path" 40 opt parallel 2>&1)
    
    echo "$file iteration $i: ${time}, ${res}"
    echo "$file iteration $i: ${time}, ${res}" >> "$aggregation_file"
    echo "----" >> "$output_file"  # Separator between iterations
  done
  
  echo -e "\n\n" >> "$output_file"
  echo "$file verified."
done

# Removing generated files after the experiment 
sh cleanup.sh 

echo "All examples verified $n times; results saved in $output_file."

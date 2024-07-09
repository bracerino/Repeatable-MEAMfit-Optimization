#!/bin/bash

# Define the source and target directories
source_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/all_vasp_files"
target_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/Fit_EAM"
target_test_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/Test_set"
num_files=10
num_iterations=50
num_processors=8
meamfit_binary=meamfit




input_file="./fitted_quantities.out"
second_input="./bestoptfuncs"
# Path to the output file
output_file="../output_file.txt"
echo "Objective_function Variances_Energy Variances_Forces RMS_Energies RMS_Forces TEST_Variances_Energy TEST_Variances_Forces TEST_RMS_Energies TEST_RMS_Forces File_Name" >> "$output_file"


SCRIPT_PATH="$(realpath "$0")"
# Extract the directory from the full path
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

for iteration in $(seq 1 $num_iterations); do
echo "Iteration $iteration"


# Navigate to the source directory

cd "$source_dir" || exit


# Randomly select files
selected_files=$(find . -type f | shuf -n "$num_files")
mapfile -t all_files < <(find . -type f)
#mapfile -t selected_files < <(find . -type f | shuf -n "$num_files")
mapfile -t not_selected_files < <(printf "%s\n" "${all_files[@]}" | grep -vxFf <(printf "%s\n" "${selected_files[@]}"))

mkdir -p "${SCRIPT_DIR}/Selected_files_RANDOM/"
selected_files_output="${SCRIPT_DIR}/Selected_files_RANDOM/selected_files_${iteration}.txt"
printf "%s\n" "${selected_files[@]}" > "$selected_files_output"


counter=1
    for file in $selected_files; do
  	echo "$file"
        cp "$file" "$target_dir/vasprun_${counter}.xml"
        ((counter++))
    done
    counter=1 # Reset counter for all_files
    all_files
    #for file in "${not_selected_files[@]}"; do #uncomment this and comment the line below if you wish to have only non-selected files for the fitting in the test folder
    for file in "${all_files[@]}"; do
        target_file="$target_test_dir/vasprun_${counter}.xml"
        if [[ ! -f "$target_file" ]]; then
          cp "$file" "$target_file"
        fi
    done

# Run the command (replace 'meamfit' with the actual command you need to run)
cd "$target_dir" || exit
rm fitdbse
mpirun -np $num_processors $meamfit_binary
mpirun -np $num_processors $meamfit_binary


awk_output=$(awk '/Variances of energies, forces and stress tensor components:/{ getline; energy_variance=$1; force_variance=$2 }
     /rms error on energies=/{ rms_error_on_energies=$5 }
     /rms error on forces=/{ rms_error_on_forces=$5 }
     END{ printf "%f %f %f %f", energy_variance, force_variance, rms_error_on_energies, rms_error_on_forces }' "$input_file")
extracted_number=$(awk '/^[[:space:]]*1:/{ print $2; exit }' "$second_input")


#TEST DATA

cp "potparas_best1" "$target_test_dir/potparas_best1"
cd "$target_test_dir" || exit
rm fitdbse
mpirun -np 1 $meamfit_binary
mpirun -np 1 $meamfit_binary


awk_output_2=$(awk '/Variances of energies, forces and stress tensor components:/{ getline; energy_variance=$1; force_variance=$2 }
     /rms error on energies=/{ rms_error_on_energies=$5 }
     /rms error on forces=/{ rms_error_on_forces=$5 }
     END{ printf "%f %f %f %f", energy_variance, force_variance, rms_error_on_energies, rms_error_on_forces }' "$input_file")

final_output="${extracted_number} ${awk_output} ${awk_output_2} "selected_files_${iteration}.txt""
echo "$final_output" >> "$output_file"


# Delete only the copied files from the target directory
find "$target_dir" -type f -name 'vasprun_*.xml' -exec rm -f {} +
#find "$target_test_dir" -type f -name 'vasprun_*.xml' -exec rm -f {} + #uncomment this if you wish to have only non-selected files for the fitting in the test folder


done

echo "Everything Done."

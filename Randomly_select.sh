#!/bin/bash

# Define the source and target directories
# Define the source and target directories
source_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/all_vasp_files"
target_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/Fit_EAM"
target_test_dir="/home/lebedmi2/DATA/VASP_data/Si_xml/Test_set"
num_files=10
num_iterations=50



input_file="./fitted_quantities.out"
second_input="./bestoptfuncs"
# Path to the output file
output_file="/home/lebedmi2/DATA/VASP_data/Si_xml/output_file.txt"

# Number of files to randomly select and copy
echo "Objective_function Variances_Energy Variances_Forces RMS_Energies RMS_Forces TEST_Variances_Energy TEST_Variances_Forces TEST_RMS_Energies TEST_RMS_Forces" >> "$output_file"



for iteration in {1..${num_iterations}}; do
echo "Iteration $iteration"


# Navigate to the source directory

cd "$source_dir" || exit

# Randomly select files
selected_files=$(find . -type f | shuf -n "$num_files")
mapfile -t all_files < <(find . -type f)
#mapfile -t selected_files < <(find . -type f | shuf -n "$num_files")
mapfile -t not_selected_files < <(printf "%s\n" "${all_files[@]}" | grep -vxFf <(printf "%s\n" "${selected_files[@]}"))

mkdir -p "../Selected_files_RANDOM/"
selected_files_output="../Selected_files_RANDOM/selected_files_${iteration}.txt"
printf "%s\n" "${selected_files[@]}" > "$selected_files_output"


counter=1
    for file in $selected_files; do
  	echo "$file"
        cp "$file" "$target_dir/vasprun_${counter}.xml"
        ((counter++))
    done
    counter=1 # Reset counter for all_files
    for file in "${not_selected_files[@]}"; do
        cp "$file" "$target_test_dir/vasprun_${counter}.xml"
        ((counter++))
    done

# Run the command (replace 'meamfit' with the actual command you need to run)
cd "$target_dir" || exit
rm fitdbse
meamfit
mpirun -np 8 meamfit


awk_output=$(awk '/Variances of energies, forces and stress tensor components:/{ getline; energy_variance=$1; force_variance=$2 }
     /rms error on energies=/{ rms_error_on_energies=$5 }
     /rms error on forces=/{ rms_error_on_forces=$5 }
     END{ printf "%f %f %f %f", energy_variance, force_variance, rms_error_on_energies, rms_error_on_forces }' "$input_file")

extracted_number=$(awk '/^[[:space:]]*1:/{ print $2; exit }' "$second_input")






#TEST DATA

cp "potparas_best1" "$target_test_dir/potparas_best1"
cd "$target_test_dir" || exit
rm fitdbse
meamfit
meamfit


awk_output_2=$(awk '/Variances of energies, forces and stress tensor components:/{ getline; energy_variance=$1; force_variance=$2 }
     /rms error on energies=/{ rms_error_on_energies=$5 }
     /rms error on forces=/{ rms_error_on_forces=$5 }
     END{ printf "%f %f %f %f", energy_variance, force_variance, rms_error_on_energies, rms_error_on_forces }' "$input_file")

final_output="${extracted_number} ${awk_output} ${awk_output_2}"
echo "$final_output" >> "$output_file"



# Delete only the copied files from the target directory
# Delete only the copied files from the target directory
find "$target_dir" -type f -name 'vasprun_*.xml' -exec rm -f {} +
#find "$target_test_dir" -type f -name 'vasprun_*.xml' -exec rm -f {} +


done


echo "Operation completed."
